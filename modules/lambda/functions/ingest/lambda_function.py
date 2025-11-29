"""
Lambda Ingest Function (JSON Adapter)
Recibe resultados de laboratorio en formato JSON, valida y envía a procesamiento
"""

import json
import boto3
import os
from datetime import datetime
import logging
from typing import Dict, Any

# Configuración de logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Clientes AWS
s3_client = boto3.client("s3")
sqs_client = boto3.client("sqs")

# Variables de entorno (las mismas que ya usas)
S3_BUCKET = os.environ["S3_BUCKET"]
SQS_QUEUE_URL = os.environ["SQS_QUEUE_URL"]
ENVIRONMENT = os.environ.get("ENVIRONMENT", "dev")

# NUEVO: metadatos de formato
SOURCE_FORMAT = "JSON"  # otros adapters usarán "HL7", "XML", "CSV"
PAYLOAD_SCHEMA_VERSION = "1.0"


def lambda_handler(event, context):
    """
    Handler principal de Lambda
    """
    try:
        logger.info("Lambda Ingest (JSON) iniciado")
        logger.info(f"Event: {json.dumps(event)}")

        # 1. Parsear el body
        body = parse_body(event)

        # 2. Validar datos
        validation_result = validate_lab_result(body)
        if not validation_result["valid"]:
            return error_response(400, validation_result["errors"])

        # 3. Generar ID único
        result_id = generate_result_id(body)

        # 4. Guardar en S3
        s3_key = save_to_s3(body, result_id)

        # 5. Enviar mensaje a SQS
        message_id = send_to_sqs(s3_key, result_id, body)

        # 6. Respuesta exitosa
        logger.info(f"Procesamiento exitoso. Result ID: {result_id}")

        return success_response(
            {
                "result_id": result_id,
                "message_id": message_id,
                "s3_key": s3_key,
                "status": "accepted",
                "message": "Lab result received and queued for processing",
            }
        )

    except Exception as e:
        logger.error(f"Error en lambda_handler: {str(e)}", exc_info=True)
        return error_response(500, f"Internal server error: {str(e)}")


def parse_body(event: Dict[str, Any]) -> Dict[str, Any]:
    """Parsea el body del request"""
    try:
        if "body" in event:
            if isinstance(event["body"], str):
                return json.loads(event["body"])
            return event["body"]
        return event
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in request body: {str(e)}")


