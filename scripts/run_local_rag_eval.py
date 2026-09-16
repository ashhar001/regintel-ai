#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import statistics
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class EvalConfig:
    search_type: str
    top_k: int

    @property
    def name(self) -> str:
        return f"{self.search_type.lower()}-k{self.top_k}"


def parse_matrix(value: str) -> list[EvalConfig]:
    configs: list[EvalConfig] = []
    for raw in value.split(","):
        raw = raw.strip()
        if not raw:
            continue
        try:
            search_type, top_k = raw.split(":", 1)
            search_type = search_type.upper()
            top_k_int = int(top_k)
        except ValueError as exc:
            raise argparse.ArgumentTypeError(
                "matrix must look like SEMANTIC:3,HYBRID:3,HYBRID:5"
            ) from exc
        if search_type not in {"SEMANTIC", "HYBRID"}:
            raise argparse.ArgumentTypeError("search type must be SEMANTIC or HYBRID")
        if not 1 <= top_k_int <= 50:
            raise argparse.ArgumentTypeError("top_k must be between 1 and 50")
        configs.append(EvalConfig(search_type=search_type, top_k=top_k_int))
    if not configs:
        raise argparse.ArgumentTypeError("at least one matrix entry is required")
    return configs


def load_jsonl(path: Path) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    with path.open("r", encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, start=1):
            line = line.strip()
            if not line:
                continue
            try:
                records.append(json.loads(line))
            except json.JSONDecodeError as exc:
                raise ValueError(f"invalid JSON on line {line_number}: {exc}") from exc
    if not records:
        raise ValueError("dataset is empty")
    return records


def post_json(url: str, payload: dict[str, Any], timeout_seconds: float) -> dict[str, Any]:
    body = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout_seconds) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        error_body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {exc.code} from {url}: {error_body}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"could not reach {url}: {exc}") from exc


def normalize_text(value: str) -> str:
    return " ".join(value.lower().split())


def keyword_coverage(answer: str, keywords: list[str]) -> float:
    if not keywords:
        return 1.0
    normalized = normalize_text(answer)
    matched = sum(1 for keyword in keywords if normalize_text(keyword) in normalized)
    return matched / len(keywords)


def reciprocal_rank(results: list[dict[str, Any]], expected_document_id: str) -> float:
    for index, result in enumerate(results, start=1):
        metadata = result.get("metadata") or {}
        if metadata.get("document_id") == expected_document_id:
            return 1.0 / index
    return 0.0


def citation_doc_match(citations: list[dict[str, Any]], expected_document_id: str) -> bool:
    return any(
        (citation.get("metadata") or {}).get("document_id") == expected_document_id
        for citation in citations
    )


