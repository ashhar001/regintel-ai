# ADR-002 — OpenSearch Serverless as the Stage 2 vector store

## Status
Accepted for the Stage 2 baseline.

## Context
RegIntel needs a vector store supported by Amazon Bedrock Knowledge Bases, metadata filtering, and a path to hybrid retrieval. We also want infrastructure that demonstrates AWS-native security and operational concerns rather than hiding the vector database behind a SaaS dependency.

## Decision
Use Amazon OpenSearch Serverless with a `VECTORSEARCH` collection and a manually managed FAISS vector index. Titan Text Embeddings V2 uses 1,024 dimensions for the baseline.

The Stage 2 development collection permits public network reachability so Terraform running on a developer laptop can create the data-plane vector index. Authorization is still restricted by IAM plus the OpenSearch Serverless data access policy. This is a bootstrap choice, not the final production network design.

## Consequences
- We can test semantic and hybrid retrieval against the same corpus.
- We can explicitly define filterable regulatory metadata fields.
- OpenSearch Serverless incurs running cost even for a small development corpus; destroy the Stage 2 stack when not being used.
- A later security stage will place the collection behind private VPC connectivity and give the application its own least-privilege runtime role.
