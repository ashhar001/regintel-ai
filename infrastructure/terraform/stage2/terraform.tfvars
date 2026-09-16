aws_region  = "us-east-1"
aws_profile = "tenderly"

environment  = "dev"
project_name = "regintel-ai"

# If aws sts get-caller-identity returns an IAM user ARN, leave this unset.
# If it returns an STS assumed-role ARN and Terraform gets an AOSS 403, set the
# underlying IAM role ARN here.
# aoss_admin_principal_arn = "arn:aws:iam::123456789012:role/example-role"

# Baseline values; Stage 4 will benchmark these.
embedding_dimensions     = 1024
chunk_max_tokens         = 512
chunk_overlap_percentage = 15
stage5b_image_tag        = "stage5b-v2"
stage5b_runtime_enabled  = true
