"""
Lambda Ingest Function
Recibe resultados de laboratorio, valida y envía a procesamiento
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
s3_client = boto3.client('s3')
sqs_client = boto3.client('sqs')

# Variables de entorno
S3_BUCKET = os.environ['S3_BUCKET']
SQS_QUEUE_URL = os.environ['SQS_QUEUE_URL']
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'dev')


def lambda_handler(event, context):
    """
    Handler principal de Lambda
    
    Args:
        event: Evento de API Gateway con el body JSON
        context: Contexto de Lambda
        
    Returns:
        dict: Response para API Gateway
    """
    try:
        logger.info("Lambda Ingest iniciado")
        logger.info(f"Event: {json.dumps(event)}")
        
        # 1. Parsear el body
        body = parse_body(event)
        
        # 2. Validar datos
        validation_result = validate_lab_result(body)
        if not validation_result['valid']:
            return error_response(400, validation_result['errors'])
        
        # 3. Generar ID único
        result_id = generate_result_id(body)
        
        # 4. Guardar en S3
        s3_key = save_to_s3(body, result_id)
        
        # 5. Enviar mensaje a SQS
        message_id = send_to_sqs(s3_key, result_id, body)
        
        # 6. Respuesta exitosa
        logger.info(f"Procesamiento exitoso. Result ID: {result_id}")
        
        return success_response({
            'result_id': result_id,
            'message_id': message_id,
            's3_key': s3_key,
            'status': 'accepted',
            'message': 'Lab result received and queued for processing'
        })
        
    except Exception as e:
        logger.error(f"Error en lambda_handler: {str(e)}", exc_info=True)
        return error_response(500, f"Internal server error: {str(e)}")


def parse_body(event: Dict[str, Any]) -> Dict[str, Any]:
    """Parsea el body del request"""
    try:
        # Si viene de API Gateway
        if 'body' in event:
            if isinstance(event['body'], str):
                return json.loads(event['body'])
            return event['body']
        
        # Si es invocación directa
        return event
        
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in request body: {str(e)}")


def validate_lab_result(data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Valida el formato del resultado de laboratorio
    
    Returns:
        dict: {'valid': bool, 'errors': list}
    """
    errors = []
    
    # Campos requeridos
    required_fields = [
        'patient_id',
        'lab_id',
        'lab_name',
        'test_type',
        'test_date',
        'results'
    ]
    
    for field in required_fields:
        if field not in data:
            errors.append(f"Missing required field: {field}")
        elif not data[field]:
            errors.append(f"Field '{field}' cannot be empty")
    
    # Validar que results sea una lista
    if 'results' in data:
        if not isinstance(data['results'], list):
            errors.append("Field 'results' must be a list")
        elif len(data['results']) == 0:
            errors.append("Field 'results' cannot be empty")
        else:
            # Validar cada resultado individual
            for idx, result in enumerate(data['results']):
                result_errors = validate_test_result(result, idx)
                errors.extend(result_errors)
    
    # Validar formato de patient_id
    if 'patient_id' in data:
        if not data['patient_id'].startswith('P'):
            errors.append("patient_id must start with 'P'")
    
    # Validar formato de test_date
    if 'test_date' in data:
        try:
            datetime.fromisoformat(data['test_date'].replace('Z', '+00:00'))
        except (ValueError, AttributeError):
            errors.append("test_date must be in ISO 8601 format")
    
    return {
        'valid': len(errors) == 0,
        'errors': errors
    }


def validate_test_result(result: Dict[str, Any], index: int) -> list:
    """Valida un resultado de test individual"""
    errors = []
    prefix = f"results[{index}]"
    
    required = ['test_code', 'test_name', 'value', 'unit']
    for field in required:
        if field not in result:
            errors.append(f"{prefix}: Missing field '{field}'")
    
    # Validar que value sea numérico
    if 'value' in result:
        try:
            float(result['value'])
        except (ValueError, TypeError):
            errors.append(f"{prefix}: 'value' must be numeric")
    
    return errors


def generate_result_id(data: Dict[str, Any]) -> str:
    """Genera un ID único para el resultado"""
    timestamp = datetime.utcnow().strftime('%Y%m%d%H%M%S%f')
    patient_id = data.get('patient_id', 'UNKNOWN')
    return f"{patient_id}-{timestamp}"


def save_to_s3(data: Dict[str, Any], result_id: str) -> str:
    """
    Guarda el JSON crudo en S3
    
    Returns:
        str: S3 key del archivo guardado
    """
    try:
        # Agregar metadata
        data['ingested_at'] = datetime.utcnow().isoformat()
        data['result_id'] = result_id
        data['environment'] = ENVIRONMENT
        
        # Generar key
        timestamp = datetime.utcnow().strftime('%Y/%m/%d')
        s3_key = f"incoming/{timestamp}/{result_id}.json"
        
        # Guardar en S3
        s3_client.put_object(
            Bucket=S3_BUCKET,
            Key=s3_key,
            Body=json.dumps(data, indent=2),
            ContentType='application/json',
            ServerSideEncryption='AES256',
            Metadata={
                'result-id': result_id,
                'patient-id': data.get('patient_id', ''),
                'test-type': data.get('test_type', ''),
                'ingested-at': data['ingested_at']
            }
        )
        
        logger.info(f"Saved to S3: s3://{S3_BUCKET}/{s3_key}")
        return s3_key
        
    except Exception as e:
        logger.error(f"Error saving to S3: {str(e)}")
        raise


def send_to_sqs(s3_key: str, result_id: str, data: Dict[str, Any]) -> str:
    """
    Envía mensaje a SQS para procesamiento
    
    Returns:
        str: Message ID de SQS
    """
    try:
        message = {
            'result_id': result_id,
            's3_bucket': S3_BUCKET,
            's3_key': s3_key,
            'patient_id': data.get('patient_id'),
            'test_type': data.get('test_type'),
            'timestamp': datetime.utcnow().isoformat(),
            'environment': ENVIRONMENT
        }
        
        response = sqs_client.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=json.dumps(message),
            MessageAttributes={
                'result_id': {
                    'StringValue': result_id,
                    'DataType': 'String'
                },
                'patient_id': {
                    'StringValue': data.get('patient_id', ''),
                    'DataType': 'String'
                },
                'test_type': {
                    'StringValue': data.get('test_type', ''),
                    'DataType': 'String'
                }
            }
        )
        
        message_id = response['MessageId']
        logger.info(f"Sent to SQS: MessageId={message_id}")
        
        return message_id
        
    except Exception as e:
        logger.error(f"Error sending to SQS: {str(e)}")
        raise


def success_response(data: Dict[str, Any]) -> Dict[str, Any]:
    """Genera respuesta exitosa para API Gateway"""
    return {
        'statusCode': 202,  # Accepted
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps(data)
    }


def error_response(status_code: int, message: str) -> Dict[str, Any]:
    """Genera respuesta de error para API Gateway"""
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps({
            'error': message,
            'timestamp': datetime.utcnow().isoformat()
        })
    }