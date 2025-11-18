#!/usr/bin/env bash
set -e


# Test de encriptación obligatoria en S3
# EN: Test for mandatory S3 encryption


AWS_REGION="us-east-1"


BUCKET=$(cd environments/development && tofu output -raw data_bucket_name)
OBJECT_KEY="incoming/test-encryption.json"

echo ">> [TEST] S3 encryption policy on bucket: $BUCKET"

# Crear archivo de prueba
echo '{"test": "data"}' > test.json

echo ">> 1) Upload WITHOUT encryption (should FAIL)..."
# Esperamos que este comando falle por la bucket policy (AccessDenied)
if aws s3 cp test.json "s3://$BUCKET/$OBJECT_KEY" --region "$AWS_REGION" >/dev/null 2>&1; then
  echo "❌ Upload WITHOUT encryption SUCCEEDED but should have been denied"
  rm -f test.json
  exit 1
else
  echo "✅ Upload WITHOUT encryption was denied (expected)"
fi

echo ">> 2) Upload WITH SSE AES256 (should SUCCEED)..."
aws s3 cp test.json "s3://$BUCKET/$OBJECT_KEY" --sse AES256 --region "$AWS_REGION" >/dev/null

echo ">> 3) Verifying object exists..."
if aws s3 ls "s3://$BUCKET/$OBJECT_KEY" --region "$AWS_REGION" >/dev/null 2>&1; then
  echo "✅ Encrypted object is present in bucket"
else
  echo "❌ Encrypted upload seems to have failed"
  rm -f test.json
  exit 1
fi

echo ">> 4) Downloading and showing content..."
aws s3 cp "s3://$BUCKET/$OBJECT_KEY" downloaded-test.json --region "$AWS_REGION" >/dev/null
cat downloaded-test.json

rm -f test.json downloaded-test.json

echo "TEST PASSED: S3 encryption bucket policy works as expected"