def percentile(values: list[float], p: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    if len(ordered) == 1:
        return ordered[0]
    rank = (len(ordered) - 1) * p
    lower = math.floor(rank)
    upper = math.ceil(rank)
    if lower == upper:
        return ordered[lower]
    weight = rank - lower
    return ordered[lower] * (1 - weight) + ordered[upper] * weight


def summarize(rows: list[dict[str, Any]]) -> dict[str, Any]:
    retrieval_hits = [1.0 if row["retrieval_hit"] else 0.0 for row in rows]
    rr = [float(row["reciprocal_rank"]) for row in rows]
    keyword_scores = [float(row["answer_keyword_coverage"]) for row in rows]
    citation_matches = [1.0 if row["citation_document_match"] else 0.0 for row in rows]
    citation_presence = [1.0 if row["citation_count"] > 0 else 0.0 for row in rows]
    retrieval_latency = [float(row["retrieval_latency_ms"]) for row in rows]
    generation_latency = [float(row["generation_latency_ms"]) for row in rows]

    return {
        "cases": len(rows),
        "retrieval_hit_rate": statistics.fmean(retrieval_hits),
        "mrr": statistics.fmean(rr),
        "answer_keyword_coverage": statistics.fmean(keyword_scores),
        "citation_document_accuracy": statistics.fmean(citation_matches),
        "citation_presence_rate": statistics.fmean(citation_presence),
        "retrieval_latency_ms_avg": statistics.fmean(retrieval_latency),
        "retrieval_latency_ms_p95": percentile(retrieval_latency, 0.95),
        "generation_latency_ms_avg": statistics.fmean(generation_latency),
        "generation_latency_ms_p95": percentile(generation_latency, 0.95),
    }


def render_markdown(report: dict[str, Any]) -> str:
    lines = [
        "# RegIntel Local RAG Evaluation",
        "",
        f"Generated: {report['generated_at']}",
        "",
        "| Configuration | Hit@K | MRR | Answer keyword coverage | Citation doc accuracy | Citation presence | Retrieve avg ms | RAG avg ms |",
        "|---|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for config in report["configurations"]:
        metrics = config["metrics"]
        lines.append(
            "| {name} | {hit:.3f} | {mrr:.3f} | {kw:.3f} | {cda:.3f} | {cp:.3f} | {rl:.0f} | {gl:.0f} |".format(
                name=config["name"],
                hit=metrics["retrieval_hit_rate"],
                mrr=metrics["mrr"],
                kw=metrics["answer_keyword_coverage"],
                cda=metrics["citation_document_accuracy"],
                cp=metrics["citation_presence_rate"],
                rl=metrics["retrieval_latency_ms_avg"],
                gl=metrics["generation_latency_ms_avg"],
            )
        )
    lines.extend(
        [
            "",
            "## Metric definitions",
            "",
            "- **Hit@K**: expected `document_id` appears anywhere in the retrieved results.",
            "- **MRR**: mean reciprocal rank of the expected document.",
            "- **Answer keyword coverage**: fraction of required gold-answer phrases present in the generated answer.",
            "- **Citation doc accuracy**: at least one citation points to the expected `document_id`.",
            "- **Citation presence**: generated answer contains at least one citation.",
            "",
            "These deterministic metrics are release-regression checks. Bedrock managed RAG evaluation adds LLM-judge metrics such as context relevance, correctness and faithfulness.",
        ]
    )
    return "\n".join(lines) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description="Run repeatable local RAG regression evaluation.")
    parser.add_argument(
        "--dataset",
        default="evaluation/datasets/regintel_gold.jsonl",
        help="Gold JSONL dataset.",
    )
    parser.add_argument("--base-url", default="http://localhost:8000")
    parser.add_argument(
        "--matrix",
        type=parse_matrix,
        default=parse_matrix("SEMANTIC:3,HYBRID:3"),
        help="Comma-separated SEARCH_TYPE:TOP_K entries.",
    )
    parser.add_argument("--timeout", type=float, default=60.0)
    parser.add_argument("--output-dir", default="evaluation/results")
    parser.add_argument(
        "--sleep-seconds",
        type=float,
        default=0.15,
        help="Small delay between API requests to avoid bursty calls.",
    )
    args = parser.parse_args()

    dataset = load_jsonl(Path(args.dataset))
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    report: dict[str, Any] = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "dataset": str(args.dataset),
        "configurations": [],
    }

    for config in args.matrix:
        print(f"\n=== {config.name} ===")
        rows: list[dict[str, Any]] = []
        for index, case in enumerate(dataset, start=1):
            common = {
                "number_of_results": config.top_k,
                "search_type": config.search_type,
                "filters": case.get("filters", {}),
            }
            retrieve_payload = {"query": case["question"], **common}
            query_payload = {"question": case["question"], **common}

            retrieval = post_json(
                f"{args.base_url.rstrip('/')}/v1/rag/retrieve",
                retrieve_payload,
                args.timeout,
            )
            if args.sleep_seconds:
                time.sleep(args.sleep_seconds)
            generation = post_json(
                f"{args.base_url.rstrip('/')}/v1/rag/query",
                query_payload,
                args.timeout,
            )
            if args.sleep_seconds:
                time.sleep(args.sleep_seconds)

            results = retrieval.get("results", [])
            citations = generation.get("citations", [])
            expected_document_id = case["expected_document_id"]
            rr = reciprocal_rank(results, expected_document_id)
            row = {
                "id": case["id"],
                "question": case["question"],
                "expected_document_id": expected_document_id,
                "reference_answer": case["reference_answer"],
                "retrieval_hit": rr > 0,
                "reciprocal_rank": rr,
                "answer": generation.get("answer", ""),
                "answer_keyword_coverage": keyword_coverage(
                    generation.get("answer", ""), case.get("answer_keywords", [])
                ),
                "citation_count": len(citations),
                "citation_document_match": citation_doc_match(citations, expected_document_id),
                "retrieval_latency_ms": retrieval.get("latency_ms", 0),
                "generation_latency_ms": generation.get("latency_ms", 0),
            }
            rows.append(row)
            print(
                f"[{index:02d}/{len(dataset):02d}] {case['id']}: "
                f"hit={row['retrieval_hit']} rr={row['reciprocal_rank']:.2f} "
                f"answer={row['answer_keyword_coverage']:.2f} "
                f"citation={row['citation_document_match']}"
            )

        metrics = summarize(rows)
        report["configurations"].append(
            {"name": config.name, "search_type": config.search_type, "top_k": config.top_k, "metrics": metrics, "cases": rows}
        )

    json_path = output_dir / f"local-rag-eval-{timestamp}.json"
    markdown_path = output_dir / f"local-rag-eval-{timestamp}.md"
    latest_json = output_dir / "local-rag-eval-latest.json"
    latest_markdown = output_dir / "local-rag-eval-latest.md"

    payload = json.dumps(report, indent=2) + "\n"
    markdown = render_markdown(report)
    json_path.write_text(payload, encoding="utf-8")
    markdown_path.write_text(markdown, encoding="utf-8")
    latest_json.write_text(payload, encoding="utf-8")
    latest_markdown.write_text(markdown, encoding="utf-8")

    print("\n=== summary ===")
    print(markdown)
    print(f"JSON report: {json_path}")
    print(f"Markdown report: {markdown_path}")


if __name__ == "__main__":
    main()
