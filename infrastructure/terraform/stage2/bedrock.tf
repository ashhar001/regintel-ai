resource "aws_bedrockagent_knowledge_base" "this" {
  name        = "${local.name_prefix}-kb"
  description = "RegIntel financial regulatory knowledge base"
  role_arn    = aws_iam_role.knowledge_base.arn

  knowledge_base_configuration {
    type = "VECTOR"

    vector_knowledge_base_configuration {
      embedding_model_arn = local.embedding_model_arn

      embedding_model_configuration {
        bedrock_embedding_model_configuration {
          dimensions          = var.embedding_dimensions
          embedding_data_type = "FLOAT32"
        }
      }
    }
  }

  storage_configuration {
    type = "OPENSEARCH_SERVERLESS"

    opensearch_serverless_configuration {
      collection_arn    = aws_opensearchserverless_collection.vector.arn
      vector_index_name = opensearch_index.bedrock.name

      field_mapping {
        vector_field   = local.vector_field
        text_field     = local.text_field
        metadata_field = local.metadata_field
      }
    }
  }

  depends_on = [
    aws_iam_role_policy.kb_base,
    aws_iam_role_policy.kb_aoss,
    opensearch_index.bedrock,
  ]
}

resource "aws_bedrockagent_data_source" "s3" {
  knowledge_base_id    = aws_bedrockagent_knowledge_base.this.id
  name                 = "${local.name_prefix}-s3"
  description          = "Regulatory documents stored in the RegIntel raw bucket"
  data_deletion_policy = "DELETE"

  data_source_configuration {
    type = "S3"

    s3_configuration {
      bucket_arn              = aws_s3_bucket.raw.arn
      bucket_owner_account_id = data.aws_caller_identity.current.account_id
      inclusion_prefixes      = ["documents/"]
    }
  }

  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = "FIXED_SIZE"

      fixed_size_chunking_configuration {
        max_tokens         = var.chunk_max_tokens
        overlap_percentage = var.chunk_overlap_percentage
      }
    }
  }

  lifecycle {
    replace_triggered_by = [
      aws_bedrockagent_knowledge_base.this.id
    ]
  }
}
