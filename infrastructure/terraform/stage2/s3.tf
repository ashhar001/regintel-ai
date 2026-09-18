resource "aws_s3_bucket" "raw" {
  bucket        = "${local.name_prefix}-raw"
  force_destroy = var.environment != "prod"
}

resource "aws_s3_bucket" "processed" {
  bucket        = "${local.name_prefix}-processed"
  force_destroy = var.environment != "prod"
}

resource "aws_s3_bucket" "evaluation" {
  bucket        = "${local.name_prefix}-evaluation"
  force_destroy = var.environment != "prod"
}

resource "aws_s3_bucket_public_access_block" "raw" {
  bucket = aws_s3_bucket.raw.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "processed" {
  bucket = aws_s3_bucket.processed.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "evaluation" {
  bucket = aws_s3_bucket.evaluation.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "raw" {
  bucket = aws_s3_bucket.raw.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_ownership_controls" "processed" {
  bucket = aws_s3_bucket.processed.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_ownership_controls" "evaluation" {
  bucket = aws_s3_bucket.evaluation.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "raw" {
  bucket = aws_s3_bucket.raw.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "processed" {
  bucket = aws_s3_bucket.processed.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "evaluation" {
  bucket = aws_s3_bucket.evaluation.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.data.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "processed" {
  bucket = aws_s3_bucket.processed.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.data.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "evaluation" {
  bucket = aws_s3_bucket.evaluation.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.data.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_policy" "raw_tls_only" {
  bucket = aws_s3_bucket.raw.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.raw.arn,
          "${aws_s3_bucket.raw.arn}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_policy" "processed_tls_only" {
  bucket = aws_s3_bucket.processed.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.processed.arn,
          "${aws_s3_bucket.processed.arn}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_policy" "evaluation_tls_only" {
  bucket = aws_s3_bucket.evaluation.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.evaluation.arn,
          "${aws_s3_bucket.evaluation.arn}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

moved {
  from = aws_s3_bucket_public_access_block.this["raw"]
  to   = aws_s3_bucket_public_access_block.raw
}

moved {
  from = aws_s3_bucket_public_access_block.this["processed"]
  to   = aws_s3_bucket_public_access_block.processed
}

moved {
  from = aws_s3_bucket_public_access_block.this["evaluation"]
  to   = aws_s3_bucket_public_access_block.evaluation
}

moved {
  from = aws_s3_bucket_ownership_controls.this["raw"]
  to   = aws_s3_bucket_ownership_controls.raw
}

moved {
  from = aws_s3_bucket_ownership_controls.this["processed"]
  to   = aws_s3_bucket_ownership_controls.processed
}

moved {
  from = aws_s3_bucket_ownership_controls.this["evaluation"]
  to   = aws_s3_bucket_ownership_controls.evaluation
}

moved {
  from = aws_s3_bucket_versioning.this["raw"]
  to   = aws_s3_bucket_versioning.raw
}

moved {
  from = aws_s3_bucket_versioning.this["processed"]
  to   = aws_s3_bucket_versioning.processed
}

moved {
  from = aws_s3_bucket_versioning.this["evaluation"]
  to   = aws_s3_bucket_versioning.evaluation
}

moved {
  from = aws_s3_bucket_server_side_encryption_configuration.this["raw"]
  to   = aws_s3_bucket_server_side_encryption_configuration.raw
}

moved {
  from = aws_s3_bucket_server_side_encryption_configuration.this["processed"]
  to   = aws_s3_bucket_server_side_encryption_configuration.processed
}

moved {
  from = aws_s3_bucket_server_side_encryption_configuration.this["evaluation"]
  to   = aws_s3_bucket_server_side_encryption_configuration.evaluation
}

moved {
  from = aws_s3_bucket_policy.tls_only["raw"]
  to   = aws_s3_bucket_policy.raw_tls_only
}

moved {
  from = aws_s3_bucket_policy.tls_only["processed"]
  to   = aws_s3_bucket_policy.processed_tls_only
}

moved {
  from = aws_s3_bucket_policy.tls_only["evaluation"]
  to   = aws_s3_bucket_policy.evaluation_tls_only
}
