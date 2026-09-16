# Stage 6 migrates the main stack from workstation-local state to a versioned
# S3 backend. Runtime values are intentionally supplied with -backend-config so
# account-specific bucket names are not committed to source control.
terraform {
  backend "s3" {}
}
