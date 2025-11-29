#!/usr/bin/env bash
set -euo pipefail

###########################################
# TEST RATE LIMIT API GATEWAY
###########################################
# - Envía muchas requests al endpoint /ingest
# - Muestra el HTTP code de cada request
# - Deberías ver algunos 429 (Too Many Requests)
###########################################

# 0) Ir a la raíz del repo
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

# ⚠️ IMPORTANTE: usar ruta RELATIVA para que -chdir no sufra con espacios
ENV_DIR="environments/development"

echo ">> ROOT_DIR: $ROOT_DIR"
echo ">> ENV_DIR : $ENV_DIR"
echo

# 1) Obtener outputs desde OpenTofu (usando ruta relativa)
echo ">> Obteniendo outputs desde OpenTofu..."
INGEST_URL="$(tofu -chdir="$ENV_DIR" output -raw api_ingest_endpoint)"
API_KEY="$(tofu -chdir="$ENV_DIR" output -raw api_key_value)"

echo "   INGEST_URL: $INGEST_URL"
echo "   API_KEY   : $API_KEY"
echo

# 2) Enviar muchas requests en paralelo para probar rate limiting
echo "Enviando 50 requests en paralelo (límite configurado: 5 req/seg, burst 2)..."
echo

for i in {1..50}; do
  curl -s -o /dev/null -w "Req $i -> %{http_code}\n" \
    -X POST "$INGEST_URL" \
    -H "Content-Type: application/json" \
    -H "x-api-key: $API_KEY" \
    -d "{
      \"patient_id\": \"P$i\",
      \"lab_id\": \"LAB001\",
      \"lab_name\": \"Test\",
      \"test_type\": \"test\",
      \"test_date\": \"2024-01-15T10:00:00Z\",
      \"results\": [
        {
          \"test_code\": \"TEST\",
          \"test_name\": \"Test\",
          \"value\": 1,
          \"unit\": \"unit\"
        }
      ]
    }" &
done

# Esperar a que terminen todas las peticiones
wait

echo
echo "=== TEST RATE LIMIT COMPLETADO ==="
