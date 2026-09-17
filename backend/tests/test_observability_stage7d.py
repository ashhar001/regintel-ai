import json

from app.core.metrics import EmbeddedMetrics
from app.core.observability import _extract_trace_id
from app.core.request_context import (
    reset_request_id,
    reset_trace_id,
    set_request_id,
    set_trace_id,
)


def test_extract_trace_id_from_xray_header():
    header = "Root=1-66aa0000-1234567890abcdef12345678;Parent=abcdef1234567890;Sampled=1"
    assert _extract_trace_id(header) == "1-66aa0000-1234567890abcdef12345678"


def test_extract_trace_id_handles_missing_or_malformed_header():
    assert _extract_trace_id(None) is None
    assert _extract_trace_id("") is None
    assert _extract_trace_id("Parent=abcdef;Sampled=1") is None


def test_emf_adds_request_and_trace_ids_as_properties(capsys):
    metrics = EmbeddedMetrics(
        namespace="RegIntel/RAG",
        service="regintel-api",
        environment="test",
        enabled=True,
    )
    request_token = set_request_id("request-stage7d")
    trace_token = set_trace_id("1-66aa0000-1234567890abcdef12345678")
    try:
        metrics.emit(
            operation="rag_query",
            metrics={"RAGRequestCount": (1, "Count")},
        )
    finally:
        reset_trace_id(trace_token)
        reset_request_id(request_token)

    payload = json.loads(capsys.readouterr().out)
    assert payload["request_id"] == "request-stage7d"
    assert payload["trace_id"] == "1-66aa0000-1234567890abcdef12345678"

    dimensions = payload["_aws"]["CloudWatchMetrics"][0]["Dimensions"][0]
    assert "request_id" not in dimensions
    assert "trace_id" not in dimensions
