#!/usr/bin/env bash
set -euo pipefail

#############################################
# TEST 4 - LAMBDAS E2E (INGEST + PDF)
#
# Nota importante:
# - La Lambda Ingest genera un result_id "externo" tipo
#   P123456-2025..., útil para S3 y SQS.
# - La BD usa un result_id INTEGER (SERIAL).
# - Para la Lambda PDF usaremos SIEMPRE el result_id NUMÉRICO
#   que existe en RDS (lo ponemos en DB_RESULT_ID).
#############################################

# 0) Ir a la raíz del repo (desde donde sea que ejecutes el script)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

ENV_DIR="environments/development"
TEST_DIR="$ROOT_DIR/tests/integration/lambda"

echo ">> ROOT_DIR: $ROOT_DIR"
echo ">> ENV_DIR : $ENV_DIR"
echo

# 1) Obtener outputs desde OpenTofu
echo ">> Obteniendo nombres y recursos desde OpenTofu..."

LAMBDA_INGEST=$(tofu -chdir="$ENV_DIR" output -raw lambda_ingest_name)
LAMBDA_PDF=$(tofu -chdir="$ENV_DIR" output -raw lambda_pdf_name)
S3_BUCKET=$(tofu -chdir="$ENV_DIR" output -raw data_bucket_name)
QUEUE_URL=$(tofu -chdir="$ENV_DIR" output -raw queue_url)

echo "   Lambda Ingest : $LAMBDA_INGEST"
echo "   Lambda PDF    : $LAMBDA_PDF"
echo "   S3 Bucket     : $S3_BUCKET"
echo "   Queue URL     : $QUEUE_URL"
echo

# 2) Trabajar dentro de tests/integration/lambda
cd "$TEST_DIR"

echo "1) Enviando resultado de laboratorio a Lambda Ingest..."
cat > ingest-payload.json <<'PAYLOAD'
{
  "body": "{\"patient_id\":\"P123456\",\"lab_id\":\"LAB001\",\"lab_name\":\"Quest Diagnostics\",\"test_type\":\"complete_blood_count\",\"test_date\":\"2024-01-15T10:00:00Z\",\"physician\":{\"name\":\"Dr. Sarah Johnson\",\"npi\":\"1234567890\"},\"results\":[{\"test_code\":\"WBC\",\"test_name\":\"White Blood Cell Count\",\"value\":7.5,\"unit\":\"10^3/uL\",\"reference_range\":\"4.5-11.0\",\"is_abnormal\":false},{\"test_code\":\"RBC\",\"test_name\":\"Red Blood Cell Count\",\"value\":4.8,\"unit\":\"10^6/uL\",\"reference_range\":\"4.5-5.5\",\"is_abnormal\":false},{\"test_code\":\"HGB\",\"test_name\":\"Hemoglobin\",\"value\":13.2,\"unit\":\"g/dL\",\"reference_range\":\"13.0-17.0\",\"is_abnormal\":false}],\"notes\":\"Fasting sample\"}"
}
PAYLOAD

aws lambda invoke \
  --function-name "$LAMBDA_INGEST" \
  --payload file://ingest-payload.json \
  --cli-binary-format raw-in-base64-out \
  ingest-response.json >/dev/null

echo ">> Respuesta Ingest (pretty):"
cat ingest-response.json | jq .
echo

# Este RESULT_ID es el "externo" de Ingest (tipo string P123456-...)
RESULT_ID=$(cat ingest-response.json | jq -r '.body' | jq -r '.result_id')
S3_KEY=$(cat ingest-response.json | jq -r '.body' | jq -r '.s3_key')

echo "✅ Lambda Ingest ejecutado"
echo "   External Result ID (Ingest): $RESULT_ID"
echo "   S3 Key                     : $S3_KEY"
echo

echo "2) Verificando archivo en S3..."
aws s3 ls "s3://$S3_BUCKET/$S3_KEY"
echo "✅ Archivo guardado en S3"
echo

echo "3) Verificando mensaje en SQS..."
MSGS=$(aws sqs get-queue-attributes \
  --queue-url "$QUEUE_URL" \
  --attribute-names ApproximateNumberOfMessages \
  --query 'Attributes.ApproximateNumberOfMessagesVisible' \
  --output text)

echo "✅ Mensajes visibles en cola: $MSGS"
echo

###########################################################
# Aquí entra en juego el result_id NUMÉRICO de la BD
###########################################################

# Ajusta este valor al result_id INTEGER que tengas en lab_results.
# Por ejemplo, si hiciste un INSERT y te devolvió "result_id = 1",
# entonces deja DB_RESULT_ID=1
DB_RESULT_ID=1

echo "4) Asegúrate en RDS de que exista un registro con result_id (INTEGER) = $DB_RESULT_ID"
echo "   en lab_results y sus filas correspondientes en test_values."
echo

echo "5) Generando PDF del resultado (usando result_id numérico de la BD)..."

cat > pdf-payload.json <<PDFPAYLOAD
{
  "result_id": $DB_RESULT_ID
}
PDFPAYLOAD

aws lambda invoke \
  --function-name "$LAMBDA_PDF" \
  --payload file://pdf-payload.json \
  --cli-binary-format raw-in-base64-out \
  pdf-response.json >/dev/null

echo ">> Respuesta PDF (pretty):"
cat pdf-response.json | jq .
echo

BODY_JSON=$(jq -r '.body' pdf-response.json)
SIGNED_URL_LAMBDA=$(echo "$BODY_JSON" | jq -r '.signed_url')

if [ "$SIGNED_URL_LAMBDA" != "null" ] && [ -n "$SIGNED_URL_LAMBDA" ]; then
  echo "✅ PDF generado por Lambda"
  echo "   URL firmada: $SIGNED_URL_LAMBDA"
  echo
  echo "6) Descargando PDF con curl..."
  curl -s -o lambda-report.pdf "$SIGNED_URL_LAMBDA"
  echo "✅ PDF descargado en: $TEST_DIR/lambda-report.pdf"
else
  echo "⚠️  No se pudo obtener signed_url en la respuesta de la Lambda PDF"
fi

echo
echo "=== TEST E2E COMPLETADO ==="
