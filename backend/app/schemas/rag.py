from typing import Any, Literal

from pydantic import BaseModel, Field


class RagQueryRequest(BaseModel):
    question: str = Field(min_length=3, max_length=4000)
    number_of_results: int = Field(default=8, ge=1, le=50)
    search_type: Literal["HYBRID", "SEMANTIC"] = "HYBRID"
    filters: dict[str, str | int | float | bool] = Field(default_factory=dict)
    session_id: str | None = None


class RagRetrieveRequest(BaseModel):
    query: str = Field(min_length=3, max_length=4000)
    number_of_results: int = Field(default=8, ge=1, le=50)
    search_type: Literal["HYBRID", "SEMANTIC"] = "HYBRID"
    filters: dict[str, str | int | float | bool] = Field(default_factory=dict)


class RetrievalHit(BaseModel):
    text: str
    score: float | None = None
    source_uri: str | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)


class Citation(BaseModel):
    cited_text: str | None = None
    source_text: str | None = None
    source_uri: str | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)
    span_start: int | None = None
    span_end: int | None = None


class RagQueryResponse(BaseModel):
    answer: str
    session_id: str | None = None
    latency_ms: int
    citations: list[Citation] = Field(default_factory=list)


class RagRetrieveResponse(BaseModel):
    results: list[RetrievalHit]
    latency_ms: int
