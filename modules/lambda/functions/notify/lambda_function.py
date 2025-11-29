"""
Lambda Notify Function
Envía notificaciones por email cuando los resultados están listos.
"""

import json
import os
import logging
from typing import Dict, Any
from datetime import datetime

import boto3
import psycopg2

# --------------------------------------------------
# LOGGING
# --------------------------------------------------
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# --------------------------------------------------
# CLIENTES AWS
# --------------------------------------------------
ses_client = boto3.client("ses")
secrets_client = boto3.client("secretsmanager")

# --------------------------------------------------
# VARIABLES DE ENTORNO
# --------------------------------------------------
DB_SECRET_ARN = os.environ["DB_SECRET_ARN"]  # ARN del secret en Secrets Manager

SENDER_EMAIL = os.environ.get("SENDER_EMAIL", "noreply@example.com")
SES_TEMPLATE_NAME = os.environ.get("SES_TEMPLATE_NAME")  # opcional
SES_CONFIG_SET = os.environ.get("SES_CONFIG_SET")        # opcional

PORTAL_URL = os.environ.get("PORTAL_URL", "https://portal.example.com")


# --------------------------------------------------
# HELPERS DB + SECRETS
# --------------------------------------------------
def get_db_credentials() -> Dict[str, Any]:
    """
    Obtiene credenciales de la DB desde Secrets Manager.
    El secret debe tener: username, password, host, port, dbname
    """
    resp = secrets_client.get_secret_value(SecretId=DB_SECRET_ARN)
    return json.loads(resp["SecretString"])


def get_db_connection():
    """Crea una conexión psycopg2 usando el secret."""
    creds = get_db_credentials()
    conn = psycopg2.connect(
        host=creds["host"],
        port=creds.get("port", 5432),
        database=creds["dbname"],
        user=creds["username"],
        password=creds["password"],
        sslmode="require",
        connect_timeout=5,
    )
    return conn


# --------------------------------------------------
# HANDLER PRINCIPAL
# --------------------------------------------------
def lambda_handler(event, context):
    """
    Handler principal.
    Puede ser invocado por SNS o directamente.
    """
    try:
        logger.info("Lambda Notify iniciado")
        logger.info(f"Event: {json.dumps(event)}")

        records = parse_event(event)

        results = []
        for record in records:
            try:
                result = process_notification(record)
                results.append(result)
            except Exception as e:
                logger.error(
                    f"Error procesando record: {str(e)}", exc_info=True
                )
                results.append({"success": False, "error": str(e)})

        logger.info(f"Procesados {len(results)} registros")

        return {
            "statusCode": 200,
            "body": json.dumps(
                {"processed": len(results), "results": results}
            ),
        }

    except Exception as e:
        logger.error(f"Error en lambda_handler: {str(e)}", exc_info=True)
        raise


# --------------------------------------------------
# PARSEO DE EVENTO
# --------------------------------------------------
def parse_event(event: Dict[str, Any]) -> list:
    """Parsea el evento de SNS o invocación directa"""
    records = []

    # Si viene de SNS
    if "Records" in event:
        for record in event["Records"]:
            if "Sns" in record:
                message = json.loads(record["Sns"]["Message"])
                records.append(message)
            else:
                records.append(record)
    else:
        # Invocación directa
        records.append(event)

    return records


