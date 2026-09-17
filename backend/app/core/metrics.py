from __future__ import annotations

import json
import time
from dataclasses import dataclass
from typing import Mapping

from app.core.config import Settings

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

        # EMF is intentionally written directly to stdout. The ECS awslogs driver
        # forwards this JSON event to CloudWatch Logs, where CloudWatch extracts
        # the embedded metrics without requiring cloudwatch:PutMetricData.
        print(json.dumps(payload, separators=(",", ":"), sort_keys=True), flush=True)


def metrics_from_settings(settings: Settings) -> EmbeddedMetrics:
    return EmbeddedMetrics(
        namespace=settings.observability_metrics_namespace,
        service=settings.observability_service_name,
        environment=settings.app_env,
        enabled=settings.observability_metrics_enabled,
    )
