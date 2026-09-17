from __future__ import annotations

import json
import time
from collections.abc import Mapping
from dataclasses import dataclass

from app.core.config import Settings
from app.core.request_context import get_request_id, get_trace_id

MetricValue = tuple[int | float, str]


@dataclass(frozen=True)
class EmbeddedMetrics:
    namespace: str
    service: str
    environment: str
    enabled: bool = True

    def emit(
        self,
        operation: str,
        metrics: Mapping[str, MetricValue],
        properties: Mapping[str, str | int | float | bool | None] | None = None,
    ) -> None:
        if not self.enabled or not metrics:
            return

        metric_definitions: list[dict[str, str]] = []
        metric_values: dict[str, int | float] = {}

        for name, (value, unit) in metrics.items():
            metric_definitions.append({"Name": name, "Unit": unit})
            metric_values[name] = value

        payload: dict[str, object] = {
            "_aws": {
                "Timestamp": int(time.time() * 1000),
                "CloudWatchMetrics": [
                    {
                        "Namespace": self.namespace,
                        "Dimensions": [["Service", "Environment", "Operation"]],
                        "Metrics": metric_definitions,
                    }
                ],
            },
            "Service": self.service,
            "Environment": self.environment,
            "Operation": operation,
            **metric_values,
        }

        if properties:
            payload.update({key: value for key, value in properties.items() if value is not None})

        request_id = get_request_id()
        if request_id and "request_id" not in payload:
            payload["request_id"] = request_id

        trace_id = get_trace_id()
        if trace_id and "trace_id" not in payload:
            payload["trace_id"] = trace_id

        print(json.dumps(payload, separators=(",", ":"), sort_keys=True), flush=True)


def metrics_from_settings(settings: Settings) -> EmbeddedMetrics:
    return EmbeddedMetrics(
        namespace=getattr(settings, "observability_metrics_namespace", "RegIntel/RAG"),
        service=getattr(settings, "observability_service_name", "regintel-api"),
        environment=getattr(settings, "app_env", "dev"),
        enabled=getattr(settings, "observability_metrics_enabled", False),
    )
