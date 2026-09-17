# Stage 7 SRE Runbook — SLOs, Error Budgets, Tracing, and Incident Triage

## Service objectives

RegIntel AI uses application-level CloudWatch EMF metrics from the `RegIntel/RAG` namespace.

### Availability SLO

- Objective: **99.9% successful RAG queries**.
- SLI numerator: successful `rag_query` requests.
- SLI denominator: all `rag_query` requests.
- Error budget: **0.1%** of RAG queries may fail during the measurement period.
- Error-rate signal: `100 * SUM(RAGErrorCount) / SUM(RAGRequestCount)`.

### Latency objective

- Objective: **p95 RAG query latency < 5 seconds**.
- SLI: `RAGLatencyMs` with `Operation=rag_query`.
- Existing alarm: `${name_prefix}-rag-p95-latency` after two consecutive 5-minute periods above 5000 ms.

Quality gates such as Hit@K, MRR, answer coverage, citation accuracy, and guardrail regression remain release-time quality controls rather than availability SLOs.

## Burn-rate alerting

For the 99.9% availability SLO, the error budget is 0.1%.

Stage 7C uses multi-window confirmation:

| Severity | Windows | Burn rate | Approx. error-rate threshold |
| --- | --- | ---: | ---: |
| Fast burn | 5 minutes AND 1 hour | 14.4x | 1.44% |
| Slow burn | 30 minutes AND 6 hours | 6x | 0.60% |

A composite alarm changes to ALARM only when both windows in its pair are breaching. This suppresses isolated spikes while detecting sustained budget consumption.

Composite alarms publish ALARM and OK transitions to the Stage 7C SNS topic.

Human notification endpoints attached to the SNS topic are intentionally treated as operational configuration rather than hard-coded repository configuration. This keeps personal endpoints out of the public repository while preserving the alerting topology in Terraform.

## Stage 7D tracing and correlation

API Gateway native X-Ray tracing is enabled on the deployed production stage.

The application propagates:

- `request_id` — application request correlation ID
- `trace_id` — API Gateway X-Ray root trace ID when the request traverses the deployed API Gateway stage

Both values are log/EMF properties rather than CloudWatch metric dimensions, preventing high-cardinality metric growth.

The application response exposes:

- `x-request-id`
- `x-trace-id` when present on the real deployed API Gateway request path

`aws apigateway test-invoke-method` does not exercise the deployed stage in the same way as the public endpoint, so its backend request may not contain the X-Ray trace header. Use the real public API path to validate X-Ray propagation.

## Dashboards

Primary operational dashboards:

- `${name_prefix}-sre` — application request, error, latency, retrieval, citation and guardrail signals
- `${name_prefix}-slo` — availability SLI and error-budget views
- `${name_prefix}-incident-diagnostics` — request/trace correlation, recent failures, Bedrock KB operations and RAG incident signals
- `${name_prefix}-runtime` — API Gateway / NLB / ECS runtime signals
- `${name_prefix}-rag-operations` — Bedrock/RAG operational signals

## Saved CloudWatch Logs Insights queries

Stage 7D creates reusable saved queries for:

- request/trace correlation
- application errors and failed requests
- Bedrock Knowledge Base calls

These queries target `/ecs/${name_prefix}/api`.

## Incident workflow

1. Confirm whether the alert is availability burn, latency, direct application error, API Gateway/NLB/ECS runtime degradation, or ingestion failure.
2. Open `${name_prefix}-slo`, `${name_prefix}-sre`, and `${name_prefix}-incident-diagnostics`.
3. Identify a failing `request_id` or `trace_id` from the incident-diagnostics dashboard.
4. Search the same ID across HTTP EMF, HTTP structured logs, RAG EMF and Bedrock Knowledge Base application logs.
5. If a real public request has a `trace_id`, use it to correlate the API Gateway edge request with application logs.
6. Determine whether the failure occurred before the application, inside ECS/FastAPI, in the Bedrock retrieval/generation path, or in an upstream ingestion dependency.
7. Check recent ECS task-definition deployments and the immutable image SHA before considering rollback.
8. If a recent release is strongly correlated with the regression, use the normal Stage 6 deployment process to restore the last known-good immutable image. Do not use Terraform to roll back CD-owned ECS task revisions.
9. Record impact, request IDs, trace IDs, alarm timestamps, suspected dependency, mitigation and follow-up action.

## Useful commands

List SLO and Stage 7 alarms:

```bash
aws cloudwatch describe-alarms \
  --profile tenderly \
  --region us-east-1 \
  --alarm-name-prefix regintel-dev-doziid \
  --query '{Metric:MetricAlarms[].{Name:AlarmName,State:StateValue},Composite:CompositeAlarms[].{Name:AlarmName,State:StateValue}}' \
  --output json
```

Inspect a correlated request:

```bash
REQ_ID='<request-id>'
aws logs filter-log-events \
  --log-group-name '/ecs/regintel-dev-doziid/api' \
  --filter-pattern "\"$REQ_ID\"" \
  --profile tenderly \
  --region us-east-1 \
  --query 'events[].message' \
  --output text
```

Inspect a trace ID:

```bash
TRACE_ID='<trace-id>'
aws logs filter-log-events \
  --log-group-name '/ecs/regintel-dev-doziid/api' \
  --filter-pattern "\"$TRACE_ID\"" \
  --profile tenderly \
  --region us-east-1 \
  --query 'events[].message' \
  --output text
```

Validate the public edge trace path:

```bash
curl -si 'https://bsx97wn0ze.execute-api.us-east-1.amazonaws.com/prod/health' \
  | grep -Ei 'HTTP/|x-request-id|x-trace-id'
```

Inspect recent RAG latency:

```bash
START=$(date -u -v-15M +'%Y-%m-%dT%H:%M:%SZ')
END=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
aws cloudwatch get-metric-statistics \
  --profile tenderly \
  --region us-east-1 \
  --namespace 'RegIntel/RAG' \
  --metric-name RAGLatencyMs \
  --dimensions Name=Service,Value=regintel-api Name=Environment,Value=dev Name=Operation,Value=rag_query \
  --start-time "$START" \
  --end-time "$END" \
  --period 60 \
  --extended-statistics p95 p99
```

## Safe alarm-routing validation

Validate the notification path without breaking production traffic by temporarily setting Stage 7C child metric alarm states. Do this only during an explicit test window and restore the state immediately afterward.

Example:

```bash
ALARM='regintel-dev-doziid-availability-burn-fast-5m'
aws cloudwatch set-alarm-state \
  --profile tenderly \
  --region us-east-1 \
  --alarm-name "$ALARM" \
  --state-value ALARM \
  --state-reason 'Stage 7C notification-path validation'

aws cloudwatch set-alarm-state \
  --profile tenderly \
  --region us-east-1 \
  --alarm-name "$ALARM" \
  --state-value OK \
  --state-reason 'Stage 7C validation complete'
```

For composite-alarm routing, both child alarms in the selected fast- or slow-burn pair must be set to ALARM during the test, then restored to OK. Do not inject real Bedrock, network or ECS failures in production merely to validate paging.

## Production failure-injection policy

- Production: use alarm-state simulation for paging-path verification and real incidents for signal validation.
- Non-production: dependency failure injection may be used to exercise Bedrock error handling, ECS rollback and recovery procedures.
- Never disable guardrails, corrupt the Knowledge Base, destroy Terraform resources, or revoke production IAM permissions as a chaos test.
- Preserve the Stage 6 ownership boundary: Terraform owns infrastructure; GitHub CD owns promoted ECS task revisions and immutable images.
