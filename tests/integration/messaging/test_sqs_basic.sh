#!/usr/bin/env bash
set -e

#############################################
# ES: Test básico de SQS:
#   1) Obtener URL de la cola desde OpenTofu
#   2) Enviar mensaje de prueba
#   3) Leer mensaje
#   4) Borrar mensaje
#
# EN: Basic SQS test:
#   1) Get queue URL from OpenTofu outputs
#   2) Send test message
#   3) Receive message
#   4) Delete message
#############################################

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

# 1) Obtener URL de la cola desde OpenTofu (environment: development)
pushd "$ROOT_DIR/environments/development" > /dev/null

# Cambia "queue_url" si tu output tiene otro nombre
QUEUE_URL=$(tofu output -raw queue_url)

popd > /dev/null

echo ">> Using SQS queue URL:"
echo "   $QUEUE_URL"

# 2) Enviar mensaje de prueba
echo ">> Sending test message..."

SEND_RESULT=$(aws sqs send-message \
  --queue-url "$QUEUE_URL" \
  --message-body '{
    "test": "message",
    "timestamp": "2024-02-15T10:00:00Z",
    "data": {
      "patient_id": "P123411",
      "result_id": "test-001"
    }
  }' \
  --output json)

echo "Send result:"
echo "$SEND_RESULT"
echo

# 3) Recibir mensaje (long polling 20s)
echo ">> Receiving message (long polling 20s)..."

RECEIVE_RESULT=$(aws sqs receive-message \
  --queue-url "$QUEUE_URL" \
  --max-number-of-messages 1 \
  --wait-time-seconds 20 \
  --output json)

echo "Receive result (JSON):"
echo "$RECEIVE_RESULT"
echo

# 4) Obtener ReceiptHandle usando solo AWS CLI (sin jq)
RECEIPT_HANDLE=$(aws sqs receive-message \
  --queue-url "$QUEUE_URL" \
  --max-number-of-messages 1 \
  --wait-time-seconds 5 \
  --query 'Messages[0].ReceiptHandle' \
  --output text)

if [[ -z "$RECEIPT_HANDLE" || "$RECEIPT_HANDLE" == "None" ]]; then
  echo "❌ No message received (no ReceiptHandle)"
  exit 1
fi

echo ">> ReceiptHandle:"
echo "   $RECEIPT_HANDLE"

# 5) Borrar el mensaje
echo ">> Deleting message..."

aws sqs delete-message \
  --queue-url "$QUEUE_URL" \
  --receipt-handle "$RECEIPT_HANDLE"

echo "✅ Message deleted successfully"
echo "🎉 TEST PASSED: SQS basic send/receive/delete works"
