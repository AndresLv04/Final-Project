# Healthcare Lab Platform – API Documentation

This document describes the HTTP API exposed via **API Gateway** for the **Healthcare Lab Platform**.

- Version: `v1`
- Base URL (example):
  ```text
  https://<api-id>.execute-api.<region>.amazonaws.com/prod
  ```

In your actual environment, you can obtain it with:

```bash
cd environments/development
tofu output -raw api_endpoint
```

---

## 🔐 Authentication

### API Key (External Laboratories)

For all endpoints under `/api/v1/*` (except health), the following header is required:

```http
x-api-key: <API_KEY>
```

Obtain the value from Terraform:

```bash
tofu output -raw api_key_value
```

### Cognito (Patient Portal)

Patient authentication is performed outside this API (via Amazon Cognito + web portal).
This API is primarily intended for laboratories and internal services.

---

## 📚 Endpoints

### 1. Health Check

```
GET /health
```
or (depending on configuration)
```
GET /api/v1/health
```

API health endpoint (used by monitoring / ALB / quick tests).

**Authentication:**
- Does not require API Key
- No body required

**Response – 200 OK**

```json
{
  "status": "ok",
  "service": "healthcare-lab-platform-api",
  "time": "2025-11-28T03:38:13Z"
}
```

**Example with curl:**

```bash
curl -i "$(tofu output -raw api_health_endpoint)"
```

---

### 2. Laboratory Results Ingestion (JSON)

```
POST /api/v1/ingest
```

Main endpoint for laboratories to send results in JSON format
(this is what `scripts/send_test_message.py` uses).

#### Headers

```http
Content-Type: application/json
x-api-key: <API_KEY>
```

#### 2.1. Request Body (JSON)

Example (very similar to what `send_test_message.py` generates):

```json
{
  "patient_id": "P123456",
  "lab_id": "LAB001",
  "lab_name": "Quest Diagnostics",
  "test_type": "complete_blood_count",
  "test_date": "2025-01-15T10:30:00Z",
  "physician": {
    "name": "Dr. Sarah Johnson",
    "npi": "1234567890"
  },
  "results": [
    {
      "test_code": "WBC",
      "test_name": "White Blood Cell Count",
      "value": 7.5,
      "unit": "10^3/uL",
      "reference_range": "4.5-11.0",
      "is_abnormal": false
    },
    {
      "test_code": "HGB",
      "test_name": "Hemoglobin",
      "value": 13.2,
      "unit": "g/dL",
      "reference_range": "13.0-17.0",
      "is_abnormal": false
    }
  ],
  "notes": "Fasting sample. Patient reported no recent illness."
}
```

#### Required Fields

- **`patient_id`** (string) – Patient ID according to the laboratory/source system
- **`lab_id`** (string) – Laboratory identifier (e.g., LAB001)
- **`lab_name`** (string) – Descriptive laboratory name
- **`test_type`** (string) – Panel/test type (e.g., complete_blood_count, lipid_panel)
- **`test_date`** (string, ISO 8601) – Date/time when the study was performed/processed
- **`results`** (array) – List of individual test values

Each `results` element:
- **`test_code`** (string) – Short code (e.g., WBC, GLU)
- **`test_name`** (string) – Test name
- **`value`** (number) – Numerical result
- **`unit`** (string) – Unit (e.g., mg/dL, 10^3/uL)
- **`reference_range`** (string) – Text reference range (e.g., "4.5-11.0")
- **`is_abnormal`** (bool) – `true` if result is out of range

#### Optional Fields

- **`physician`** (object)
  - `name` (string)
  - `npi` (string)
- **`notes`** (string)

Additional fields such as `external_result_id`, `order_id`, etc., may be accepted and stored for traceability.

#### 2.2. Response – 202 Accepted

If ingestion was accepted for asynchronous processing:

```json
{
  "status": "accepted",
  "result_id": "12345",
  "patient_id": "P123456",
  "lab_id": "LAB001",
  "received_at": "2025-11-28T03:40:12Z"
}
```

- **`result_id`** – Internal ID that will be used in RDS and the patient portal

Subsequent processing (normalization, RDS writing, notifications) is performed by
SQS + ECS Worker + Lambda, asynchronously.

#### 2.3. Examples with curl

**Example 1 – Send a single result (inline JSON)**

