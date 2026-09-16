# Stage 5A — Guardrails, Observability, and Cost Controls

Stage 5A adds production safety and operational controls without changing the retrieval baseline established in Stage 4.

## Controls

- Bedrock Guardrail with content safety, prompt-attack filtering, PII anonymization, a PAN-like regex, a compliance-evasion denied topic, and contextual grounding/relevance checks.
- Versioned guardrail wired into `RetrieveAndGenerate` through `generationConfiguration.guardrailConfiguration`.
- Structured request logs with request IDs and latency.
- CloudWatch dashboard for Bedrock latency/tokens/errors, guardrail interventions, Step Functions ingestion health, and failure queues.
- Alarms for Bedrock server errors and throttling.
- Optional AWS Budget, disabled by default because budgets are account-level.

## Important limitation

Bedrock Guardrails applied to Knowledge Bases evaluate the user input and generated response, not the retrieved Knowledge Base references themselves. Treat retrieved source authorization and data classification as a separate control plane.
