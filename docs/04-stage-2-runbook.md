# Stage 2 Runbook — Bedrock Knowledge Base + OpenSearch Serverless

Stage 2 creates the first end-to-end RAG path:

`S3 -> Bedrock Knowledge Base -> Titan Text Embeddings V2 -> OpenSearch Serverless -> Retrieve / RetrieveAndGenerate -> FastAPI`

## 1. Prerequisites

Verify your AWS profile before Terraform:

```bash
export AWS_PROFILE=tenderly
export AWS_REGION=us-east-1
aws sts get-caller-identity
```

Your provisioning identity needs permissions to create IAM roles/policies, KMS keys, S3 buckets, OpenSearch Serverless resources and Bedrock Knowledge Bases. Creating the OpenSearch vector index also requires OpenSearch Serverless data-plane access.

Install Terraform 1.8+ on your Mac if it is not already installed.

## 2. Configure Terraform

```bash
cd infrastructure/terraform/stage2
cp terraform.tfvars.example terraform.tfvars
```

The sample already uses:

```hcl
aws_region  = "us-east-1"
aws_profile = "tenderly"
```

## 3. Initialize and review

```bash
terraform fmt -recursive
terraform init
terraform validate
terraform plan -out=stage2.tfplan
```

Review the plan before applying. It will create customer-managed KMS encryption for S3, three private/versioned buckets, an OpenSearch Serverless vector collection and index, a least-privilege Bedrock Knowledge Base service role, the Knowledge Base, and its S3 data source.

## 4. Apply

```bash
terraform apply stage2.tfplan
```

OpenSearch Serverless data policies can take time to propagate. The configuration deliberately waits before creating the vector index.

Capture outputs:

```bash
RAW_BUCKET=$(terraform output -raw raw_bucket_name)
KB_ID=$(terraform output -raw knowledge_base_id)
DS_ID=$(terraform output -raw data_source_id)
RAG_MODEL_ARN=$(terraform output -raw rag_model_arn)

echo "$RAW_BUCKET"
echo "$KB_ID"
echo "$DS_ID"
```

## 5. Upload the synthetic validation document

This document is intentionally synthetic. We use it to prove the pipeline before bringing in real regulatory documents.

From the repository root:

```bash
python scripts/upload_sample.py \
  --bucket "$RAW_BUCKET" \
  --profile tenderly \
  --region us-east-1
```

The upload contains both:

- `regintel-policy-001.txt`
- `regintel-policy-001.txt.metadata.json`

The metadata includes regulator, jurisdiction, topic, entity type, dates and a numeric publication epoch.

## 6. Start the Knowledge Base ingestion job

```bash
python scripts/sync_knowledge_base.py \
  --knowledge-base-id "$KB_ID" \
  --data-source-id "$DS_ID" \
  --profile tenderly \
  --region us-east-1
```

Wait for `status=COMPLETE`.

## 7. Configure the FastAPI service

From the repository root, update `.env`:

```dotenv
BEDROCK_KNOWLEDGE_BASE_ID=<KB_ID_FROM_TERRAFORM>
BEDROCK_RAG_MODEL_ARN=<RAG_MODEL_ARN_FROM_TERRAFORM>
```

Keep your normal local AWS profile environment:

```bash
export AWS_PROFILE=tenderly
export AWS_REGION=us-east-1
```

Restart FastAPI:

```bash
make run
```

## 8. Test retrieval independently

```bash
curl -s -X POST http://localhost:8000/v1/rag/retrieve \
  -H 'Content-Type: application/json' \
  -d '{
    "query": "How long must verification records be retained?",
    "number_of_results": 5,
    "search_type": "HYBRID",
    "filters": {
      "regulator": "REGINTEL_TEST",
      "topic": "KYC"
    }
  }' | python -m json.tool
```

You should receive source chunks, relevance scores, metadata and the S3 source URI.

## 9. Test grounded generation

```bash
curl -s -X POST http://localhost:8000/v1/rag/query \
  -H 'Content-Type: application/json' \
  -d '{
    "question": "How long must customer verification records be retained?",
    "number_of_results": 8,
    "search_type": "HYBRID",
    "filters": {
      "regulator": "REGINTEL_TEST",
      "topic": "KYC"
    }
  }' | python -m json.tool
```

Expected meaning: seven years after the customer relationship ends. The response should also contain citations pointing back to the source document.

## 10. Validate semantic versus hybrid search

Run the same `/v1/rag/retrieve` request twice, changing only:

```json
"search_type": "SEMANTIC"
```

and:

```json
"search_type": "HYBRID"
```

Do not decide which is better from one query. This endpoint exists so Stage 4 can evaluate retrieval over a proper test set.

## 11. Cost hygiene

OpenSearch Serverless is a continuously billed service. When you are finished experimenting and do not need the environment, destroy the Stage 2 stack:

```bash
cd infrastructure/terraform/stage2
terraform destroy
```

Do not destroy it if you want to continue immediately into the next stages.

## Stage 2 exit criteria

Stage 2 is complete only when all of these pass:

1. `terraform apply` completes.
2. The sample document and its metadata sidecar are in S3.
3. The Bedrock ingestion job is `COMPLETE`.
4. `/v1/rag/retrieve` returns the expected source chunk.
5. Metadata filtering works.
6. `/v1/rag/query` answers from the document and returns a citation.
7. Asking a question not supported by the corpus does not produce a confidently fabricated regulatory answer.
