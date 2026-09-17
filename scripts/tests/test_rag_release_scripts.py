from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

import pytest


def _load_script(name: str):
    module_path = Path(__file__).resolve().parents[1] / name
    spec = importlib.util.spec_from_file_location(name.removesuffix(".py"), module_path)
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


run_local_rag_eval = _load_script("run_local_rag_eval.py")
check_release_gate = _load_script("check_release_gate.py")


def test_parse_matrix_supports_rerank_config() -> None:
    configs = run_local_rag_eval.parse_matrix("HYBRID:20:RERANK:5")

    assert len(configs) == 1
    assert configs[0].name == "hybrid-rerank-20to5"
    assert configs[0].search_type == "HYBRID"
    assert configs[0].top_k == 20
    assert configs[0].rerank is True
    assert configs[0].rerank_top_k == 5


def test_run_local_rag_eval_sends_rerank_payloads(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    dataset = tmp_path / "dataset.jsonl"
    dataset.write_text(
        json.dumps(
            {
                "id": "case-1",
                "question": "How often are high-risk customers reviewed?",
                "reference_answer": "Every twelve months.",
                "expected_document_id": "REGINTEL-TEST-001",
                "filters": {"topic": "KYC"},
                "answer_keywords": ["twelve months"],
            }
        )
        + "\n",
        encoding="utf-8",
    )
    output_dir = tmp_path / "results"
    payloads = []

    def fake_post_json(url: str, payload: dict[str, object], timeout_seconds: float):
        payloads.append((url, payload, timeout_seconds))
        if url.endswith("/retrieve"):
            return {
                "latency_ms": 10,
                "results": [
                    {
                        "metadata": {"document_id": "REGINTEL-TEST-001"},
                        "source_uri": "s3://bucket/policy.txt",
                    }
                ],
            }
        return {
            "latency_ms": 20,
            "answer": "Every twelve months.",
            "citations": [
                {
                    "metadata": {"document_id": "REGINTEL-TEST-001"},
                    "source_uri": "s3://bucket/policy.txt",
                }
            ],
        }

    monkeypatch.setattr(run_local_rag_eval, "post_json", fake_post_json)
    monkeypatch.setattr(
        sys,
        "argv",
        [
            "run_local_rag_eval.py",
            "--dataset",
            str(dataset),
            "--base-url",
            "http://api.test",
            "--matrix",
            "HYBRID:20:RERANK:5",
            "--output-dir",
            str(output_dir),
            "--sleep-seconds",
            "0",
        ],
    )

    run_local_rag_eval.main()

    request_payloads = [payload for _, payload, _ in payloads]
    assert request_payloads == [
        {
            "query": "How often are high-risk customers reviewed?",
            "number_of_results": 20,
            "search_type": "HYBRID",
            "filters": {"topic": "KYC"},
            "rerank": True,
            "rerank_top_k": 5,
        },
        {
            "question": "How often are high-risk customers reviewed?",
            "number_of_results": 20,
            "search_type": "HYBRID",
            "filters": {"topic": "KYC"},
            "rerank": True,
            "rerank_top_k": 5,
        },
    ]
    report = json.loads((output_dir / "local-rag-eval-latest.json").read_text())
    config = report["configurations"][0]
    assert config["name"] == "hybrid-rerank-20to5"
    assert config["rerank"] is True
    assert config["rerank_top_k"] == 5
    assert config["cases"][0]["citation_document_ids"] == ["REGINTEL-TEST-001"]


def test_check_release_gate_prints_failing_case_ids(
    capsys: pytest.CaptureFixture[str],
    tmp_path: Path,
) -> None:
    report = tmp_path / "report.json"
    report.write_text(
        json.dumps(
            {
                "configurations": [
                    {
                        "name": "hybrid-rerank-20to5",
                        "metrics": {
                            "retrieval_hit_rate": 1.0,
                            "mrr": 0.75,
                            "answer_keyword_coverage": 0.5,
                            "citation_document_accuracy": 0.5,
                        },
                        "cases": [
                            {
                                "id": "case-1",
                                "retrieval_hit": True,
                                "reciprocal_rank": 1.0,
                                "answer_keyword_coverage": 0.0,
                                "citation_document_match": False,
                            }
                        ],
                    }
                ]
            }
        ),
        encoding="utf-8",
    )

    monkeypatch_args = [
        "check_release_gate.py",
        "--report",
        str(report),
        "--configuration",
        "hybrid-rerank-20to5",
    ]
    original_argv = sys.argv
    sys.argv = monkeypatch_args
    try:
        with pytest.raises(SystemExit):
            check_release_gate.main()
    finally:
        sys.argv = original_argv

    output = capsys.readouterr().out
    assert "cases: case-1" in output
