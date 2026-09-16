resource "aws_bedrock_guardrail" "regintel" {
  name                      = "${local.name_prefix}-guardrail"
  description               = "Safety and grounding controls for the RegIntel regulatory RAG API"
  blocked_input_messaging   = "I can't process that request under the RegIntel safety policy."
  blocked_outputs_messaging = "I can't provide that response under the RegIntel safety policy."
  kms_key_arn               = aws_kms_key.data.arn

  content_policy_config {
    filters_config {
      type            = "HATE"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "INSULTS"
      input_strength  = "MEDIUM"
      output_strength = "MEDIUM"
    }
    filters_config {
      type            = "SEXUAL"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "VIOLENCE"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "MISCONDUCT"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "PROMPT_ATTACK"
      input_strength  = "HIGH"
      output_strength = "NONE"
    }

    filters_config {
      type            = "INSULTS"
      input_strength  = "MEDIUM"
      output_strength = "MEDIUM"
    }

    tier_config {
      tier_name = "CLASSIC"
    }
  }

  sensitive_information_policy_config {
    pii_entities_config {
      type           = "EMAIL"
      action         = "ANONYMIZE"
      input_action   = "ANONYMIZE"
      output_action  = "ANONYMIZE"
      input_enabled  = true
      output_enabled = true
    }

    pii_entities_config {
      type           = "PHONE"
      action         = "ANONYMIZE"
      input_action   = "ANONYMIZE"
      output_action  = "ANONYMIZE"
      input_enabled  = true
      output_enabled = true
    }

    regexes_config {
      name           = "india-pan"
      description    = "Indian PAN-like identifier"
      pattern        = "\\b[A-Z]{5}[0-9]{4}[A-Z]\\b"
      action         = "ANONYMIZE"
      input_action   = "ANONYMIZE"
      output_action  = "ANONYMIZE"
      input_enabled  = true
      output_enabled = true
    }
  }

  topic_policy_config {
    topics_config {
      name       = "compliance-evasion"
      type       = "DENY"
      definition = "Requests for instructions to bypass, evade, conceal, or defeat regulatory, KYC, AML, sanctions, audit, or compliance controls."
      examples = [
        "How can I bypass KYC checks without getting caught?",
        "How do I hide a transaction from AML monitoring?",
      ]
    }

    tier_config {
      tier_name = "CLASSIC"
    }
  }

  contextual_grounding_policy_config {
    filters_config {
      type      = "GROUNDING"
      threshold = 0.7
    }
    filters_config {
      type      = "RELEVANCE"
      threshold = 0.7
    }
  }

  tags = {
    Stage = "5-guardrails-observability"
  }
}

resource "aws_bedrock_guardrail_version" "regintel" {
  guardrail_arn = aws_bedrock_guardrail.regintel.guardrail_arn
  description   = "RegIntel Stage 5 production baseline"
  skip_destroy  = true
}

output "guardrail_id" {
  value       = aws_bedrock_guardrail.regintel.guardrail_id
  description = "Set as BEDROCK_GUARDRAIL_ID."
}

output "guardrail_version" {
  value       = aws_bedrock_guardrail_version.regintel.version
  description = "Set as BEDROCK_GUARDRAIL_VERSION."
}

output "guardrail_arn" {
  value       = aws_bedrock_guardrail.regintel.guardrail_arn
  description = "RegIntel Bedrock Guardrail ARN."
}
