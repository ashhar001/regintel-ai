# RegIntel AI — Production Amazon Bedrock RAG Platform

A production-oriented financial regulatory intelligence platform built to demonstrate Amazon Bedrock RAG engineering end to end.

## Current status
- Stage 0: complete — product/NFR/architecture contract
- Stage 1: complete — FastAPI + Bedrock Converse foundation
- Stage 2: implemented — Terraform RAG foundation + Bedrock Knowledge Base API integration
- Stage 3+: delivered incrementally after each previous stage passes its exit criteria

## Stage 2 architecture

```text
Synthetic / regulatory documents + metadata sidecars
                      |
                      v
              S3 raw/documents
                      |
                      v
            Bedrock Knowledge Base
                      |
       Titan Text Embeddings V2
                      |
                      v
         OpenSearch Serverless
          FAISS vector index
                      |
          +-----------+-----------+
          |                       |
          v                       v
/v1/rag/retrieve          /v1/rag/query
retrieval + scores        RetrieveAndGenerate
metadata + source URI     grounded answer + citations
```

Stage 2 keeps retrieval and generation as separate application paths. This lets later evaluation measure retrieval quality independently from generation quality.

## Infrastructure created in Stage 2
- Customer-managed KMS key for S3 data encryption
- Private, versioned raw / processed / evaluation S3 buckets
- OpenSearch Serverless `VECTORSEARCH` collection
- FAISS k-NN index with Titan V2 1,024-dimensional vectors
- Explicit filterable regulatory metadata fields
- Least-privilege Bedrock Knowledge Base service role
- Bedrock Knowledge Base using Titan Text Embeddings V2
- S3 Knowledge Base data source with baseline fixed-size chunking

The Stage 2 development collection permits public network reachability so Terraform on a developer laptop can create the OpenSearch data-plane index. IAM and OpenSearch data policies still control authorization. VPC-only connectivity is a later hardening step.

## Prerequisites
- Python 3.12+
- Terraform 1.8+
- AWS CLI configured
- Amazon Bedrock model access/permissions
- Docker (optional)

## Run the API locally

```bash
cp .env.example .env
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -e './backend[dev]'
uvicorn app.main:app --app-dir backend --reload --port 8000
```

If you use a named local AWS CLI profile:

```bash
export AWS_PROFILE=tenderly
export AWS_REGION=us-east-1
aws sts get-caller-identity
```

## Deploy Stage 2

Follow the full runbook:

`docs/04-stage-2-runbook.md`

The short path is:

```bash
cd infrastructure/terraform/stage2
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform validate
terraform plan -out=stage2.tfplan
terraform apply stage2.tfplan
```

Then upload the synthetic validation corpus, run a Knowledge Base sync, populate the two Stage 2 environment variables, and test the RAG endpoints.

## RAG endpoints

### Retrieval only

`POST /v1/rag/retrieve`

```json
{
  "query": "How long must verification records be retained?",
  "number_of_results": 5,
  "search_type": "HYBRID",
  "filters": {
    "regulator": "REGINTEL_TEST",
    "topic": "KYC"
  }
}
```

Returns retrieved chunks, relevance scores, source URI and metadata.

### Retrieve + generate

`POST /v1/rag/query`

```json
{
  "question": "How long must customer verification records be retained?",
  "number_of_results": 8,
  "search_type": "HYBRID",
  "filters": {
    "regulator": "REGINTEL_TEST",
    "topic": "KYC"
  }
}
```

Returns a grounded answer, Bedrock session ID, latency and citations.

## Tests

```bash
pytest backend/tests -q
ruff check backend
```

## Cost hygiene

OpenSearch Serverless is continuously billed. Destroy development infrastructure when you are not using it:

```bash
terraform -chdir=infrastructure/terraform/stage2 destroy
```

## Engineering principle
Every RAG optimization will be measured against a versioned evaluation dataset. Semantic search, hybrid retrieval, chunking, reranking and model changes will not be called improvements until the metrics support the claim.

See `docs/02-roadmap.md` for the full delivery sequence.
