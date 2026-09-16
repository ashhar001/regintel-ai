output "raw_bucket_name" {
  value       = aws_s3_bucket.raw.id
  description = "Upload source documents and .metadata.json sidecars under documents/."
}

output "processed_bucket_name" {
  value       = aws_s3_bucket.processed.id
  description = "Reserved for later transformation/enrichment stages."
}

output "evaluation_bucket_name" {
  value       = aws_s3_bucket.evaluation.id
  description = "Reserved for RAG evaluation datasets and outputs."
}

output "knowledge_base_id" {
  value       = aws_bedrockagent_knowledge_base.this.id
  description = "Set this as BEDROCK_KNOWLEDGE_BASE_ID in the API environment."
}

output "data_source_id" {
  value       = aws_bedrockagent_data_source.s3.data_source_id
  description = "Bedrock S3 data source ID used to start ingestion jobs."
}

output "vector_collection_endpoint" {
  value       = aws_opensearchserverless_collection.vector.collection_endpoint
  description = "OpenSearch Serverless collection endpoint."
}

output "vector_index_name" {
  value       = opensearch_index.bedrock.name
  description = "OpenSearch vector index backing the Knowledge Base."
}

output "embedding_model_arn" {
  value       = local.embedding_model_arn
  description = "Embedding model configured for the Knowledge Base."
}

output "rag_model_arn" {
  value       = "arn:${data.aws_partition.current.partition}:bedrock:${var.aws_region}::foundation-model/amazon.nova-lite-v1:0"
  description = "Stage 2 generation model ARN to set as BEDROCK_RAG_MODEL_ARN."
}

output "ingestion_queue_url" {
  value       = aws_sqs_queue.ingestion.id
  description = "Stage 3 ingestion queue URL."
}

output "ingestion_dlq_url" {
  value       = aws_sqs_queue.ingestion_dlq.id
  description = "Stage 3 ingress dead-letter queue URL."
}

output "workflow_failure_queue_url" {
  value       = aws_sqs_queue.workflow_failures.id
  description = "Failed workflow details are written here."
}

output "ingestion_table_name" {
  value       = aws_dynamodb_table.ingestion.name
  description = "Idempotency and ingestion-status table."
}

output "ingestion_state_machine_arn" {
  value       = aws_sfn_state_machine.ingestion.arn
  description = "Automated document ingestion state machine."
}

output "ingestion_pipe_arn" {
  value       = aws_pipes_pipe.ingestion.arn
  description = "EventBridge Pipe connecting SQS to the ingestion state machine."
}

