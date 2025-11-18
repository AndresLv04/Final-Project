#!/usr/bin/env bash
set -e


# Test de versionado en el bucket de datos
# Versioning test for data bucket


REGION="us-east-1"

BUCKET=$(cd environments/development && tofu output -raw data_bucket_name)
KEY="incoming/test-version.json"

echo ">> [TEST] S3 versioning on $BUCKET / $KEY"

# 1) Subir versión 1
echo '{"version": 1}' > test.json
aws s3 cp test.json "s3://$BUCKET/$KEY" --sse AES256 --region "$REGION"

# 2) Subir versión 2
echo '{"version": 2}' > test.json
aws s3 cp test.json "s3://$BUCKET/$KEY" --sse AES256 --region "$REGION"

# 3) Ver todas las versiones y contar cuántas hay
VERSIONS_COUNT=$(aws s3api list-object-versions \
  --bucket "$BUCKET" \
  --prefix "$KEY" \
  --region "$REGION" \
  --query "length(Versions)" \
  --output text)

echo ">> Found $VERSIONS_COUNT versions for $KEY"

if [ "$VERSIONS_COUNT" -lt 2 ]; then
  echo "❌ Expected at least 2 versions, got: $VERSIONS_COUNT"
  rm -f test.json
  exit 1
fi

echo "Versioning works correctly (at least 2 versions found)"
rm -f test.json

echo "TEST PASSED: S3 versioning is enabled and working"
