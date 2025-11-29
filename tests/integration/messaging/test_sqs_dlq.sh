#!/usr/bin/env bash
set -e

#############################################
# ES: Test del Dead Letter Queue (DLQ)
#   - Envía mensaje a la cola principal
#   - Simula 3 intentos fallidos (no borrar)
#   - Verifica que termina en la DLQ
#############################################

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

pushd "$ROOT_DIR/environments/development" > /dev/null
QUEUE_URL=$(tofu output -raw queue_url)
DLQ_URL=$(tofu output -raw dlq_url)
popd > /dev/null

echo ">> Main queue URL: $QUEUE_URL"
echo ">> DLQ URL:        $DLQ_URL"

echo ">> Sending test message to main queue..."

SEND_RESULT=$(aws sqs send-message \
  --queue-url "$QUEUE_URL" \
  --message-body '{"test": "dlq-test"}' \
  --output json)

echo "Send result:"
echo "$SEND_RESULT"
echo

ATTEMPTS=3
for i in $(seq 1 $ATTEMPTS); do
  echo ">> Attempt $i of $ATTEMPTS (receive but NOT delete)..."

  RECEIVE=$(aws sqs receive-message \
    --queue-url "$QUEUE_URL" \
    --max-number-of-messages 1 \
    --visibility-timeout 10 \
    --wait-time-seconds 5 \
    --output json || true)

  echo "Receive output:"
  echo "$RECEIVE"
  echo

  echo "Waiting for visibility timeout to expire..."
  sleep 12
done

echo ">> After $ATTEMPTS failed attempts, message should be in DLQ"
echo "Waiting a few seconds..."
sleep 5

echo ">> Checking DLQ messages..."

DLQ_MSG=$(aws sqs receive-message \
  --queue-url "$DLQ_URL" \
  --max-number-of-messages 1 \
  --wait-time-seconds 10 \
  --query 'Messages[0].MessageId' \
  --output text || true)

if [[ -z "$DLQ_MSG" || "$DLQ_MSG" == "None" ]]; then
  echo "❌ No message found in DLQ (check redrive policy & maxReceiveCount)."
  exit 1
fi

echo "✅ Message found in DLQ with MessageId: $DLQ_MSG"
echo "🎉 TEST PASSED: DLQ redrive policy works"