# --------------------------------------------------
# LÓGICA DE NOTIFICACIÓN
# --------------------------------------------------
def process_notification(data: Dict[str, Any]) -> Dict[str, Any]:
    """Procesa una notificación individual"""

    result_id = data.get("result_id")
    patient_id = data.get("patient_id")

    if not result_id or not patient_id:
        raise ValueError("Missing result_id or patient_id")

    logger.info(
        f"Procesando notificación para result_id={result_id}, "
        f"patient_id={patient_id}"
    )

    # 1. Obtener información del paciente desde RDS
    patient_info = get_patient_info(patient_id)

    if not patient_info:
        raise ValueError(f"Patient not found: {patient_id}")

    # 2. Obtener información del resultado
    result_info = get_result_info(result_id)

    # 3. Enviar email (si hay template configurado, lo usamos)
    if SES_TEMPLATE_NAME:
        email_result = send_email_with_template(patient_info, result_info)
    else:
        email_result = send_email(patient_info, result_info)

    # 4. Registrar en RDS (opcional)
    log_notification(result_id, patient_id, email_result)

    return {
        "success": True,
        "result_id": result_id,
        "patient_id": patient_id,
        "email": patient_info["email"],
        "message_id": email_result.get("MessageId"),
    }


# --------------------------------------------------
# QUERIES A RDS
# --------------------------------------------------
def get_patient_info(patient_id: str) -> Dict[str, Any]:
    """Obtiene información del paciente desde RDS"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        query = """
            SELECT patient_id, first_name, last_name, email
            FROM patients
            WHERE patient_id = %s AND deleted_at IS NULL
        """

        cursor.execute(query, (patient_id,))
        row = cursor.fetchone()

        cursor.close()
        conn.close()

        if not row:
            return None

        return {
            "patient_id": row[0],
            "first_name": row[1],
            "last_name": row[2],
            "email": row[3],
        }

    except Exception as e:
        logger.error(f"Error querying RDS (patient): {str(e)}")
        raise


def get_result_info(result_id: str) -> Dict[str, Any]:
    """Obtiene información del resultado desde RDS"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        query = """
            SELECT result_id, test_type, test_date, lab_name
            FROM lab_results
            WHERE result_id = %s
        """

        cursor.execute(query, (result_id,))
        row = cursor.fetchone()

        cursor.close()
        conn.close()

        if not row:
            return {
                "result_id": result_id,
                "test_type": "Unknown",
                "test_date": datetime.now().isoformat(),
                "lab_name": "Unknown",
            }

        return {
            "result_id": row[0],
            "test_type": row[1],
            "test_date": row[2].isoformat() if row[2] else "",
            "lab_name": row[3],
        }

    except Exception as e:
        logger.error(f"Error querying result info: {str(e)}")
        # No fallar si no podemos obtener info del resultado
        return {
            "result_id": result_id,
            "test_type": "Lab Result",
            "test_date": "",
            "lab_name": "",
        }


# --------------------------------------------------
# ENVÍO DE EMAIL – TEMPLATE SES
# --------------------------------------------------
def send_email_with_template(
    patient_info: Dict[str, Any], result_info: Dict[str, Any]
) -> Dict[str, Any]:
    """
    Envía email usando un template de SES (TEST 2).
    Usa la plantilla creada por Terraform: SES_TEMPLATE_NAME.
    """

    if not SES_TEMPLATE_NAME:
        raise RuntimeError("SES_TEMPLATE_NAME no está definido en variables de entorno")

    recipient = patient_info["email"]

    template_data = {
        "first_name": patient_info["first_name"],
        "test_type": result_info.get("test_type", "Lab Result").replace("_", " ").title(),
        "test_date": result_info.get("test_date", ""),
        "lab_name": result_info.get("lab_name", "N/A"),
        "result_id": result_info["result_id"],
    }

    try:
        kwargs = dict(
            Source=SENDER_EMAIL,
            Destination={"ToAddresses": [recipient]},
            Template=SES_TEMPLATE_NAME,
            TemplateData=json.dumps(template_data),
        )

        # Si definiste SES_CONFIG_SET en Terraform, lo usamos
        if SES_CONFIG_SET:
            kwargs["ConfigurationSetName"] = SES_CONFIG_SET

        response = ses_client.send_templated_email(**kwargs)

        logger.info(
            f"Templated email sent. MessageId: {response['MessageId']}"
        )
        return response

    except Exception as e:
        logger.error(f"Error sending templated email: {str(e)}")
        raise


# --------------------------------------------------
# ENVÍO DE EMAIL – SIMPLE (fallback)
# --------------------------------------------------
def send_email(
    patient_info: Dict[str, Any], result_info: Dict[str, Any]
) -> Dict[str, Any]:
    """Envía email 'plano' usando SES (fallback si no hay template)."""

    recipient = patient_info["email"]
    first_name = patient_info["first_name"]
    test_type = result_info.get("test_type", "Lab Result")
    result_url = f"{PORTAL_URL}/results/{result_info['result_id']}"

    subject = f"Your {test_type} Results Are Ready"

    body_text = f"""
