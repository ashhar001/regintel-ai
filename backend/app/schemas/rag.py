from typing import Any, Literal

from pydantic import BaseModel, Field, model_validator


class RerankOptions(BaseModel):
    rerank: bool = False
    rerank_top_k: int | None = Field(default=None, ge=1, le=50)

    @model_validator(mode="after")
    def validate_rerank_top_k(self) -> "RerankOptions":
        if self.rerank and self.rerank_top_k is None:
            raise ValueError("rerank_top_k is required when rerank is true")
        return self


class RagQueryRequest(RerankOptions):
    question: str = Field(min_length=3, max_length=4000)
    number_of_results: int = Field(default=8, ge=1, le=50)
    search_type: Literal["HYBRID", "SEMANTIC"] = "HYBRID"
    filters: dict[str, str | int | float | bool] = Field(default_factory=dict)
    session_id: str | None = None

    @model_validator(mode="after")
    def validate_rerank_candidate_count(self) -> "RagQueryRequest":
        if self.rerank_top_k is not None and self.rerank_top_k > self.number_of_results:
            raise ValueError("rerank_top_k cannot exceed number_of_results")
        return self


class RagRetrieveRequest(RerankOptions):
    query: str = Field(min_length=3, max_length=4000)
    number_of_results: int = Field(default=8, ge=1, le=50)
    search_type: Literal["HYBRID", "SEMANTIC"] = "HYBRID"
    filters: dict[str, str | int | float | bool] = Field(default_factory=dict)

    @model_validator(mode="after")
    def validate_rerank_candidate_count(self) -> "RagRetrieveRequest":
        if self.rerank_top_k is not None and self.rerank_top_k > self.number_of_results:
            raise ValueError("rerank_top_k cannot exceed number_of_results")
        return self


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
