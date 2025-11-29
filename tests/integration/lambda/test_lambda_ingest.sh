#!/usr/bin/env bash
set -e

#############################################
# ES: Test de Lambda Ingest (end-to-end)
#  - Obtiene el nombre de la Lambda desde OpenTofu
#  - Envía un evento de ejemplo
#  - Muestra la respuesta
#  - Verifica S3 (archivo en incoming/)
#  - Verifica SQS (mensajes visibles)
#
# EN: Lambda Ingest test (end-to-end)
#  - Get Lambda name from OpenTofu outputs
#  - Send sample event
#  - Show response
#  - Check S3 (incoming/ object)
#  - Check SQS (visible messages)
#############################################

# Ir a la raíz del repo
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
echo ">> ROOT_DIR: $ROOT_DIR"

# Entrar al entorno development (donde está el tofu)
pushd "$ROOT_DIR/environments/development" > /dev/null

echo ">> Obteniendo nombre de la Lambda Ingest desde OpenTofu..."
LAMBDA_NAME=$(tofu output -raw lambda_ingest_name)
echo "   Lambda name: $LAMBDA_NAME"
echo

echo ">> Creando evento de prueba (test-event.json)..."

cat > test-event.json <<'EOF'
{
  "body": "{\"patient_id\":\"P123456\",\"lab_id\":\"LAB001\",\"lab_name\":\"Quest Diagnostics\",\"test_type\":\"complete_blood_count\",\"test_date\":\"2024-01-15T10:00:00Z\",\"physician\":{\"name\":\"Dr. Smith\",\"npi\":\"1234567890\"},\"results\":[{\"test_code\":\"WBC\",\"test_name\":\"White Blood Cell Count\",\"value\":7.5,\"unit\":\"10^3/uL\",\"reference_range\":\"4.5-11.0\",\"is_abnormal\":false},{\"test_code\":\"RBC\",\"test_name\":\"Red Blood Cell Count\",\"value\":4.8,\"unit\":\"10^6/uL\",\"reference_range\":\"4.5-5.5\",\"is_abnormal\":false}],\"notes\":\"Test notes\"}"
}
EOF

echo ">> Invocando Lambda..."
aws lambda invoke \
  --function-name "$LAMBDA_NAME" \
  --payload fileb://test-event.json \
  --cli-binary-format raw-in-base64-out \
  response.json

echo
echo ">> Respuesta cruda (raw response.json):"
cat response.json
echo
echo

# Si tienes jq instalado, formateamos el JSON bonito
if command -v jq >/dev/null 2>&1; then
  echo ">> Respuesta formateada (jq):"
  cat response.json | jq .
  echo
else
  echo ">> 'jq' no está instalado, saltando pretty-print."
  echo "   (Puedes instalarlo y volver a correr el test)."
  echo
fi

#############################################
# Verificar S3: archivo en incoming/
#############################################

# Opción simple: usar directamente el bucket esperado en dev
# ES: si cambiaste project_name/environment, ajusta aquí
# EN: if you changed project_name/environment, update this
BUCKET_NAME="healthcare-lab-platform-dev-data"

echo ">> Listando objetos en S3 (bucket: $BUCKET_NAME, prefix: incoming/)..."
aws s3 ls "s3://$BUCKET_NAME/incoming/" --recursive || true
echo

#############################################
# Verificar SQS: mensajes visibles
#############################################

echo ">> Obteniendo URL de la cola SQS desde OpenTofu..."
QUEUE_URL=$(tofu output -raw queue_url)
echo "   Queue URL: $QUEUE_URL"
echo

echo ">> Consultando ApproximateNumberOfMessagesVisible..."
aws sqs get-queue-attributes \
  --queue-url "$QUEUE_URL" \
  --attribute-names ApproximateNumberOfMessages

echo
echo "✅ Test de Lambda Ingest finalizado."
echo

popd > /dev/null
