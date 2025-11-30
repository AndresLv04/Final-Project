# Healthcare Lab Platform

**Project Description**

## What is Healthcare Lab Platform?

Healthcare Lab Platform is a comprehensive solution that enables clinical laboratories to deliver test results to patients in a secure and efficient way. The system aggregates data from multiple laboratories, normalizes different formats (JSON, HL7, XML, CSV), and provides an intuitive web portal for patients to access their results.

---

## System Goals

- Multi-Lab Aggregation: Receives results from multiple laboratories with different formats and systems.

- Security: Complies with HIPAA standards through end-to-end encryption and robust access control.

- Scalability: Serverless and containerized architecture that automatically scales based on demand.

- Availability: Highly available system with automatic failure recovery.

- User Experience: Modern, responsive web portal for viewing results.
---

## Prerequisites

Before you start, you need:

- **AWS account** with permissions for:  
  VPC, EC2, IAM, S3, SQS, SNS, RDS, Lambda, API Gateway, Cognito, ECS, CloudWatch, ACM, Route53.
- **AWS CLI** configured
- **Terraform / OpenTofu** (v1.6+ recommended)
- **Docker** installed
- **Python 3.11+** for test scripts (Cognito, ingestion)

---

## 🔧 Initial Setup

### 1. Clone the Repository
```bash
git clone <REPO_URL>
cd healthcare-lab-platform
```

### 2. Configure AWS Environment
```bash
export AWS_PROFILE=default    
export AWS_REGION=us-east-1     
```

### 3. Environment Variables / tfvars (development)

In `environments/development/`, create or adjust your variables file (e.g., `dev.tfvars`):

```hcl
project_name = "healthcare-lab-platform"
environment  = "dev"
owner        = "andres"
# ...other network, RDS, ECS parameters, etc.
```

---

## Infrastructure Deployment

From `environments/development`:

```bash
cd environments/development

tofu init
tofu plan  -var-file="terraform.tfvars"
tofu apply -var-file="terraform.tfvars"
```

This creates the following resources, among others:

### Network and Security
- VPC, public/private subnets, NAT Gateway, route tables
- Security Groups for ALB, ECS, RDS, Lambda, VPC endpoints

### Data
- S3 Buckets (data + logs)
- SQS (main queue + DLQ)
- RDS PostgreSQL

### Processing
- Lambdas (ingest, notify, pdf)
- API Gateway (ingestion, health, pdf endpoints)
- ECS Worker (processes SQS messages and loads into RDS)

### Authentication and Portal
- Cognito (User Pool, Web Client, Hosted UI)
- Application Load Balancer for the portal
- ECS Fargate service for the patient portal
- (Optional) CloudFront in front of the ALB

### Review Outputs

After deployment, review the outputs:

```bash
tofu output
```

Important outputs:
- `api_endpoint`, `api_ingest_endpoint`, `api_key_value`
- `db_address`, `db_name`
- `cognito_user_pool_id`, `cognito_web_client_id`, `cognito_hosted_ui_url`
- `alb_portal_url` and/or `portal_url`
- `portal_ecr_repository`

---

## 🖥️ Local Portal Management

The portal is located in `services/portal` and is a Flask application.

### 1. Run Locally

```bash
cd services/portal
python -m venv .venv
source .venv/bin/activate    
pip install -r requirements.txt
```

Configure environment variables (minimum example):

```bash
export COGNITO_REGION=us-east-1
export COGNITO_USER_POOL_ID=...
export COGNITO_CLIENT_ID=...
export COGNITO_DOMAIN=...
export CALLBACK_URL=http://localhost:5000/callback
export LOGOUT_URL=http://localhost:5000
export DB_HOST=...
export DB_PORT=5432
export DB_NAME=...
export DB_USER=...
export DB_PASSWORD=...
```

Launch the server:

```bash
python app.py
```

You can point to RDS in AWS (if your IP is allowed) or to a local PostgreSQL database with the same schema.

---

## Portal Deployment / Update in ECS

### Build & Push Docker Image to ECR

From the repository root:

```bash
./scripts/build-and-push-portal.sh dev
```

The script:
- Obtains the Account ID
- Builds the image with the Dockerfile from `services/portal`
- Pushes it to `healthcare-lab-platform-dev-portal` in ECR
- (Optional) Forces a new deployment of the ECS service

### First Portal Deployment (if service doesn't exist)

```bash
cd environments/development
tofu apply -var-file="dev.tfvars" -target=module.ecs_portal
```

### Portal Logs

```bash
aws logs tail "/ecs/healthcare-lab-platform-dev/portal" \
  --follow --region us-east-1
```

### Portal URL

```bash
tofu output portal_url     # or alb_portal_url
```

---

## How to Test

### 1. Health Checks

**Portal / ALB:**

```bash
curl -i "$(tofu output -raw portal_url)/health"
```

Expected response:
```json
{"database":"connected","status":"healthy"}
```

**API Gateway:**

```bash
curl -i "$(tofu output -raw api_health_endpoint)"
```

### 2. Cognito Login Test

Using the Cognito test script:

```bash
python scripts/cognito_auth_tester.py \
  --user-pool-id "$(tofu output -raw cognito_user_pool_id)" \
  --client-id   "$(tofu output -raw cognito_web_client_id)" \
  --action login \
  --email YOUR_EMAIL
```

Allows testing:
- User registration and confirmation
- Login
- Password change
- Token refresh

### 3. End-to-End Ingestion Test

(Lab → API → S3/SQS → Worker → RDS → Portal)

Laboratory message sending script:

```bash
python scripts/send_test_message.py \
  --api-url "$(tofu output -raw api_endpoint)" \
  --api-key "$(tofu output -raw api_key_value)" \
  --count 5
```

**Flow:**
1. Generates result messages (CBC, CMP, etc.) with fictitious patients and laboratories
2. Sends messages to the `/api/v1/ingest` endpoint of API Gateway
3. Lambda stores data in S3 and/or SQS
4. ECS Worker processes the queue and saves to RDS
5. Patient views their results in the portal (dashboard filtered by `patient_id` from the Cognito token)

---

## ⚙️ CI/CD (Academic Mode)

The project includes a GitHub Actions pipeline:

- **validate:** Python linting + terraform validate
- **test:** Unit test execution
- **terraform-plan:** Infrastructure plan (only in real mode)
- **build-docker, package-lambda, deploy-staging, deploy-production:**
  - These jobs are skipped by default because the `ENABLE_REAL_DEPLOY` variable is set to `false` (safe for public repositories and academic use)

To enable real deployments, you can change:

```yaml
env:
  ENABLE_REAL_DEPLOY: true
```

  **Warning:** This will deploy real resources in AWS, so it should only be done in a controlled environment.

---

##  Known Limitations

- **Educational/Demo Environment:**  
  Although best practices are followed, no formal HIPAA/PCI review or complete production hardening has been performed.

- **Simplified Patient Matching:**  
  Patient matching rules (IDs, name, date of birth) are basic and do not equate to a complete Master Patient Index (MPI).

- **Partial Format Coverage:**  
  The architecture contemplates JSON / HL7 / XML / CSV, but some parsers/adapters are prototypes and don't cover all real-world variants.

- **AWS Costs:**  
  Using RDS, NAT Gateway, ALB, ECS, etc. incurs real costs even in dev. It's recommended to configure budgets and shut down resources when not in use.

- **Single Region:**  
  Currently deployed in a single region (e.g., us-east-1). Multi-region and DR are not automated.

---
