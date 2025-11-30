# 💰 Cost Analysis - Healthcare Lab Platform

**Scenario:** Regional health network with 15 independent laboratories
**Volume:** 220,000 lab results per month (7,300 per day)
**Region:** US East (N. Virginia) - us-east-1

---

## 💻 Detailed Cost Breakdown

### 1. Compute Services

#### 1.1 ECS Fargate - Worker Service

**Purpose:** Process lab results from SQS queue

**Configuration:**
- vCPU: 0.5 per task
- Memory: 1 GB per task
- Average tasks: 1.5 (auto-scales 1-4)
- Runtime: 730 hours/month (24/7)
```

**Monthly Cost:** $27/month

#### 1.2 ECS Fargate - Portal Service

**Purpose:** Patient-facing web application

**Configuration:**
- vCPU: 0.25 per task
- Memory: 512 MB per task
- Average tasks: 1.2 (auto-scales 1-3)
- Runtime: 730 hours/month (24/7)

```

**Monthly Cost:** $11/month

#### 1.3 AWS Lambda Functions

**Functions:**
1. **Ingest:** Receives lab results (225k invocations)
2. **Notify:** Sends email notifications (225k invocations)
3. **PDF Generator:** Creates PDF reports (150k invocations)

**Configuration:**
- Total requests: 600,000/month
- Average duration: 1 second
- Average memory: 256 MB

---

### 2. Networking Services

#### 2.1 NAT Gateway

**Purpose:** Allow private subnets to access internet

**Configuration:**
- Number of NAT Gateways: 1
- Data processed: 500 GB/month

**Calculation:**
```
Hourly charge: 730 hours × $0.045 = $32.85
Data processing: 500 GB × $0.045 = $22.50
Total: $55.35/month
```
#### 2.2 Application Load Balancer (ALB)

**Purpose:** Distribute traffic to Portal service

**Configuration:**
- Number of ALBs: 1
- Hours: 730/month
- LCUs: ~2 average

---

### 3. Storage Services

#### 3.1 Amazon RDS (PostgreSQL)

**Purpose:** Store lab results, patient data, audit logs

**Configuration:**
- Instance: db.t3.small (2 vCPU, 2 GB RAM)
- Storage: 50 GB gp3
- Deployment: Multi-AZ
- Backup: 50 GB

#### 3.2 Amazon S3

**Purpose:** Store raw files, processed files, PDF reports, logs

**Buckets:**
- `incoming/`: 30 GB (cleaned after processing)
- `processed/`: 360 GB (cumulative Year 1)
- `reports/`: 10 GB (PDFs)
- `logs/`: 5 GB


#### 3.3 Elastic Container Registry (ECR)

**Purpose:** Store Docker images

**Configuration:**
- Storage: 5 GB (2 services × ~2 GB each + versions)
- Data transfer: 10 GB/month

---

### 4. Security & Authentication

#### 4.1 AWS Cognito

**Purpose:** User authentication for patient portal

**Configuration:**
- Monthly Active Users (MAUs): 500
- Authentication: Email + Password
- MFA: Optional (not enabled)

#### 4.2 AWS Secrets Manager

**Purpose:** Store credentials for 15 laboratories

**Configuration:**
- Number of secrets: 15
- API calls: 50,000/month

---

### 5. Messaging & Queuing

#### 5.1 Amazon SQS

**Purpose:** Queue lab results for processing

**Configuration:**
- Standard queue
- Requests: 500,000/month
- Data transfer: 5 GB

#### 5.2 Amazon SNS

**Purpose:** Publish notifications

**Configuration:**
- Topics: 2
- Email notifications: 220,000/month


#### 5.3 Amazon SES

**Purpose:** Send email notifications to patients

**Configuration:**
- Emails sent: 220,000/month

---

### 6. API & Integration

#### 6.1 API Gateway

**Purpose:** REST API for lab result ingestion

**Configuration:**
- API type: REST
- Requests: 250,000/month
- Average payload: 5 KB
- Cache: 0.5 GB

---

### 7. Monitoring & Management

#### 7.1 CloudWatch Logs

**Purpose:** Application and infrastructure logging

**Configuration:**
- Logs ingested: 30 GB/month
- Logs stored: 30 GB
- Retention: 7 days

#### 7.2 CloudWatch Metrics & Alarms

**Configuration:**
- Custom metrics: 50
- API requests: 100,000
- Standard alarms: 20

---


### Cost Per Result

**Total cost per result:**
```
Fixed cost allocation: $138 ÷ 219,000 = $0.00063/result
Variable cost: $0.00034/result
Total: $0.00097/result

≈ $0.001 per lab result
or
$1.00 per 1,000 lab results
```

## 💡 Alternative Architectures

### Option A: Serverless-Only
**Replace:**
- RDS → DynamoDB

#### Option B: Replace NAT Gateway with VPC Endpoints
**Implementation:**
- Add VPC Endpoints for: S3, ECR, ECS, CloudWatch, SQS, SNS, Secrets Manager

---

### Immediate Actions

1. ✅ **Deploy with current architecture** - $167/month
2. ✅ **Enable basic monitoring** - Already included
3. ✅ **Set up billing alerts** - Free

### Short-Term

1. 🎯 **Implement VPC Endpoints**
2. 🎯 **Enable S3 Intelligent-Tiering** 
3. 🎯 **Reduce log retention to 3 days**

**Target:** $110/month by Month 3

### Medium-Term (Months 4-6)

---

## 📞 Cost Monitoring

### Billing Alerts Setup

1. **Budget Alert 1:** (90% of budget)
2. **Budget Alert 2:** (100% of budget)
3. **Budget Alert 3:** (120% of budget)


---

### A. AWS Pricing Calculator Links

**Estimate:** 
![Cost_analysis](../documentation/images/cost_system.png)
![Cost_analysis](../documentation/images/cost_system2.png)

# 4. Implemented Optimization Strategies

Several optimizations have already been considered in the current architecture:

**Use of multiple serverless services:**

- Lambda, SQS, SNS, API Gateway scale with demand and have no high fixed cost.

**Fargate with autoscaling:**

- ECS Worker scales based on the queue → no payment for idle instances.
- Portal maintains a minimum number of tasks but can scale according to CPU/memory.

**Controlled CloudWatch Log Retention:**

- Log groups with limited retention (e.g., 7 days) to avoid accumulating log storage costs.

**S3 for cold storage:**

- Results and original payloads in S3, not in the DB.
- Database remains lighter and cheaper.

**DLQ in SQS:**

- Prevents infinite retries and useless processing of defective messages.

# 5. Future Optimization Opportunities

As volume grows (more laboratories, more results), these improvements can be applied:

**Reduce NAT Gateway dependency:**

- Use VPC Endpoints (Gateway/Interface) for S3, SQS, CloudWatch Logs, etc.
- This reduces traffic billed through NAT, which is usually expensive.

**Adjust RDS and Fargate sizes:**

- Monitor CPU, memory, and I/O.
- Downsize if underutilized or use Aurora Serverless v2 for fine-grained elasticity.

**Savings Plans / Reserved Instances:**

- For RDS and Fargate (if usage is stable), commitment discounts can be used (1–3 years).

**Rationalized multi-environment:**

- Dev and staging environments with minimal resources (small RDS, fewer ECS tasks, nighttime shutdown windows), to avoid duplicating production costs.

**Cost breakdown:**

- Fixed cost comes mainly from RDS, ALB, NAT, and always-active Fargate tasks (portal).
- Main variable cost is in Lambdas + SQS + API Gateway + S3, which scale with the number of results.