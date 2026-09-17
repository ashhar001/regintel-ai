# Stage 7 SRE Runbook — SLOs, Error Budgets, and Incident Triage

## Service objectives

RegIntel AI uses application-level CloudWatch EMF metrics from the `RegIntel/RAG` namespace.

### Availability SLO

- Objective: **99.9% successful RAG queries**.
- SLI numerator: successful `rag_query` requests.
- SLI denominator: all `rag_query` requests.
- Error budget: **0.1%** of RAG queries may fail during the measurement period.
- Error-rate signal: `100 * SUM(RAGErrorCount) / SUM(RAGRequestCount)`.

### Latency SLO

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

Composite alarms publish ALARM and OK transitions to the Stage 7C SNS topic. The topic is intentionally created without a hard-coded human subscription; production notification destinations can be attached separately without changing the SLO logic.

## Incident workflow

1. Confirm whether the alert is availability burn, latency, or a direct application error alarm.
2. Open the `${name_prefix}-slo` and `${name_prefix}-sre` dashboards and compare request volume, error rate, and p95/p99 latency.
3. Pick a failing `request_id` from `/ecs/${name_prefix}/api` logs.
4. Search that same `request_id` to correlate HTTP EMF, HTTP application logs, RAG EMF, and Bedrock Knowledge Base application logs.
5. Determine whether the failure is before the application, inside ECS/FastAPI, or in the Bedrock retrieval/generation path.
6. Check recent ECS task-definition deployments and the immutable image SHA before considering rollback.
7. If a recent release is strongly correlated with the regression, use the normal Stage 6 deployment process to restore the last known-good immutable image. Do not use Terraform to roll back CD-owned ECS task revisions.
8. Record impact, request IDs, alarm timestamps, suspected dependency, mitigation, and follow-up action.

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

Inspect correlated application logs:

```bash
REQ_ID='<request-id>'
aws logs tail '/ecs/regintel-dev-doziid/api' \
  --profile tenderly \
  --region us-east-1 \
  --since 30m \
  --format short | grep "$REQ_ID"
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

Validate the notification path without breaking production traffic by temporarily setting a Stage 7C child metric alarm state. Do this only during an explicit test window and restore the state immediately afterward.

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

For composite-alarm routing, both child alarms in the selected fast- or slow-burn pair must be set to ALARM during the test, then restored to OK. Do not inject real Bedrock, network, or ECS failures in production merely to validate paging.

## Production failure-injection policy

- Production: use alarm-state simulation for paging-path verification and real incidents for signal validation.
- Non-production: dependency failure injection may be used to exercise Bedrock error handling, ECS rollback, and recovery procedures.
- Never disable guardrails, corrupt the Knowledge Base, destroy Terraform resources, or revoke production IAM permissions as a chaos test.
- Preserve the Stage 6 ownership boundary: Terraform owns infrastructure; GitHub CD owns promoted ECS task revisions and immutable images.
