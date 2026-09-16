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
    name: str
    search_type: str
    candidates: int
    rerank: bool
    final_k: int


def load_jsonl(path: Path) -> list[dict[str, Any]]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def post_json(url: str, payload: dict[str, Any], timeout: float) -> dict[str, Any]:
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as exc:
        body = exc.read().decode(errors="replace")
        raise RuntimeError(f"HTTP {exc.code}: {body}") from exc


def rr(results: list[dict[str, Any]], expected: str) -> float:
    for i, item in enumerate(results, 1):
        if (item.get("metadata") or {}).get("document_id") == expected:
            return 1.0 / i
    return 0.0


def keyword_coverage(answer: str, keywords: list[str]) -> float:
    text = " ".join(answer.lower().split())
    return sum(" ".join(k.lower().split()) in text for k in keywords) / max(len(keywords), 1)


def percentile(values: list[float], p: float) -> float:
    if not values:
        return 0.0
    vals=sorted(values)
    pos=(len(vals)-1)*p
    lo=math.floor(pos); hi=math.ceil(pos)
    return vals[lo] if lo==hi else vals[lo]*(hi-pos)+vals[hi]*(pos-lo)


def main() -> None:
    ap=argparse.ArgumentParser(description="Compare baseline retrieval with Bedrock reranking.")
    ap.add_argument("--dataset", default="evaluation/datasets/regintel_hard_gold.jsonl")
    ap.add_argument("--base-url", default="http://localhost:8000")
    ap.add_argument("--timeout", type=float, default=90.0)
    ap.add_argument("--output-dir", default="evaluation/results")
    args=ap.parse_args()

    cases=load_jsonl(Path(args.dataset))
    configs=[
        EvalConfig("semantic-k5", "SEMANTIC", 5, False, 5),
        EvalConfig("hybrid-k5", "HYBRID", 5, False, 5),
        EvalConfig("hybrid-rerank-20to5", "HYBRID", 20, True, 5),
    ]
    report={"generated_at":datetime.now(timezone.utc).isoformat(),"dataset":args.dataset,"configurations":[]}

    for cfg in configs:
        print(f"\n=== {cfg.name} ===")
        rows=[]
        for idx, case in enumerate(cases, 1):
            common={
                "number_of_results":cfg.candidates,
                "search_type":cfg.search_type,
                "filters":case.get("filters",{}),
                "rerank":cfg.rerank,
            }
            if cfg.rerank:
                common["rerank_top_k"]=cfg.final_k
            ret=post_json(f"{args.base_url}/v1/rag/retrieve",{"query":case["question"],**common},args.timeout)
            time.sleep(.1)
            gen=post_json(f"{args.base_url}/v1/rag/query",{"question":case["question"],**common},args.timeout)
            results=ret.get("results",[]); citations=gen.get("citations",[])
            score=rr(results,case["expected_document_id"])
            cdoc=any((c.get("metadata") or {}).get("document_id")==case["expected_document_id"] for c in citations)
            row={
                "id":case["id"],"rr":score,"hit":score>0,
                "answer":keyword_coverage(gen.get("answer",""),case.get("answer_keywords",[])),
                "citation":cdoc,"retrieve_ms":ret.get("latency_ms",0),"rag_ms":gen.get("latency_ms",0),
            }
            rows.append(row)
            print(f"[{idx:02d}/{len(cases):02d}] {case['id']}: hit={row['hit']} rr={score:.2f} answer={row['answer']:.2f} citation={cdoc}")
        metrics={
            "hit_at_k":statistics.fmean(1 if r["hit"] else 0 for r in rows),
            "mrr":statistics.fmean(r["rr"] for r in rows),
            "answer_keyword_coverage":statistics.fmean(r["answer"] for r in rows),
            "citation_doc_accuracy":statistics.fmean(1 if r["citation"] else 0 for r in rows),
            "retrieve_avg_ms":statistics.fmean(r["retrieve_ms"] for r in rows),
            "retrieve_p95_ms":percentile([r["retrieve_ms"] for r in rows],.95),
            "rag_avg_ms":statistics.fmean(r["rag_ms"] for r in rows),
        }
        report["configurations"].append({"name":cfg.name,"metrics":metrics,"cases":rows})

    print("\n=== summary ===")
    print("| Configuration | Hit@K | MRR | Answer | Citation | Retrieve avg ms | RAG avg ms |")
    print("|---|---:|---:|---:|---:|---:|---:|")
    for item in report["configurations"]:
        m=item["metrics"]
        print(f"| {item['name']} | {m['hit_at_k']:.3f} | {m['mrr']:.3f} | {m['answer_keyword_coverage']:.3f} | {m['citation_doc_accuracy']:.3f} | {m['retrieve_avg_ms']:.0f} | {m['rag_avg_ms']:.0f} |")

    out=Path(args.output_dir); out.mkdir(parents=True,exist_ok=True)
    stamp=datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    path=out/f"rerank-benchmark-{stamp}.json"
    path.write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    (out/"rerank-benchmark-latest.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    print(f"\nJSON report: {path}")


if __name__ == "__main__":
    main()
