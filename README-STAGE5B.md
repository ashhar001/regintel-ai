# RegIntel AI — Stage 5B Overlay

Adds production runtime hosting around the existing RAG stack:

- ECR with immutable/scanned images
- private two-AZ VPC
- no NAT gateway / no public ECS IPs
- PrivateLink endpoints for ECR, Logs, Bedrock Runtime, and Bedrock Agent Runtime
- S3 gateway endpoint
- ECS Fargate + internal NLB + target health checks
- CPU target-tracking autoscaling
- API Gateway REST API + private VPC Link
- Cognito user-pool authorization for `/v1/*`
- AWS WAF managed common rules + per-IP rate limiting
- runtime CloudWatch dashboard and alarms

Read `docs/09-stage-5b-production-deployment.md` before applying. Deployment intentionally uses two Terraform applies so an ECS service is never started before its immutable ECR image exists.
