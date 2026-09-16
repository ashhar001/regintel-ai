# Stage 1 Runbook — Bedrock Service Foundation

## Goal
Prove local AWS authentication, Bedrock inference, application configuration, structured response metadata, Docker packaging, and testability before adding RAG.

## Minimal Bedrock permission for the local identity
Use least privilege. For this non-streaming Stage 1 service, `bedrock:InvokeModel` is the key permission used by `Converse`.

Example scoped policy for Nova Lite in us-east-1:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "InvokeNovaLite",
      "Effect": "Allow",
      "Action": "bedrock:InvokeModel",
      "Resource": "arn:aws:bedrock:us-east-1::foundation-model/amazon.nova-lite-v1:0"
    }
  ]
}
```

Later stages will use separate application/runtime roles. Do not reuse an administrator user for ECS.

## Local setup

```bash
cp .env.example .env
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -e './backend[dev]'
```

If you use a named profile:

```bash
export AWS_PROFILE=your-profile
export AWS_REGION=us-east-1
aws sts get-caller-identity
```

## Start the API

```bash
uvicorn app.main:app --app-dir backend --reload --port 8000
```

## Smoke tests

```bash
curl http://localhost:8000/health
```

```bash
curl -X POST http://localhost:8000/v1/chat \
  -H 'Content-Type: application/json' \
  -d '{"question":"What will make this RAG system production-grade?"}'
```

## Important negative test
Ask a specific regulatory question before the KB exists:

```bash
curl -X POST http://localhost:8000/v1/chat \
  -H 'Content-Type: application/json' \
  -d '{"question":"What exact SEBI circular currently governs this obligation?"}'
```

The assistant should explicitly state that grounded regulatory retrieval is not yet connected rather than inventing a citation. This is intentional.

## Stage 1 acceptance criteria
- `/health` returns HTTP 200.
- `/v1/chat` successfully invokes Nova Lite.
- Response contains latency and token usage.
- A specific regulatory question is not fabricated.
- `pytest backend/tests -q` passes.
- Docker image builds.
- No AWS secrets exist in the repository or `.env` committed to Git.

## Troubleshooting
### AccessDeniedException
Confirm the caller identity and `bedrock:InvokeModel` permission for the selected model ARN.

### Credentials not found
Run `aws sts get-caller-identity` first. If using a named AWS profile, set `AWS_PROFILE` in the shell before starting Uvicorn.

### Model invocation fails
Confirm the configured region and model ID. Keep the model ID as `amazon.nova-lite-v1:0` for this stage.
