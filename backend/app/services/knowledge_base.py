import logging
import time
from dataclasses import dataclass
from typing import Any

import boto3
from botocore.config import Config
from botocore.exceptions import BotoCoreError, ClientError

from app.core.config import Settings
from app.core.metrics import metrics_from_settings

logger = logging.getLogger(__name__)


class BedrockKnowledgeBaseError(RuntimeError):
    pass


@dataclass(frozen=True)
class KnowledgeBaseResult:
    answer: str
    session_id: str | None
    latency_ms: int
    citations: list[dict[str, Any]]
    guardrail_intervened: bool = False


@dataclass(frozen=True)
class KnowledgeBaseRetrievalResult:
    latency_ms: int
    results: list[dict[str, Any]]


class BedrockKnowledgeBaseService:
    def __init__(self, settings: Settings, client: Any | None = None) -> None:
        self.settings = settings
        self.metrics = metrics_from_settings(settings)
        self.client = client or boto3.client(
            "bedrock-agent-runtime",
            region_name=settings.aws_region,
            config=Config(
                connect_timeout=5,
                read_timeout=120,
                retries={"max_attempts": 3, "mode": "standard"},
            ),
        )

    def _require_configuration(self) -> None:
        if not self.settings.bedrock_knowledge_base_id:
            raise BedrockKnowledgeBaseError("BEDROCK_KNOWLEDGE_BASE_ID is not configured")
        if not self.settings.bedrock_rag_model_arn:
            raise BedrockKnowledgeBaseError("BEDROCK_RAG_MODEL_ARN is not configured")

    @staticmethod
    def _build_filter(filters: dict[str, Any]) -> dict[str, Any] | None:
        clauses = [
            {"equals": {"key": key, "value": value}}
            for key, value in sorted(filters.items())
        ]
        if not clauses:
            return None
        if len(clauses) == 1:
            return clauses[0]
        return {"andAll": clauses}

    def _vector_search_configuration(
        self,
        number_of_results: int,
        search_type: str,
        filters: dict[str, Any],
        rerank: bool = False,
        rerank_top_k: int | None = None,
    ) -> dict[str, Any]:
        config: dict[str, Any] = {
            "numberOfResults": number_of_results,
            "overrideSearchType": search_type,
        }
        retrieval_filter = self._build_filter(filters)
        if retrieval_filter:
            config["filter"] = retrieval_filter

        if rerank:
            if not self.settings.bedrock_rerank_model_arn:
                raise BedrockKnowledgeBaseError(
                    "BEDROCK_RERANK_MODEL_ARN is required when reranking is enabled"
                )
            if rerank_top_k is None:
                raise BedrockKnowledgeBaseError(
                    "rerank_top_k is required when reranking is enabled"
                )
            if rerank_top_k > number_of_results:
                raise BedrockKnowledgeBaseError(
                    "rerank_top_k cannot exceed number_of_results"
                )

            config["rerankingConfiguration"] = {
                "type": "BEDROCK_RERANKING_MODEL",
                "bedrockRerankingConfiguration": {
                    "modelConfiguration": {
                        "modelArn": self.settings.bedrock_rerank_model_arn
                    },
                    "numberOfRerankedResults": rerank_top_k,
                },
            }
        return config

    @staticmethod
    def _source_uri(location: dict[str, Any] | None) -> str | None:
        if not location:
            return None

        stack: list[Any] = [location]
        while stack:
            value = stack.pop()
            if isinstance(value, dict):
                for key, nested in value.items():
                    if key in {"uri", "url"} and isinstance(nested, str):
                        return nested
                    stack.append(nested)
            elif isinstance(value, list):
                stack.extend(value)
        return None

    @staticmethod
    def _text_from_content(content: dict[str, Any] | None) -> str:
        if not content:
            return ""
        text = content.get("text")
        if isinstance(text, str):
            return text
        return ""

    def retrieve(
        self,
        query: str,
        number_of_results: int,
        search_type: str,
        filters: dict[str, Any],
        rerank: bool = False,
        rerank_top_k: int | None = None,
    ) -> KnowledgeBaseRetrievalResult:
        self._require_configuration()
        started = time.perf_counter()

        try:
            response = self.client.retrieve(
                knowledgeBaseId=self.settings.bedrock_knowledge_base_id,
                retrievalQuery={"text": query},
                retrievalConfiguration={
                    "vectorSearchConfiguration": self._vector_search_configuration(
                        number_of_results=number_of_results,
                        search_type=search_type,
                        filters=filters,
                        rerank=rerank,
                        rerank_top_k=rerank_top_k,
                    )
                },
            )
        except (ClientError, BotoCoreError) as exc:
            latency_ms = int((time.perf_counter() - started) * 1000)
            self.metrics.emit(
                operation="rag_retrieve",
                metrics={
                    "RAGRequestCount": (1, "Count"),
                    "RAGErrorCount": (1, "Count"),
                    "RetrievalLatencyMs": (latency_ms, "Milliseconds"),
                },
                properties={"search_type": search_type, "rerank": rerank},
            )
            logger.exception("bedrock_kb_retrieve_failed")
            raise BedrockKnowledgeBaseError("Knowledge Base retrieval failed") from exc

        latency_ms = int((time.perf_counter() - started) * 1000)
        results: list[dict[str, Any]] = []
        for item in response.get("retrievalResults", []):
            results.append(
                {
                    "text": self._text_from_content(item.get("content")),
                    "score": item.get("score"),
                    "source_uri": self._source_uri(item.get("location")),
                    "metadata": item.get("metadata", {}),
                }
            )

        self.metrics.emit(
            operation="rag_retrieve",
            metrics={
                "RAGRequestCount": (1, "Count"),
                "RAGErrorCount": (0, "Count"),
                "RetrievalLatencyMs": (latency_ms, "Milliseconds"),
                "RetrievalResultCount": (len(results), "Count"),
            },
            properties={"search_type": search_type, "rerank": rerank},
        )
        logger.info(
            "bedrock_kb_retrieve_succeeded",
            extra={
                "knowledge_base_id": self.settings.bedrock_knowledge_base_id,
                "latency_ms": latency_ms,
                "result_count": len(results),
                "search_type": search_type,
                "rerank": rerank,
                "rerank_top_k": rerank_top_k,
            },
        )
        return KnowledgeBaseRetrievalResult(latency_ms=latency_ms, results=results)

    def query(
        self,
        question: str,
        number_of_results: int,
        search_type: str,
        filters: dict[str, Any],
        session_id: str | None = None,
        rerank: bool = False,
        rerank_top_k: int | None = None,
    ) -> KnowledgeBaseResult:
        self._require_configuration()
        started = time.perf_counter()

        knowledge_base_config: dict[str, Any] = {
            "knowledgeBaseId": self.settings.bedrock_knowledge_base_id,
            "modelArn": self.settings.bedrock_rag_model_arn,
            "retrievalConfiguration": {
                "vectorSearchConfiguration": self._vector_search_configuration(
                    number_of_results=number_of_results,
                    search_type=search_type,
                    filters=filters,
                    rerank=rerank,
                    rerank_top_k=rerank_top_k,
                )
            },
            "generationConfiguration": {
                "promptTemplate": {
                    "textPromptTemplate": """
You are RegIntel AI, a regulatory intelligence assistant.

Answer the user's question using only the retrieved evidence.

Rules:
- Return only the final user-facing answer.
- Do not expose internal reasoning, retrieval steps, tool calls, function names,
  or labels such as "Action:", "Observation:", or "Response:".
- Do not invent information unsupported by the retrieved evidence.
- If the evidence is insufficient, say:
  "I don't have enough evidence in the indexed sources to answer that."
- Be concise, factual, and precise.

User question:
$query$

Retrieved evidence:
$search_results$

$output_format_instructions$
"""
                },
                "inferenceConfig": {
                    "textInferenceConfig": {
                        "maxTokens": self.settings.bedrock_max_tokens,
                        "temperature": self.settings.bedrock_temperature,
                        "topP": self.settings.bedrock_top_p,
                    }
                }
            },
        }

        if self.settings.bedrock_guardrail_id or self.settings.bedrock_guardrail_version:
            if not (
                self.settings.bedrock_guardrail_id
                and self.settings.bedrock_guardrail_version
            ):
                raise BedrockKnowledgeBaseError(
                    "BEDROCK_GUARDRAIL_ID and BEDROCK_GUARDRAIL_VERSION must be configured together"
                )
            knowledge_base_config["generationConfiguration"]["guardrailConfiguration"] = {
                "guardrailId": self.settings.bedrock_guardrail_id,
                "guardrailVersion": self.settings.bedrock_guardrail_version,
            }

        request: dict[str, Any] = {
            "input": {"text": question},
            "retrieveAndGenerateConfiguration": {
                "type": "KNOWLEDGE_BASE",
                "knowledgeBaseConfiguration": knowledge_base_config,
            },
        }
        if session_id:
            request["sessionId"] = session_id

        try:
            response = self.client.retrieve_and_generate(**request)
        except (ClientError, BotoCoreError) as exc:
            latency_ms = int((time.perf_counter() - started) * 1000)
            self.metrics.emit(
                operation="rag_query",
                metrics={
                    "RAGRequestCount": (1, "Count"),
                    "RAGErrorCount": (1, "Count"),
                    "RAGLatencyMs": (latency_ms, "Milliseconds"),
                },
                properties={"search_type": search_type, "rerank": rerank},
            )
            logger.exception("bedrock_kb_retrieve_and_generate_failed")
            raise BedrockKnowledgeBaseError("Knowledge Base query failed") from exc

        latency_ms = int((time.perf_counter() - started) * 1000)
        citations: list[dict[str, Any]] = []

        for citation in response.get("citations", []):
            text_part = (
                citation.get("generatedResponsePart", {})
                .get("textResponsePart", {})
            )
            span = text_part.get("span", {})
            references = citation.get("retrievedReferences", []) or []
            for reference in references:
                citations.append(
                    {
                        "cited_text": text_part.get("text"),
                        "source_text": self._text_from_content(reference.get("content")),
                        "source_uri": self._source_uri(reference.get("location")),
                        "metadata": reference.get("metadata", {}),
                        "span_start": span.get("start"),
                        "span_end": span.get("end"),
                    }
                )

        answer = response.get("output", {}).get("text", "").strip()
        guardrail_intervened = response.get("guardrailAction") == "INTERVENED"
        self.metrics.emit(
            operation="rag_query",
            metrics={
                "RAGRequestCount": (1, "Count"),
                "RAGErrorCount": (0, "Count"),
                "RAGLatencyMs": (latency_ms, "Milliseconds"),
                "CitationCount": (len(citations), "Count"),
                "GuardrailBlockedCount": (1 if guardrail_intervened else 0, "Count"),
            },
            properties={"search_type": search_type, "rerank": rerank},
        )
        logger.info(
            "bedrock_kb_retrieve_and_generate_succeeded",
            extra={
                "knowledge_base_id": self.settings.bedrock_knowledge_base_id,
                "latency_ms": latency_ms,
                "citation_count": len(citations),
                "search_type": search_type,
                "rerank": rerank,
                "rerank_top_k": rerank_top_k,
                "guardrail_intervened": guardrail_intervened,
            },
        )

        return KnowledgeBaseResult(
            answer=answer,
            session_id=response.get("sessionId"),
            latency_ms=latency_ms,
            citations=citations,
            guardrail_intervened=guardrail_intervened,
        )
