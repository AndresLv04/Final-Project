#!/usr/bin/env bash
set -euo pipefail

#############################################
# TEST API GATEWAY (Health, Ingest, PDF)
#############################################

# Ir a la raíz del repo
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

ENV_DIR="environments/development"

echo ">> ROOT_DIR: $ROOT_DIR"
echo ">> ENV_DIR : $ENV_DIR"
echo

echo ">> Obteniendo outputs desde OpenTofu..."
API_KEY=$(tofu -chdir="$ENV_DIR" output -raw api_key_value)
HEALTH_URL=$(tofu -chdir="$ENV_DIR" output -raw api_health_endpoint)
INGEST_URL=$(tofu -chdir="$ENV_DIR" output -raw api_ingest_endpoint)
PDF_URL=$(tofu -chdir="$ENV_DIR" output -raw api_pdf_endpoint)

echo "   API_KEY   : $API_KEY"
echo "   HEALTH_URL: $HEALTH_URL"
echo "   INGEST_URL: $INGEST_URL"
echo "   PDF_URL   : $PDF_URL"
echo

HAS_JQ=0
if command -v jq >/dev/null 2>&1; then
  HAS_JQ=1
fi

#############################################
# TEST 1: Health Check (sin API Key)
#############################################
echo "=== TEST 1: Health Check (GET /health) ==="
echo ">> curl $HEALTH_URL"
RESP_HEALTH=$(curl -s "$HEALTH_URL")

if [ "$HAS_JQ" -eq 1 ]; then
  echo "$RESP_HEALTH" | jq .
else
  echo "$RESP_HEALTH"
fi
echo

#############################################
# TEST 2: Ingest Endpoint (con y sin API Key)
#############################################
echo "2.1) Sin API Key (debería dar 403/Forbidden)"
set +e
curl -i -X POST "$INGEST_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "patient_id": "P123456",
    "lab_id": "LAB001",
    "lab_name": "Quest Diagnostics",
    "test_type": "complete_blood_count",
    "test_date": "2024-01-15T10:00:00Z",
    "results": []
  }'
STATUS=$?
set -e
echo "Exit code curl (esperado != 0 por 403): $STATUS"
echo
echo "2.2) Con API Key (debería ser aceptado)"
RESP_INGEST=$(curl -s \
  -X POST "$INGEST_URL" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{
    "patient_id": "P123456",
    "lab_id": "LAB001",
    "lab_name": "Quest Diagnostics",
    "test_type": "complete_blood_count",
    "test_date": "2024-01-15T10:00:00Z",
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
        "test_code": "RBC",
        "test_name": "Red Blood Cell Count",
        "value": 4.8,
        "unit": "10^6/uL",
        "reference_range": "4.5-5.5",
        "is_abnormal": false
      }
    ],
    "notes": "Fasting sample"
  }')

if [ "$HAS_JQ" -eq 1 ]; then
  echo "$RESP_INGEST" | jq .
else
  echo "$RESP_INGEST"
fi
echo

#############################################
# TEST 3: Validación de datos (error 400)
#############################################
echo "=== TEST 3: Validación de datos (payload inválido) ==="

RESP_INVALID=$(curl -s \
  -X POST "$INGEST_URL" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{
    "patient_id": "P123456"
  }')

if [ "$HAS_JQ" -eq 1 ]; then
  echo "$RESP_INVALID" | jq .
else
  echo "$RESP_INVALID"
fi
echo

#############################################
# TEST 5: PDF Endpoint
#############################################
echo "=== TEST 5: PDF Endpoint (POST /pdf) ==="

RESP_PDF=$(curl -s \
  -X POST "$PDF_URL" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{
    "result_id": "1"
  }')

if [ "$HAS_JQ" -eq 1 ]; then
  echo "$RESP_PDF" | jq .
else
  echo "$RESP_PDF"
fi
echo

echo "=== TESTS API GATEWAY COMPLETADOS ==="
