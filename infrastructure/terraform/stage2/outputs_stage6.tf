output "data_kms_key_arn" {
  value       = aws_kms_key.data.arn
  description = "CMK used by RegIntel data and the encrypted Bedrock Guardrail."
}
