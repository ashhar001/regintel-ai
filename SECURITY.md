# Security Policy

## Reporting a Vulnerability

Please report security concerns privately to the repository owner. Do not open a public issue for suspected vulnerabilities, exposed credentials, or infrastructure details.

Include a concise description, affected component, reproduction steps if safe to share, and any relevant logs with secrets redacted.

## Public Repository Hygiene

Never commit local secrets or environment-specific infrastructure artifacts, including:

- `.env` files
- Terraform state files: `terraform.tfstate*`
- Terraform plan files: `*.tfplan*`
- `.terraform/` plugin and backend directories
- AWS account-specific outputs, live API URLs, credentials, tokens, or private keys

The `/health` endpoint is intentionally unauthenticated for load balancers and uptime checks. All `/v1/*` API routes are intended to be reached only through API Gateway with the Cognito authorizer enabled; do not expose the internal NLB or ECS task endpoint directly.
