# CI/CD Pipeline - Healthcare Lab Platform

## Overview

This repository contains a complete CI/CD pipeline implemented with GitHub Actions for the **Healthcare Lab Platform** project. The pipeline is designed to demonstrate continuous integration and deployment practices without performing actual deployments to AWS.

## What It Does

The pipeline is configured with `ENABLE_REAL_DEPLOY: 'false'`, which means:

- **All validations and tests are executed**
- **The complete CI/CD flow is simulated**
- **NO actual deployments to AWS are performed**
- **NO cloud resources are consumed**

### Why Aren't Terraform Plan/Apply Executed?

The project is **completed** and the main objective was to **learn how to use CI/CD** with different branching strategies. Therefore:

1. We didn't need to deploy real infrastructure
2. The pipeline serves only as an educational reference and reusable template
3. We can experiment with the flow without risk of affecting production environments

To enable real deployments, simply change `ENABLE_REAL_DEPLOY` to `'true'` in the environment variables.

## Pipeline Flow

### Triggers

The pipeline runs automatically when:

- A **Pull Request** is created towards `develop` or `main`
- A **Push** is made to `develop` or `main` branches
- It's executed **manually** (workflow_dispatch) by selecting the environment

## Pipeline Jobs

### 1. **Validate** - Code Validation

Executes code quality validations:

- **Python Linting** with `flake8`
- **Python Formatting** with `black`
- **Terraform Formatting** with `terraform fmt`
- **Terraform Validation** with `terraform validate`

**Runs:** On all events (PR, Push, Manual)

### 2. **Test** - Unit Tests

Executes the project's test suite:

- Unit tests with `pytest`
- Coverage report generation
- Upload results to Codecov

**Runs:** After `validate`, on all events

### 3. **Terraform Plan** - Infrastructure Planning

Generates a Terraform plan to review changes:

- Initializes Terraform
- Generates the change plan
- Comments the plan on the Pull Request

**Runs:** Only on Pull Requests  
**IMPORTANT:** Only displays an informational message

### 4. **Build Docker** - Image Building

Builds Docker images for the services:

- `processor`: Worker that processes data
- `portal`: Application web portal

**Runs:** Only on pushes to `develop` or `main`  
**Note:** Skips push to ECR

### 5. **Package Lambda** - Function Packaging

Packages Lambda functions:

- `ingest` → Data ingestion
- `notify` → Notification system
- `pdf_generator` → PDF report generation

**Runs:** Only on pushes to `develop` or `main`

### 6. **Deploy Staging** - Staging Deployment

Deploys the application to the development environment:

- Updates Lambda functions
- Executes `terraform apply`
- Updates ECS services
- Waits for services to be stable

**Runs:** Only on pushes to `develop`

### 7. **Deploy Production** - Production Deployment

Deploys the application to the production environment:

- Uses production-specific credentials
- Executes Terraform plan and apply
- Updates ECS services in production

**Runs:** Only on pushes to `main`

## Branch Strategy

- **`feature/*`**: Development of new features
- **`develop`**: Integration and testing branch (→ Staging)
- **`main`**: Stable production branch (→ Production)

### GitHub Secrets
That we configured, but didn't use for the reasons mentioned above.
- `AWS_ACCESS_KEY_ID`: AWS credentials for staging
- `AWS_SECRET_ACCESS_KEY`: AWS secret key for staging
- `AWS_ACCESS_KEY_ID_PROD`: AWS credentials for production
- `AWS_SECRET_ACCESS_KEY_PROD`: AWS secret key for production

## How to Use This Pipeline

### For Local Development

1. Create a feature branch from `develop`:
   ```bash
   git checkout develop
   git pull
   git checkout -b feature/new-functionality
   ```

2. Develop your code and make commits

3. Open a Pull Request towards `develop`:
   - These will run automatically: `validate`, `test`, `terraform-plan`
   - Review the results in the "Actions" tab

### To Deploy to Staging

1. Merge the PR to `develop`:
   ```bash
   git checkout develop
   git merge feature/new-functionality
   git push
   ```

2. The pipeline will automatically deploy to staging (because we have it set to not require authorization)

## Pipeline Monitoring

You can view the pipeline status in:

- **GitHub Actions**: "Actions" tab in the repository
- **Pull Requests**: Checks at the bottom of each PR
- **Branch Protection**: Configure rules to require successful checks

## Enable Real Deployments

To use the pipeline in a real environment:

1. Change `ENABLE_REAL_DEPLOY: 'true'`
2. Configure AWS secrets in GitHub (we have them configured)
3. Make sure to have the base infrastructure created
4. Adjust resource names according to your configuration