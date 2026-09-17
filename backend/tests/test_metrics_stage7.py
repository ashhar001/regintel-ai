import json

from app.core.config import Settings
from app.core.metrics import EmbeddedMetrics, metrics_from_settings


def test_embedded_metrics_emits_cloudwatch_emf(capsys):
    metrics = EmbeddedMetrics(
        namespace="RegIntel/RAG",
        service="regintel-api",
        environment="test",
        enabled=True,
    )

    metrics.emit(
        operation="rag_query",
        metrics={
            "RAGRequestCount": (1, "Count"),
            "RAGLatencyMs": (1234, "Milliseconds"),
        },
        properties={"search_type": "HYBRID"},
    )

    payload = json.loads(capsys.readouterr().out)
    assert payload["Service"] == "regintel-api"
    assert payload["Environment"] == "test"
    assert payload["Operation"] == "rag_query"
    assert payload["RAGRequestCount"] == 1
    assert payload["RAGLatencyMs"] == 1234
    assert payload["search_type"] == "HYBRID"

    cloudwatch = payload["_aws"]["CloudWatchMetrics"][0]
    assert cloudwatch["Namespace"] == "RegIntel/RAG"
    assert cloudwatch["Dimensions"] == [["Service", "Environment", "Operation"]]
    assert {item["Name"] for item in cloudwatch["Metrics"]} == {
        "RAGRequestCount",
        "RAGLatencyMs",
    }


def test_metrics_disabled_by_default(capsys):
    settings = Settings(app_env="test")
    metrics = metrics_from_settings(settings)

    metrics.emit(
        operation="rag_query",
        metrics={"RAGRequestCount": (1, "Count")},
    )

    assert capsys.readouterr().out == ""
