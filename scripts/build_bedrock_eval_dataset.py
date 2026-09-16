#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def load_jsonl(path: Path) -> list[dict[str, Any]]:
    records = []
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if line:
                records.append(json.loads(line))
    return records


def main() -> None:
    parser = argparse.ArgumentParser(description="Build Bedrock RAG-evaluation JSONL dataset.")
    parser.add_argument("--input", default="evaluation/datasets/regintel_gold.jsonl")
    parser.add_argument("--output", default="evaluation/datasets/bedrock-rag-eval.jsonl")
    args = parser.parse_args()

    records = load_jsonl(Path(args.input))
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)

    with output.open("w", encoding="utf-8") as handle:
        for record in records:
            bedrock_record = {
                "conversationTurns": [
                    {
                        "prompt": {"content": [{"text": record["question"]}]},
                        "referenceResponses": [
                            {"content": [{"text": record["reference_answer"]}]}
                        ],
                    }
                ]
            }
            handle.write(json.dumps(bedrock_record, separators=(",", ":")) + "\n")

    print(f"wrote {len(records)} prompts to {output}")


if __name__ == "__main__":
    main()
