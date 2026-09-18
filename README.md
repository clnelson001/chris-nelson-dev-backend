# chris-nelson-dev-backend

Serverless AWS backend and infrastructure for **chris-nelson.dev**.

This project is a hands-on cloud engineering environment I built to design, deploy, and operate AWS infrastructure using Terraform. It powers the live status and latency APIs for my personal site and manages the supporting AWS infrastructure.

The stack includes **AWS Lambda, API Gateway, CloudFront, S3, Route 53, IAM, CloudWatch, ACM, and optional AWS WAF**, with **Terraform** for infrastructure as code and **GitHub Actions** for testing and validation.

## Architecture

The site uses a serverless AWS architecture with CloudFront providing the public entry point for the static frontend and API Gateway exposing backend API endpoints implemented with Python Lambda functions.

```text
                         ┌─────────────────┐
                         │    Route 53     │
                         │   DNS / Health  │
                         │     Checks      │
                         └────────┬────────┘
                                  │
                                  ▼
                         ┌─────────────────┐
                         │   CloudFront    │
                         │      CDN        │
                         └───────┬─────────┘
                                 │
                    ┌────────────┴────────────┐
                    │                         │
                    ▼                         ▼
             ┌─────────────┐          ┌─────────────┐
             │     S3      │          │ API Gateway │
             │   Static    │          │  HTTP API   │
             │   Website   │          └──────┬──────┘
             └─────────────┘                 │
                                             ▼
                                      ┌─────────────┐
                                      │   Lambda    │
                                      │   Python    │
                                      └──────┬──────┘
                                             │
                                  ┌──────────┴──────────┐
                                  │                     │
                                  ▼                     ▼
                           ┌─────────────┐       ┌─────────────┐
                           │ CloudWatch  │       │  Route 53   │
                           │   Alarms    │       │Health Checks│
                           └─────────────┘       └─────────────┘
```

Infrastructure is provisioned and managed with Terraform.

## What It Does

The backend provides API endpoints used by the frontend to report the health and performance of the site.

### `/status`

Returns the overall health of the site based on AWS monitoring state.

### `/status/latency`

Performs a real HTTPS request to the site and reports observed connection latency.

### `/status/health-checkers`

Retrieves Route 53 health-check observations used by the frontend for regional health visibility.

## AWS Services

The project uses several AWS services together as a small production-style serverless environment:

- **Lambda** — Python backend functions
- **API Gateway** — HTTP API endpoints
- **CloudFront** — CDN and public distribution layer
- **S3** — static frontend hosting
- **Route 53** — DNS and health checks
- **CloudWatch** — monitoring and alarm state
- **IAM** — execution roles and least-privilege permissions
- **ACM** — TLS certificates
- **AWS WAF** — optional web application firewall protection

## Infrastructure as Code

AWS infrastructure is defined using **Terraform** rather than being configured manually.

Terraform manages resources including:

- Lambda functions
- IAM roles and policies
- API Gateway
- CloudFront
- S3
- Route 53
- ACM certificates
- CloudWatch monitoring
- Optional WAF configuration

Terraform configuration is located under:

```text
terraform/
```

Remote-state configuration is defined in:

```text
terraform/provider.tf
```

## Repository Structure

```text
.
├── .github/
│   └── workflows/
│       └── backend-ci.yml
│
├── lambda/
│   ├── status_handler.py
│   └── status_api_handler.py
│
├── terraform/
│   └── ...
│
├── tests/
│   └── ...
│
└── .gitignore
```

### `lambda/`

Python Lambda functions implementing the backend API.

### `terraform/`

Terraform configuration for the AWS infrastructure, including networking-facing services, API resources, IAM, monitoring, certificates, DNS, and security controls.

### `tests/`

Unit and smoke tests for backend helper functions.

### `.github/workflows/backend-ci.yml`

GitHub Actions workflow used to validate changes.

## CI

GitHub Actions runs automated validation on pushes and pull requests.

The workflow:

1. Sets up the Python environment
2. Runs the pytest test suite
3. Packages the Lambda deployment artifacts
4. Runs Terraform formatting checks
5. Runs Terraform validation

This provides basic validation of both the application code and infrastructure configuration before changes are deployed.

## Tests

Tests are written with **pytest**.

Current tests exercise Lambda helper functionality such as WAF status handling and AWS region mapping without requiring live AWS credentials.

Run the tests locally with:

```bash
python -m pytest
```

## Local Development

Create a Python virtual environment:

```bash
python3 -m venv .venv
source .venv/bin/activate
```

Install the required Python tooling:

```bash
python -m pip install pytest boto3
```

Run the test suite:

```bash
python -m pytest
```

Validate the Terraform configuration without connecting to the remote backend:

```bash
cd terraform
terraform init -backend=false
terraform fmt -check
terraform validate
```

## Engineering Goals

This project serves as a practical environment for developing and reinforcing cloud engineering skills, including:

- AWS service integration
- Serverless application design
- Infrastructure as code with Terraform
- IAM roles and permissions
- DNS and TLS configuration
- CDN and API integration
- Monitoring and health checks
- Python-based AWS automation
- CI validation for application and infrastructure changes

The infrastructure is intentionally small enough to operate as a personal project while using the same AWS building blocks and operational practices found in larger cloud environments.

## Live Site

The infrastructure supports:

**https://chris-nelson.dev**

The site's status functionality uses the backend APIs contained in this repository.