locals {
  name_prefix = "regintel-${var.environment}-${random_string.suffix.result}"

  vector_collection_name = substr("${local.name_prefix}-vec", 0, 32)
  vector_index_name      = "regintel-vector-index-v2"

  vector_field   = "bedrock-knowledge-base-default-vector"
  text_field     = "AMAZON_BEDROCK_TEXT_CHUNK"
  metadata_field = "AMAZON_BEDROCK_METADATA"

  embedding_model_arn = "arn:${data.aws_partition.current.partition}:bedrock:${var.aws_region}::foundation-model/${var.embedding_model_id}"

  # OpenSearch Serverless data access policies require an IAM principal, not an STS session ARN.
  caller_arn_parts = split("/", data.aws_caller_identity.current.arn)
  inferred_caller_principal_arn = startswith(data.aws_caller_identity.current.arn, "arn:${data.aws_partition.current.partition}:sts::") && length(local.caller_arn_parts) >= 2 ? (
    "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${local.caller_arn_parts[1]}"
  ) : data.aws_caller_identity.current.arn

  caller_principal_arn = coalesce(var.aoss_admin_principal_arn, local.inferred_caller_principal_arn)
}