```bash
API_URL="$(tofu output -raw api_endpoint)"
API_KEY="$(tofu output -raw api_key_value)"

curl -X POST "$API_URL/api/v1/ingest" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{
    "patient_id": "P123456",
    "lab_id": "LAB001",
    "lab_name": "Quest Diagnostics",
    "test_type": "complete_blood_count",
    "test_date": "2025-01-15T10:30:00Z",
    "physician": {
      "name": "Dr. Sarah Johnson",
      "npi": "1234567890"
    },
    "results": [
      {
        "test_code": "WBC",
        "test_name": "White Blood Cell Count",
        "value": 7.5,
        "unit": "10^3/uL",
        "reference_range": "4.5-11.0",
        "is_abnormal": false
      }
    ],
    "notes": "Fasting sample"
  }'
```

**Example 2 – Using the test script**

```bash
cd scripts

python send_test_message.py \
  --api-url "$(cd ../environments/development && tofu output -raw api_endpoint)" \
  --api-key "$(cd ../environments/development && tofu output -raw api_key_value)" \
  --count 5
```

The script:
- Generates random data (patients, labs, panels)
- Sends them to `POST /api/v1/ingest`
- Displays in console whether each submission was accepted (`status: accepted`) or failed

---

### 3. PDF Results Generation

> **Note:** PDF integration is intended for internal use (portal / backoffice).
> The endpoint can be adjusted based on Lambda PDF implementation.

```
POST /api/v1/results/{result_id}/pdf
```

Requests PDF generation for a particular result.

#### Headers

```http
Content-Type: application/json
x-api-key: <API_KEY>
```

#### Path Parameters

- **`result_id`** – Result ID (the same returned by `/ingest` and stored in RDS)

#### Body (optional)

```json
{
  "delivery": "download"
}
```

**`delivery`** options:
- `"download"` – Return a download link (pre-signed URL)
- `"email"` – Send via email to the patient (if configured)

#### Response – 202 Accepted (example)

```json
{
  "status": "accepted",
  "result_id": "12345",
  "job_id": "pdf-job-67890"
}
```

#### Response – 200 OK (if synchronous and returns URL)

```json
{
  "status": "ready",
  "result_id": "12345",
  "pdf_url": "https://s3-...-presigned-url"
}
```

#### Example with curl

```bash
API_URL="$(tofu output -raw api_endpoint)"
API_KEY="$(tofu output -raw api_key_value)"
RESULT_ID="12345"

curl -X POST "$API_URL/api/v1/results/$RESULT_ID/pdf" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{"delivery": "download"}'
```

---

## 🔎 Supported Data Formats (Overview)

The platform can receive data in multiple formats, but **all inputs are normalized to a canonical JSON schema** before being processed by the ingest Lambda.

- **JSON via REST** → `/api/v1/ingest` (invokes the ingest Lambda directly)
- **HL7** → Ingestion via SFTP/S3 → processed by an HL7 adapter Lambda that converts HL7 to JSON and then invokes the ingest Lambda
- **XML** → Ingestion via SOAP / dedicated endpoints or S3 → processed by an XML adapter Lambda that converts XML to JSON and then invokes the ingest Lambda
- **CSV** → Ingestion via files (S3 / email → SES / Lambda) → processed by a CSV adapter Lambda that converts CSV to JSON and then invokes the ingest Lambda
The **ingest Lambda** validates that the resulting JSON conforms to the expected schema, stores the payload in **S3**, and then publishes a message to **SQS** for downstream processing.

This document covers only the HTTP API (JSON).
Non-JSON flows (HL7/XML/CSV) are implemented via dedicated adapter Lambdas that perform the format → JSON transformation and delegate to the ingest Lambda.

---

## ❗ Error Handling

All error responses use JSON with a consistent format:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Missing required field: patient_id",
    "details": {
      "field": "patient_id"
    }
  }
}
```

### Common Status Codes

| Status Code | Description |
|-------------|-------------|
| **400 Bad Request** | Invalid JSON, missing required fields, incorrect format |
| **401 Unauthorized** | Invalid or missing API Key |
| **403 Forbidden** | Valid API Key but no permissions for the resource (if labs are segmented) |
| **404 Not Found** | Endpoint or resource not found (nonexistent result_id) |
| **429 Too Many Requests** | Rate limit exceeded (if throttling is enabled) |
| **500 Internal Server Error** | Unhandled error in Lambda / backend |

### Error Examples with curl

#### Missing API Key

```bash
curl -i -X POST "$API_URL/api/v1/ingest" \
  -H "Content-Type: application/json" \
  -d '{"patient_id":"P123456"}'
```

**Response:**

```http
HTTP/1.1 401 Unauthorized
```

```json
{
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Missing or invalid API key"
  }
}
```

#### Invalid JSON / Missing Required Field

```bash
curl -i -X POST "$API_URL/api/v1/ingest" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{"lab_id": "LAB001"}'
```

**Response:**

```http
HTTP/1.1 400 Bad Request
```

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Missing required field: patient_id"
  }
}
```

---
