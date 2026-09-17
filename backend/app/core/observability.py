import logging
import time
import uuid

from fastapi import Request

from app.core.config import get_settings
from app.core.metrics import metrics_from_settings
from app.core.request_context import (
    reset_request_id,
    reset_trace_id,
    set_request_id,
    set_trace_id,
)

logger = logging.getLogger("regintel.http")


def _extract_trace_id(trace_header: str | None) -> str | None:
    if not trace_header:
        return None
    for part in trace_header.split(";"):
        key, separator, value = part.strip().partition("=")
        if separator and key == "Root" and value:
            return value
    return None


async def request_observability_middleware(request: Request, call_next):
    request_id = request.headers.get("x-request-id") or str(uuid.uuid4())
    trace_id = _extract_trace_id(request.headers.get("x-amzn-trace-id"))
    request_token = set_request_id(request_id)
    trace_token = set_trace_id(trace_id)
    started = time.perf_counter()
    settings = get_settings()
    metrics = metrics_from_settings(settings)

    try:
        try:
            response = await call_next(request)
        except Exception:
            latency_ms = int((time.perf_counter() - started) * 1000)
            metrics.emit(
                operation="http_request",
                metrics={
                    "HTTPRequestCount": (1, "Count"),
                    "HTTPErrorCount": (1, "Count"),
                    "HTTPLatencyMs": (latency_ms, "Milliseconds"),
                },
                properties={
                    "method": request.method,
                    "path": request.url.path,
                    "status_code": 500,
                },
            )
            logger.exception(
                "http_request_failed",
                extra={
                    "method": request.method,
                    "path": request.url.path,
                    "latency_ms": latency_ms,
                },
            )
            raise

        latency_ms = int((time.perf_counter() - started) * 1000)
        response.headers["x-request-id"] = request_id
        if trace_id:
            response.headers["x-trace-id"] = trace_id
        is_error = response.status_code >= 500
        metrics.emit(
            operation="http_request",
            metrics={
                "HTTPRequestCount": (1, "Count"),
                "HTTPErrorCount": (1 if is_error else 0, "Count"),
                "HTTPLatencyMs": (latency_ms, "Milliseconds"),
            },
            properties={
                "method": request.method,
                "path": request.url.path,
                "status_code": response.status_code,
            },
        )
        logger.info(
            "http_request_completed",
            extra={
                "method": request.method,
                "path": request.url.path,
                "status_code": response.status_code,
                "latency_ms": latency_ms,
            },
        )
        return response
    finally:
        reset_trace_id(trace_token)
        reset_request_id(request_token)
