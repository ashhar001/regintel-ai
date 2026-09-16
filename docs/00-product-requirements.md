# Stage 0 — Product Requirements

## Product
**RegIntel AI** — an enterprise financial-regulatory intelligence platform built on Amazon Bedrock.

## Primary users
- Compliance analysts
- Risk and legal operations teams
- Fintech / exchange / banking product teams
- Internal auditors

## Core user journeys
1. Ingest official regulatory documents with normalized metadata.
2. Ask a natural-language question and receive a grounded answer with citations.
3. Filter retrieval by regulator, jurisdiction, document type, effective date, topic, and entity type.
4. Compare two versions/circulars and explain what changed.
5. Refuse or qualify answers when evidence is insufficient.
6. Record audit metadata for every request without storing secrets in logs.

## MVP data domain
Start with official public regulatory material. The first implementation should use a small curated corpus before automating external acquisition.

Suggested metadata:
- regulator
- jurisdiction
- document_type
- publication_date
- effective_date
- topic
- entity_type
- source_url
- document_version

## Non-functional requirements
### Security
- Private S3 buckets; block public access.
- Encryption at rest with KMS where appropriate.
- TLS in transit.
- Least-privilege IAM.
- Cognito authentication at the public API layer.
- WAF at the edge.
- Guardrails for input/output policy enforcement.
- CloudTrail auditing.

### Reliability
- At-least-once ingestion with idempotent processors.
- SQS retry + DLQ for asynchronous failures.
- Explicit timeouts and bounded retries.
- Health/readiness endpoints.
- Safe deployment rollback.

### Performance targets
Initial engineering targets; validate with load tests later:
- API availability target: 99.9% once production deployed.
- P95 non-LLM API overhead: < 300 ms.
- P95 end-to-end answer latency: < 8 s for standard RAG queries.
- First useful streamed token target: < 3 s where streaming is enabled.

### Quality targets
These are release gates to be calibrated after the evaluation dataset exists:
- Context relevance >= 0.85
- Faithfulness >= 0.90
- Citation coverage >= 0.90
- Critical safety regression count = 0

### Environments
- dev
- stage
- prod

## Definition of done for the overall project
The project is not considered production-ready until retrieval, generation, security, observability, evaluation, deployment, rollback, and operational runbooks are all implemented and tested.