Hello {first_name},

Your lab results are now available.

Test Type: {test_type}
Lab: {result_info.get('lab_name', 'N/A')}

To view your results, please log in to your patient portal:
{result_url}

If you have any questions about your results, please contact your healthcare provider.

Best regards,
Healthcare Lab Platform
    """.strip()

    body_html = f"""
<html>
<head></head>
<body>
  <h2>Your Lab Results Are Ready</h2>

  <p>Hello {first_name},</p>

  <p>Your lab results are now available for viewing.</p>

  <table style="border-collapse: collapse; margin: 20px 0;">
    <tr>
      <td style="padding: 8px; font-weight: bold;">Test Type:</td>
      <td style="padding: 8px;">{test_type}</td>
    </tr>
    <tr>
      <td style="padding: 8px; font-weight: bold;">Lab:</td>
      <td style="padding: 8px;">{result_info.get('lab_name', 'N/A')}</td>
    </tr>
  </table>

  <p>
    <a href="{result_url}"
       style="background-color: #007bff; color: white; padding: 10px 20px;
              text-decoration: none; border-radius: 5px; display: inline-block;">
      View Results
    </a>
  </p>

  <p style="color: #666; font-size: 12px; margin-top: 30px;">
    If you have any questions about your results, please contact your healthcare provider.
  </p>

  <hr style="margin: 30px 0; border: none; border-top: 1px solid #ddd;">

  <p style="color: #999; font-size: 11px;">
    Healthcare Lab Platform<br>
    This is an automated message, please do not reply.
  </p>
</body>
</html>
    """.strip()

    try:
        SOURCE = f'"Healthcare Lab Platform" <{SENDER_EMAIL}>'
        response = ses_client.send_email(
            Source=SOURCE,
            Destination={"ToAddresses": [recipient]},
            Message={
                "Subject": {"Data": subject, "Charset": "UTF-8"},
                "Body": {
                    "Text": {"Data": body_text, "Charset": "UTF-8"},
                    "Html": {"Data": body_html, "Charset": "UTF-8"},
                },
            },
        )

        logger.info(
            f"Email sent successfully. MessageId: {response['MessageId']}"
        )
        return response

    except Exception as e:
        logger.error(f"Error sending email: {str(e)}")
        raise


# --------------------------------------------------
# AUDIT LOG (OPCIONAL)
# --------------------------------------------------
def log_notification(
    result_id: str, patient_id: str, email_result: Dict[str, Any]
):
    """Registra la notificación en la base de datos (opcional)"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        query = """
            INSERT INTO audit_log (
                event_type, table_name, record_id,
                user_id, new_values, created_at
            ) VALUES (
                'NOTIFICATION', 'lab_results', %s,
                %s, %s, NOW()
            )
        """

        cursor.execute(
            query,
            (
                str(result_id),
                patient_id,
                json.dumps(
                    {
                        "message_id": email_result.get("MessageId"),
                        "status": "sent",
                        "timestamp": datetime.utcnow().isoformat(),
                    }
                ),
            ),
        )

        conn.commit()
        cursor.close()
        conn.close()

        logger.info("Notification logged to database")

    except Exception as e:
        logger.warning(f"Could not log notification: {str(e)}")
        # No fallar si no podemos loggear
