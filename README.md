# chris-nelson-dev-backend

Serverless backend for the live status/latency API behind chris-nelson.dev, and the static HTML frontend hosted behind the same CloudFront/S3 stack. Terraform-provisioned AWS stack with Lambda + API Gateway + CloudFront + Route 53 health checks, optional WAF, CI, and tests.

## Architecture / Stack
- AWS: Lambda (Python), API Gateway HTTP API, CloudFront + S3 for frontend hosting, Route 53 health checks, optional WAF.
- IaC: Terraform (remote state config lives in `terraform/provider.tf`).
- CI: GitHub Actions (`.github/workflows/backend-ci.yml`) runs pytest, packages Lambda zips, and checks Terraform fmt/validate.
- Language: Python 3 for Lambdas.

## Repo Structure
- `lambda/` - `status_handler.py`, `status_api_handler.py`
- `terraform/` - CloudFront, WAF, API Gateway, Lambda, IAM, monitoring, certs, DNS
- `tests/` - smoke/unit tests for Lambda helper functions
- `.github/workflows/backend-ci.yml` - CI pipeline
- `.gitignore` - ignores venv, pyc, terraform state, zips

## Local Setup
1) Setup virtual python env: `python3 -m venv .venv && source .venv/bin/activate`
2) Install tooling: `python -m pip install pytest boto3`
3) Run tests: `python -m pytest`
4) Terraform sanity: `cd terraform && terraform init -backend=false && terraform validate`

## CI Behavior
- On push/PR: run pytest, build Lambda zips (uploaded as artifacts), and terraform fmt/validate.
- Make the workflow required in branch protection if you want to gate merges.

## Tests
- Run `python -m pytest`. Current tests cover helper functions (e.g., WAF status logic, region mapping) without needing AWS creds.
