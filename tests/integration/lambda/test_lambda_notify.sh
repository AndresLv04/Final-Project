#!/usr/bin/env bash
set -e

#############################################
# TEST 2 - LAMBDA NOTIFY (INTEGRATION TEST)
#############################################

# Ir a la raíz del repo
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

echo ">> ROOT_DIR: $ROOT_DIR"

# 1) Obtener nombre de la Lambda desde OpenTofu (environment: development)
echo ">> Obteniendo nombre de la Lambda Notify desde OpenTofu..."

pushd "$ROOT_DIR/environments/development" > /dev/null
LAMBDA_NOTIFY=$(tofu output -raw lambda_notify_name)
popd > /dev/null

echo "   Lambda Notify name: $LAMBDA_NOTIFY"
echo

# 2) Crear evento de prueba
echo ">> Creando evento de prueba (notify-event.json)..."

cat > tests/integration/lambda/notify-event.json <<'EOF'
{
  "result_id": "1",
  "patient_id": "P123456"
}
EOF

cat tests/integration/lambda/notify-event.json
echo
echo

# 3) Invocar Lambda
echo ">> Invocando Lambda Notify..."

aws lambda invoke \
  --function-name "$LAMBDA_NOTIFY" \
  --payload file://tests/integration/lambda/notify-event.json \
  --cli-binary-format raw-in-base64-out \
  tests/integration/lambda/notify-response.json

echo
echo ">> Respuesta cruda (raw notify-response.json):"
cat tests/integration/lambda/notify-response.json
echo
echo

# 4) Pretty-print con jq (si está instalado)
if command -v jq >/dev/null 2>&1; then
  echo ">> Respuesta formateada (jq):"
  cat tests/integration/lambda/notify-response.json | jq .
else
  echo ">> 'jq' no está instalado, saltando pretty-print."
  echo "   (Opcional) Puedes instalarlo y volver a correr el test."
fi

echo
echo "✅ Test de Lambda Notify finalizado."
