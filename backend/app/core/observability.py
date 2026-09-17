import logging
import time
import uuid

from fastapi import Request

from app.core.config import get_settings
from app.core.metrics import metrics_from_settings

logger = logging.getLogger("regintel.http")


async def request_observability_middleware(request: Request, call_next):
    request_id = request.headers.get("x-request-id") or str(uuid.uuid4())
    started = time.perf_counter()
    settings = get_settings()
    metrics = metrics_from_settings(settings)

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
                "request_id": request_id,
                "method": request.method,
                "path": request.url.path,
                "status_code": 500,
            },
        )
        logger.exception(
            "http_request_failed",
            extra={
                "request_id": request_id,
                "method": request.method,
                "path": request.url.path,
                "latency_ms": latency_ms,
            },
        )
        raise

    latency_ms = int((time.perf_counter() - started) * 1000)
    response.headers["x-request-id"] = request_id
    is_error = response.status_code >= 500
    metrics.emit(
        operation="http_request",
        metrics={
            "HTTPRequestCount": (1, "Count"),
            "HTTPErrorCount": (1 if is_error else 0, "Count"),
            "HTTPLatencyMs": (latency_ms, "Milliseconds"),
        },
        properties={
            "request_id": request_id,
            "method": request.method,
            "path": request.url.path,
            "status_code": response.status_code,
        },
    )
    logger.info(
        "http_request_completed",
        extra={
            "request_id": request_id,
            "method": request.method,
            "path": request.url.path,
            "status_code": response.status_code,
            "latency_ms": latency_ms,
        },
    )
    return response
