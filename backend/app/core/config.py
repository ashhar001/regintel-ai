from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    app_name: str = "RegIntel AI API"
    app_env: str = "dev"
    log_level: str = "INFO"

    aws_region: str = "us-east-1"
    bedrock_model_id: str = "amazon.nova-lite-v1:0"
    bedrock_max_tokens: int = Field(default=700, ge=1, le=5000)
    bedrock_temperature: float = Field(default=0.1, ge=0.0, le=1.0)
    bedrock_top_p: float = Field(default=0.9, gt=0.0, le=1.0)

    bedrock_knowledge_base_id: str | None = None
    bedrock_rag_model_arn: str | None = None
    bedrock_rerank_model_arn: str | None = None
    bedrock_guardrail_id: str | None = None
    bedrock_guardrail_version: str | None = None

    observability_metrics_enabled: bool = True
    observability_metrics_namespace: str = "RegIntel/RAG"
    observability_service_name: str = "regintel-api"


@lru_cache
def get_settings() -> Settings:
    return Settings()
