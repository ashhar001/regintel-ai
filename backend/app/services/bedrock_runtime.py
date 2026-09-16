import logging
import time
from dataclasses import dataclass

import boto3
from botocore.config import Config
from botocore.exceptions import BotoCoreError, ClientError

from app.core.config import Settings

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = """You are RegIntel AI, an enterprise financial-regulatory assistant.
At this stage you do NOT have a retrieval knowledge base connected.
Answer only general questions about the product or AWS architecture.
If a user asks for a specific regulation, circular, policy, date, clause, or legal requirement,
state that grounded regulatory retrieval will be added in the next stage and do not fabricate it.
Be concise and explicit about uncertainty."""


class BedrockInvocationError(RuntimeError):
    pass


@dataclass(frozen=True)
class BedrockResult:
    text: str
    latency_ms: int
    input_tokens: int | None
    output_tokens: int | None
    total_tokens: int | None
    request_id: str | None


class BedrockRuntimeService:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self.client = boto3.client(
            "bedrock-runtime",
            region_name=settings.aws_region,
            config=Config(
                connect_timeout=5,
                read_timeout=120,
                retries={"max_attempts": 3, "mode": "standard"},
            ),
        )

    def ask(self, question: str) -> BedrockResult:
        started = time.perf_counter()
        try:
            response = self.client.converse(
                modelId=self.settings.bedrock_model_id,
                system=[{"text": SYSTEM_PROMPT}],
                messages=[{"role": "user", "content": [{"text": question}]}],
                inferenceConfig={
                    "maxTokens": self.settings.bedrock_max_tokens,
                    "temperature": self.settings.bedrock_temperature,
                    "topP": self.settings.bedrock_top_p,
                },
            )
        except (ClientError, BotoCoreError) as exc:
            logger.exception("bedrock_converse_failed")
            raise BedrockInvocationError("Amazon Bedrock invocation failed") from exc

        latency_ms = int((time.perf_counter() - started) * 1000)
        content = response.get("output", {}).get("message", {}).get("content", [])
        text = "".join(block.get("text", "") for block in content if "text" in block).strip()
        usage = response.get("usage", {})
        metadata = response.get("ResponseMetadata", {})

        logger.info(
            "bedrock_converse_succeeded",
            extra={
                "model_id": self.settings.bedrock_model_id,
                "latency_ms": latency_ms,
                "input_tokens": usage.get("inputTokens"),
                "output_tokens": usage.get("outputTokens"),
            },
        )

        return BedrockResult(
            text=text,
            latency_ms=latency_ms,
            input_tokens=usage.get("inputTokens"),
            output_tokens=usage.get("outputTokens"),
            total_tokens=usage.get("totalTokens"),
            request_id=metadata.get("RequestId"),
        )
