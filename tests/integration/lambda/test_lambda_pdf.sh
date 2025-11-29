#!/usr/bin/env bash
set -e

#############################################
# TEST 3 - LAMBDA PDF (INTEGRATION TEST)
#############################################

# 1) Ir a la raíz del repo
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

echo ">> ROOT_DIR: $ROOT_DIR"

# 2) Obtener nombre de la Lambda PDF
echo ">> Obteniendo nombre de la Lambda PDF desde OpenTofu..."
LAMBDA_PDF=$(tofu -chdir=environments/development output -raw lambda_pdf_name)
echo "   Lambda PDF name: $LAMBDA_PDF"
echo

# 3) Ir a la carpeta de tests
cd tests/integration/lambda

echo ">> Creando evento de prueba (pdf-event.json)..."
cat > pdf-event.json <<'EOF'
{
  "result_id": "1"
}
EOF

cat pdf-event.json
echo

# 4) Invocar Lambda PDF
echo ">> Invocando Lambda PDF..."
aws lambda invoke \
  --function-name "$LAMBDA_PDF" \
  --payload file://pdf-event.json \
  --cli-binary-format raw-in-base64-out \
  pdf-response.json \
  >/dev/null

# 5) Mostrar un resumen de la respuesta (sin la URL)
echo ">> Resumen de la respuesta (jq, sin signed_url):"
jq '{statusCode, body: (.body | fromjson | {result_id, s3_key})}' pdf-response.json
echo

# 6) Extraer la signed_url del body (que es un string JSON)
SIGNED_URL_LAMBDA=$(jq -r '.body | fromjson | .signed_url' pdf-response.json)

echo ">> Signed URL devuelta por Lambda:"
echo "$SIGNED_URL_LAMBDA"
echo

# 7) Probar descarga con curl usando ESA URL
echo ">> Probando descarga con curl (lambda-report.pdf)..."
curl -s -o lambda-report.pdf "$SIGNED_URL_LAMBDA"
echo "PDF descargado en: $(pwd)/lambda-report.pdf"

echo
echo "✅ Test de Lambda PDF finalizado."
