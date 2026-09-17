from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status

from app.core.config import Settings, get_settings
from app.schemas.chat import ChatRequest, ChatResponse, Usage
from app.services.bedrock_runtime import BedrockInvocationError, BedrockRuntimeService

router = APIRouter(prefix="/v1", tags=["chat"])

SettingsDep = Annotated[Settings, Depends(get_settings)]


def get_bedrock_service(settings: SettingsDep) -> BedrockRuntimeService:
    return BedrockRuntimeService(settings)


BedrockServiceDep = Annotated[BedrockRuntimeService, Depends(get_bedrock_service)]


@router.post("/chat", response_model=ChatResponse)
def chat(
    request: ChatRequest,
    service: BedrockServiceDep,
) -> ChatResponse:
    try:
        result = service.ask(request.question)
    except BedrockInvocationError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="The model service could not complete the request.",
        ) from exc

    return ChatResponse(
        answer=result.text,
        model_id=service.settings.bedrock_model_id,
        latency_ms=result.latency_ms,
        usage=Usage(
            input_tokens=result.input_tokens,
            output_tokens=result.output_tokens,
            total_tokens=result.total_tokens,
        ),
        request_id=result.request_id,
    )
