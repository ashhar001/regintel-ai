# Stage 6 CI: grants the GitHub Terraform plan role access required for PR validation.
# The OpenSearch provider performs data-plane reads while refreshing the vector
# index during Terraform plan. This separate policy is additive and avoids
# changing the Stage 2 Bedrock/administrator access policy.
resource "aws_opensearchserverless_access_policy" "stage6_ci" {
  count = try(trimspace(var.stage6_ci_role_arn), "") != "" ? 1 : 0

  name        = substr("${local.name_prefix}-ci", 0, 32)
  type        = "data"
  description = "Read-only vector-index access for the GitHub Terraform plan role"

  policy = jsonencode([
    {
      Description = "GitHub Actions Terraform plan read access"
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
            "aoss:DescribeIndex",
            "aoss:ReadDocument",
          ]
        },
      ]
      Principal = [var.stage6_ci_role_arn]
    }
  ])

  depends_on = [aws_opensearchserverless_collection.vector]
}