def validate_lab_result(data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Valida el formato del resultado de laboratorio
    """
    errors = []

    required_fields = [
        "patient_id",
        "lab_id",
        "lab_name",
        "test_type",
        "test_date",
        "results",
    ]

    for field in required_fields:
        if field not in data:
            errors.append(f"Missing required field: {field}")
        elif not data[field]:
            errors.append(f"Field '{field}' cannot be empty")

    # results debe ser lista
    if "results" in data:
        if not isinstance(data["results"], list):
            errors.append("Field 'results' must be a list")
        elif len(data["results"]) == 0:
            errors.append("Field 'results' cannot be empty")
        else:
            for idx, result in enumerate(data["results"]):
                errors.extend(validate_test_result(result, idx))

    # patient_id (ejemplo de regla simple)
    if "patient_id" in data and data["patient_id"]:
        if not str(data["patient_id"]).startswith("P"):
            errors.append("patient_id must start with 'P'")

    # test_date en ISO 8601
    if "test_date" in data and data["test_date"]:
        try:
            datetime.fromisoformat(str(data["test_date"]).replace("Z", "+00:00"))
        except (ValueError, AttributeError, TypeError):
            errors.append("test_date must be in ISO 8601 format")

    return {"valid": len(errors) == 0, "errors": errors}


def validate_test_result(result: Dict[str, Any], index: int) -> list:
    """Valida un resultado de test individual"""
    errors = []
    prefix = f"results[{index}]"

    required = ["test_code", "test_name", "value", "unit"]
    for field in required:
        if field not in result:
            errors.append(f"{prefix}: Missing field '{field}'")

    if "value" in result:
        try:
            float(result["value"])
        except (ValueError, TypeError):
            errors.append(f"{prefix}: 'value' must be numeric")

    return errors


def generate_result_id(data: Dict[str, Any]) -> str:
    """Genera un ID único para el resultado"""
    timestamp = datetime.utcnow().strftime("%Y%m%d%H%M%S%f")
    patient_id = data.get("patient_id", "UNKNOWN")
    lab_id = data.get("lab_id", "LAB")
    return f"{lab_id}-{patient_id}-{timestamp}"


def save_to_s3(data: Dict[str, Any], result_id: str) -> str:
    """
    Guarda el JSON crudo en S3
    """
    try:
        now = datetime.utcnow().isoformat()

        data["ingested_at"] = now
        data["result_id"] = result_id
        data["environment"] = ENVIRONMENT
        data["source_format"] = SOURCE_FORMAT
        data["payload_schema_version"] = PAYLOAD_SCHEMA_VERSION

        date_prefix = datetime.utcnow().strftime("%Y/%m/%d")
        s3_key = f"incoming/{SOURCE_FORMAT.lower()}/{date_prefix}/{result_id}.json"

        s3_client.put_object(
            Bucket=S3_BUCKET,
            Key=s3_key,
            Body=json.dumps(data, indent=2),
            ContentType="application/json",
            ServerSideEncryption="AES256",
            Metadata={
                "result-id": result_id,
                "patient-id": str(data.get("patient_id", "")),
                "lab-id": str(data.get("lab_id", "")),
                "test-type": str(data.get("test_type", "")),
                "source-format": SOURCE_FORMAT,
                "ingested-at": now,
            },
        )

        logger.info(f"Saved to S3: s3://{S3_BUCKET}/{s3_key}")
        return s3_key

    except Exception as e:
        logger.error(f"Error saving to S3: {str(e)}")
        raise


def send_to_sqs(s3_key: str, result_id: str, data: Dict[str, Any]) -> str:
    """
    Envía mensaje a SQS para procesamiento
    """
    try:
        message = {
            "result_id": result_id,
            "s3_bucket": S3_BUCKET,
            "s3_key": s3_key,
            "patient_id": data.get("patient_id"),
            "test_type": data.get("test_type"),
            "lab_id": data.get("lab_id"),
            "lab_name": data.get("lab_name"),
            "source_format": SOURCE_FORMAT,
            "payload_schema_version": PAYLOAD_SCHEMA_VERSION,
            "timestamp": datetime.utcnow().isoformat(),
            "environment": ENVIRONMENT,
        }

        response = sqs_client.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=json.dumps(message),
            MessageAttributes={
                "result_id": {"StringValue": result_id, "DataType": "String"},
                "patient_id": {
                    "StringValue": str(data.get("patient_id", "")),
                    "DataType": "String",
                },
                "test_type": {
                    "StringValue": str(data.get("test_type", "")),
                    "DataType": "String",
                },
                "lab_id": {
                    "StringValue": str(data.get("lab_id", "")),
                    "DataType": "String",
                },
                "source_format": {"StringValue": SOURCE_FORMAT, "DataType": "String"},
            },
        )

        message_id = response["MessageId"]
        logger.info(f"Sent to SQS: MessageId={message_id}")
        return message_id

    except Exception as e:
        logger.error(f"Error sending to SQS: {str(e)}")
        raise


def success_response(data: Dict[str, Any]) -> Dict[str, Any]:
    """Genera respuesta exitosa para API Gateway"""
    return {
        "statusCode": 202,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(data),
    }


def error_response(status_code: int, message) -> Dict[str, Any]:
    """Genera respuesta de error para API Gateway"""
    if isinstance(message, list):
        error_msg = "; ".join(map(str, message))
    else:
        error_msg = str(message)

    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(
            {"error": error_msg, "timestamp": datetime.utcnow().isoformat()}
        ),
    }
