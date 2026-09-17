from types import SimpleNamespace

from fastapi.testclient import TestClient

from app.api.routes.rag import get_kb_service
from app.main import app


class FakeKnowledgeBaseService:
    def __init__(self) -> None:
        self.retrieve_request = None
        self.query_request = None

    def retrieve(self, **kwargs):
        self.retrieve_request = kwargs
        return SimpleNamespace(
            latency_ms=12,
            results=[
                {
                    "text": "High-risk customers are reviewed every twelve months.",
                    "score": 0.9,
                    "source_uri": "s3://bucket/policy.txt",
                    "metadata": {"document_id": "REGINTEL-TEST-001"},
                }
            ],
        )

    def query(self, **kwargs):
        self.query_request = kwargs
        return SimpleNamespace(
            answer="High-risk customers are reviewed every twelve months.",
            session_id="session-1",
            latency_ms=34,
            citations=[
                {
                    "cited_text": "twelve months",
                    "source_text": "High-risk customers must be reviewed every twelve months.",
                    "source_uri": "s3://bucket/policy.txt",
                    "metadata": {"document_id": "REGINTEL-TEST-001"},
                    "span_start": 0,
                    "span_end": 13,
                }
            ],
        )


def test_retrieve_route_forwards_rerank_options() -> None:
    service = FakeKnowledgeBaseService()
    app.dependency_overrides[get_kb_service] = lambda: service
    try:
        response = TestClient(app).post(
            "/v1/rag/retrieve",
            json={
                "query": "How often are high-risk customers reviewed?",
                "number_of_results": 20,
                "search_type": "HYBRID",
                "filters": {"topic": "KYC"},
                "rerank": True,
                "rerank_top_k": 5,
            },
        )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert service.retrieve_request["rerank"] is True
    assert service.retrieve_request["rerank_top_k"] == 5


def test_query_route_forwards_rerank_options() -> None:
    service = FakeKnowledgeBaseService()
    app.dependency_overrides[get_kb_service] = lambda: service
    try:
        response = TestClient(app).post(
            "/v1/rag/query",
            json={
                "question": "How often are high-risk customers reviewed?",
                "number_of_results": 20,
                "search_type": "HYBRID",
                "filters": {"topic": "KYC"},
                "rerank": True,
                "rerank_top_k": 5,
            },
        )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert service.query_request["rerank"] is True
    assert service.query_request["rerank_top_k"] == 5


def test_rerank_requires_rerank_top_k() -> None:
    response = TestClient(app).post(
        "/v1/rag/query",
        json={
            "question": "How often are high-risk customers reviewed?",
            "number_of_results": 20,
            "search_type": "HYBRID",
            "rerank": True,
        },
    )

    assert response.status_code == 422


def test_rerank_top_k_cannot_exceed_number_of_results() -> None:
    response = TestClient(app).post(
        "/v1/rag/retrieve",
        json={
            "query": "How often are high-risk customers reviewed?",
            "number_of_results": 5,
            "search_type": "HYBRID",
            "rerank": True,
            "rerank_top_k": 20,
        },
    )

    assert response.status_code == 422
