# ADR-001: Region and initial model choices

**Status:** Accepted for Stage 1

## Decision
- AWS Region: `us-east-1`
- Development generation model: `amazon.nova-lite-v1:0`
- Planned production/evaluation candidate: `amazon.nova-pro-v1:0`
- Planned embedding model: `amazon.titan-embed-text-v2:0`
- Planned vector store: Amazon OpenSearch Serverless

## Rationale
- `us-east-1` has broad Bedrock feature/model availability.
- Nova Lite is appropriate for low-cost development and smoke testing.
- Nova Pro will be benchmarked rather than assumed to be the final production model.
- Titan Text Embeddings V2 is Bedrock-native and supports configurable dimensions.
- OpenSearch Serverless supports the hybrid-search path we want to test.

## Important rule
No model is promoted to production based only on subjective output quality. Retrieval + generation evaluation, latency and cost will determine the production choice.
