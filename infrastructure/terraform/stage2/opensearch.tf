resource "aws_opensearchserverless_security_policy" "encryption" {
  name        = substr("${local.name_prefix}-enc", 0, 32)
  type        = "encryption"
  description = "Encryption policy for RegIntel vector collection"

  policy = jsonencode({
    Rules = [
      {
        ResourceType = "collection"
        Resource     = ["collection/${local.vector_collection_name}"]
      }
    ]
    AWSOwnedKey = true
  })
}

resource "aws_opensearchserverless_security_policy" "network" {
  name        = substr("${local.name_prefix}-net", 0, 32)
  type        = "network"
  description = "Stage 2 network policy for RegIntel vector collection"

  policy = jsonencode([
    {
      Description = "Stage 2 bootstrap access"
      Rules = [
        {
          ResourceType = "collection"
          Resource     = ["collection/${local.vector_collection_name}"]
        },
        {
          ResourceType = "dashboard"
          Resource     = ["collection/${local.vector_collection_name}"]
        }
      ]
      AllowFromPublic = true
    }
  ])
}

resource "aws_opensearchserverless_collection" "vector" {
  name             = local.vector_collection_name
  type             = "VECTORSEARCH"
  standby_replicas = var.environment == "prod" ? "ENABLED" : "DISABLED"
  description      = "RegIntel Bedrock Knowledge Base vector collection"

  depends_on = [
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.network,
  ]
}

resource "aws_opensearchserverless_access_policy" "data" {
  name        = substr("${local.name_prefix}-data", 0, 32)
  type        = "data"
  description = "Data access for Bedrock KB and the Terraform provisioning principal"

  policy = jsonencode([
    {
      Description = "Bedrock KB and Terraform provisioning access"
      Rules = [
        {
          ResourceType = "collection"
          Resource     = ["collection/${local.vector_collection_name}"]
          Permission = [
            "aoss:DescribeCollectionItems",
          ]
        },
        {
          ResourceType = "index"
          Resource     = ["index/${local.vector_collection_name}/*"]
          Permission = [
            "aoss:CreateIndex",
            "aoss:DeleteIndex",
            "aoss:UpdateIndex",
            "aoss:DescribeIndex",
            "aoss:ReadDocument",
            "aoss:WriteDocument",
          ]
        }
      ]
      Principal = distinct([
        aws_iam_role.knowledge_base.arn,
        local.caller_principal_arn,
      ])
    }
  ])

  depends_on = [aws_opensearchserverless_collection.vector]
}

resource "time_sleep" "wait_for_aoss_policy" {
  create_duration = "60s"

  depends_on = [aws_opensearchserverless_access_policy.data]
}

resource "opensearch_index" "bedrock" {
  name      = local.vector_index_name
  index_knn = true

  mappings = jsonencode({
    properties = {
      (local.vector_field) = {
        type       = "knn_vector"
        dimension  = var.embedding_dimensions
        space_type = "l2"
        method = {
          name   = "hnsw"
          engine = "faiss"
          parameters = {
            ef_construction = 128
            m               = 24
          }
        }
      }
      (local.metadata_field) = {
        type  = "text"
        index = false
      }
      (local.text_field) = {
        type  = "text"
        index = true
      }

      # Filterable metadata fields used by RegIntel.
      document_id = {
        type = "text"
        fields = {
          keyword = {
            type         = "keyword"
            ignore_above = 256
          }
        }
      }

      regulator = {
        type = "text"
        fields = {
          keyword = {
            type         = "keyword"
            ignore_above = 256
          }
        }
      }

      jurisdiction = {
        type = "text"
        fields = {
          keyword = {
            type         = "keyword"
            ignore_above = 256
          }
        }
      }

      document_type = {
        type = "text"
        fields = {
          keyword = {
            type         = "keyword"
            ignore_above = 256
          }
        }
      }

      topic = {
        type = "text"
        fields = {
          keyword = {
            type         = "keyword"
            ignore_above = 256
          }
        }
      }

      entity_type = {
        type = "text"
        fields = {
          keyword = {
            type         = "keyword"
            ignore_above = 256
          }
        }
      }

      publication_date = {
        type = "text"
        fields = {
          keyword = {
            type         = "keyword"
            ignore_above = 256
          }
        }
      }

      publication_epoch = {
        type = "long"
      }

      effective_date = {
        type = "text"
        fields = {
          keyword = {
            type         = "keyword"
            ignore_above = 256
          }
        }
      }
    }
  })

  force_destroy = var.environment != "prod"
  lifecycle {
    ignore_changes = [
      mappings
    ]
  }

  depends_on = [time_sleep.wait_for_aoss_policy]
}
