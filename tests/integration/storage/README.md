## Verificación manual de access logs de S3

Después de activar logging y generar tráfico sobre el bucket de datos:

```bash
LOG_BUCKET="healthcare-lab-platform-dev-logs"
PREFIX="data-bucket-access-logs/"
REGION="us-east-1"

aws s3 ls "s3://$LOG_BUCKET/$PREFIX" --recursive --region "$REGION"

LAST_LOG_KEY=$(aws s3 ls "s3://$LOG_BUCKET/$PREFIX" --recursive --region "$REGION" \
  | sort \
  | tail -n 1 \
  | awk '{print $4}')

aws s3 cp "s3://$LOG_BUCKET/$LAST_LOG_KEY" - --region "$REGION" | head -5
