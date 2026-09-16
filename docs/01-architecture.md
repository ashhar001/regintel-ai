# Target Architecture

## Request path
User -> CloudFront -> WAF -> Cognito -> API Gateway -> FastAPI on ECS Fargate -> Bedrock Guardrails -> retrieval/orchestration -> Bedrock model -> grounded cited response.

## Retrieval path
FastAPI -> Bedrock Knowledge Base -> OpenSearch Serverless -> metadata filters + hybrid search -> reranker -> top context -> generation.

## Ingestion path
S3 raw -> EventBridge -> SQS -> Step Functions -> validation / metadata enrichment -> S3 processed -> Bedrock Knowledge Base sync -> embeddings -> OpenSearch Serverless.

## Evaluation path
Versioned evaluation dataset in S3 -> Bedrock RAG evaluation -> report in S3 -> CI/CD release gate.

## Observability
CloudWatch logs + metrics + traces, Bedrock invocation metrics, ingestion queue depth / DLQ alarms, retrieval quality metrics, latency, token usage, guardrail interventions and evaluation regressions.

## Why OpenSearch Serverless initially
It supports Bedrock Knowledge Bases and allows hybrid retrieval when the vector store has a filterable text field. This gives us a straightforward path to benchmark semantic vs hybrid retrieval before considering alternate vector backends.
