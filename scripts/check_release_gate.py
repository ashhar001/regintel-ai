#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path


def failing_case_ids(metric_name: str, cases: list[dict[str, object]]) -> list[str]:
    if metric_name == "Hit@K":
        return [str(case.get("id")) for case in cases if not case.get("retrieval_hit")]
    if metric_name == "Answer keyword coverage":
        return [
            str(case.get("id"))
            for case in cases
            if float(case.get("answer_keyword_coverage", 0.0)) < 1.0
        ]
    if metric_name == "Citation document accuracy":
        return [
            str(case.get("id"))
            for case in cases
            if not case.get("citation_document_match")
        ]
    if metric_name == "MRR":
        weakest = sorted(
            cases,
            key=lambda case: float(case.get("reciprocal_rank", 0.0)),
        )[:3]
        return [str(case.get("id")) for case in weakest]
    return []


def main() -> None:
    parser = argparse.ArgumentParser(description="Fail a release when deterministic RAG metrics regress.")
    parser.add_argument("--report", default="evaluation/results/local-rag-eval-latest.json")
    parser.add_argument("--configuration", default="hybrid-k5")
    parser.add_argument("--min-hit", type=float, default=1.0)
    parser.add_argument("--min-mrr", type=float, default=0.70)
    parser.add_argument("--min-answer", type=float, default=0.95)
    parser.add_argument("--min-citation", type=float, default=0.875)
    args = parser.parse_args()

    report = json.loads(Path(args.report).read_text(encoding="utf-8"))
    selected = next(
        (item for item in report.get("configurations", []) if item.get("name") == args.configuration),
        None,
    )
    if selected is None:
        raise SystemExit(f"configuration {args.configuration!r} not found in {args.report}")

    metrics = selected["metrics"]
    cases = selected.get("cases", [])
    checks = {
        "Hit@K": (float(metrics["retrieval_hit_rate"]), args.min_hit),
        "MRR": (float(metrics["mrr"]), args.min_mrr),
        "Answer keyword coverage": (float(metrics["answer_keyword_coverage"]), args.min_answer),
        "Citation document accuracy": (float(metrics["citation_document_accuracy"]), args.min_citation),
    }

    failed = []
    print("\n=== Stage 6 release gate ===")
    for name, (actual, threshold) in checks.items():
        state = "PASS" if actual >= threshold else "FAIL"
        print(f"{state:4}  {name:28} actual={actual:.3f} threshold={threshold:.3f}")
        if actual < threshold:
            failed.append(name)
            case_ids = failing_case_ids(name, cases)
            if case_ids:
                print(f"      cases: {', '.join(case_ids)}")

    if failed:
        raise SystemExit("release blocked: " + ", ".join(failed))

    print("Release gate passed.")


if __name__ == "__main__":
    main()
