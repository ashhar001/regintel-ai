from fastapi import APIRouter, Depends, HTTPException, status

from app.core.config import Settings, get_settings
from app.schemas.rag import (
    Citation,
    RagQueryRequest,
    RagQueryResponse,
    RagRetrieveRequest,
    RagRetrieveResponse,
    RetrievalHit,
)
from app.services.knowledge_base import BedrockKnowledgeBaseError, BedrockKnowledgeBaseService

router = APIRouter(prefix="/v1/rag", tags=["rag"])


def get_kb_service(settings: Settings = Depends(get_settings)) -> BedrockKnowledgeBaseService:
    return BedrockKnowledgeBaseService(settings)


@router.post("/retrieve", response_model=RagRetrieveResponse)
def retrieve(
    request: RagRetrieveRequest,
    service: BedrockKnowledgeBaseService = Depends(get_kb_service),
) -> RagRetrieveResponse:
    try:
        result = service.retrieve(
            query=request.query,
            number_of_results=request.number_of_results,
            search_type=request.search_type,
            filters=request.filters,
        )
    except BedrockKnowledgeBaseError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(exc),
        ) from exc

    return RagRetrieveResponse(
        latency_ms=result.latency_ms,
        results=[RetrievalHit(**item) for item in result.results],
    )


@router.post("/query", response_model=RagQueryResponse)
def query(
    request: RagQueryRequest,
    service: BedrockKnowledgeBaseService = Depends(get_kb_service),
) -> RagQueryResponse:
    try:
        result = service.query(
            question=request.question,
            number_of_results=request.number_of_results,
            search_type=request.search_type,
            filters=request.filters,
            session_id=request.session_id,
        )
    except BedrockKnowledgeBaseError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(exc),
        ) from exc

    return RagQueryResponse(
        answer=result.answer,
        session_id=result.session_id,
        latency_ms=result.latency_ms,
        citations=[Citation(**item) for item in result.citations],
    )
