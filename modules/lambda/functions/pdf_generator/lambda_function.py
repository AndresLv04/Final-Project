"""
Lambda PDF Generator Function
Genera reportes PDF de resultados de laboratorio
"""

import os
import json
import logging
from datetime import datetime
from io import BytesIO
from typing import Dict, Any

import boto3
import psycopg2
import psycopg2.extras
from botocore.client import Config

# --------------------------------------------------
# LOGGING
# --------------------------------------------------
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# --------------------------------------------------
# CLIENTES AWS
# --------------------------------------------------
s3_client = boto3.client(
    "s3", config=Config(signature_version="s3v4")  # Forzar SigV4 para presigned URLs
)
secrets_client = boto3.client("secretsmanager")

# --------------------------------------------------
# VARIABLES DE ENTORNO
#   OJO: ahora usamos DB_SECRET_ARN en lugar de DB_HOST/USER/PASS
# --------------------------------------------------
S3_BUCKET = os.environ["S3_BUCKET"]
DB_SECRET_ARN = os.environ["DB_SECRET_ARN"]  # definido en Terraform
SIGNED_URL_TTL = int(os.environ.get("SIGNED_URL_TTL", "3600"))


# --------------------------------------------------
# FUNCIONES DE DB - SECRETS MANAGER
# --------------------------------------------------
def get_db_credentials() -> Dict[str, Any]:
    """
    Lee las credenciales de la DB desde Secrets Manager.
    El secret debe tener: username, password, host, port, dbname
    """
    response = secrets_client.get_secret_value(SecretId=DB_SECRET_ARN)
    secret_str = response["SecretString"]
    return json.loads(secret_str)


def get_db_connection():
    """
    Crea una conexión psycopg2 usando el secret de Secrets Manager.
    """
    creds = get_db_credentials()
    conn = psycopg2.connect(
        host=creds["host"],
        port=creds.get("port", 5432),
        database=creds["dbname"],
        user=creds["username"],
        password=creds["password"],
        sslmode="require",
    )
    return conn


# --------------------------------------------------
# HANDLER PRINCIPAL
# --------------------------------------------------
def lambda_handler(event, context):
    """
    Handler principal
    Genera PDF para un result_id específico
    """
    try:
        logger.info("Lambda PDF Generator iniciado")
        logger.info(f"Event: {json.dumps(event)}")

        # Obtener result_id del evento
        result_id = extract_result_id(event)

        if not result_id:
            return error_response(400, "Missing result_id")

        logger.info(f"Generando PDF para result_id: {result_id}")

        # 1. Obtener datos del resultado desde RDS
        result_data = get_result_data(result_id)

        if not result_data:
            return error_response(404, f"Result not found: {result_id}")

        # 2. Generar PDF
        pdf_buffer = generate_pdf(result_data)

        # 3. Guardar PDF en S3
        s3_key = save_pdf_to_s3(pdf_buffer, result_id)

        # 4. Generar signed URL
        signed_url = generate_signed_url(s3_key, expiration=SIGNED_URL_TTL)

        logger.info(f"PDF generado exitosamente: {s3_key}")

        return success_response(
            {
                "result_id": result_id,
                "s3_key": s3_key,
                "signed_url": signed_url,
                "expires_in": SIGNED_URL_TTL,
            }
        )

    except Exception as e:
        logger.error(f"Error en lambda_handler: {str(e)}", exc_info=True)
        return error_response(500, f"Internal server error: {str(e)}")


# --------------------------------------------------
# HELPERS PARA EVENTO
# --------------------------------------------------
def extract_result_id(event: Dict[str, Any]) -> str:
    """Extrae result_id del evento"""

    # De query string parameters (API Gateway / Function URL)
    if "queryStringParameters" in event and event["queryStringParameters"]:
        return event["queryStringParameters"].get("result_id")

    # De path parameters
    if "pathParameters" in event and event["pathParameters"]:
        return event["pathParameters"].get("result_id")

    # De body
    if "body" in event:
        try:
            body = (
                json.loads(event["body"])
                if isinstance(event["body"], str)
                else event["body"]
            )
            return body.get("result_id")
        except Exception:
            pass

    # Invocación directa (tests con aws lambda invoke)
    return event.get("result_id")


# --------------------------------------------------
# CONSULTAS A RDS
# --------------------------------------------------
def get_result_data(result_id: str) -> Dict[str, Any]:
    """Obtiene todos los datos del resultado desde RDS"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

        # Query principal
        query = """
            SELECT 
                lr.result_id,
                lr.patient_id,
                p.first_name,
                p.last_name,
                p.date_of_birth,
                lr.lab_name,
                lr.test_type,
                lr.test_date,
                lr.physician_name,
                lr.physician_npi,
                lr.notes,
                lr.created_at
            FROM lab_results lr
            JOIN patients p ON lr.patient_id = p.patient_id
            WHERE lr.result_id = %s
        """

        cursor.execute(query, (result_id,))
        result = cursor.fetchone()
        if not result:
            cursor.close()
            conn.close()
            return None

        result_data = dict(result)

        # Query para obtener valores de tests
        values_query = """
            SELECT 
                test_code,
                test_name,
                value,
                unit,
                reference_range,
                is_abnormal,
                severity
            FROM test_values
            WHERE result_id = %s
            ORDER BY test_code
        """

        cursor.execute(values_query, (result_id,))
        test_values = cursor.fetchall()

        result_data["test_values"] = [dict(row) for row in test_values]

        cursor.close()
        conn.close()

        return result_data

    except Exception as e:
        logger.error(f"Error querying RDS: {str(e)}")
        raise


# --------------------------------------------------
# GENERACIÓN DE PDF
# --------------------------------------------------
def generate_pdf(data: Dict[str, Any]) -> BytesIO:
    """
    Genera el PDF con los datos del resultado
    Usa ReportLab para crear el PDF
    """
    from reportlab.lib.pagesizes import letter
    from reportlab.lib import colors
    from reportlab.lib.units import inch
    from reportlab.platypus import (
        SimpleDocTemplate,
        Table,
        TableStyle,
        Paragraph,
        Spacer,
    )
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib.enums import TA_CENTER

    buffer = BytesIO()

    # Crear documento
    doc = SimpleDocTemplate(
        buffer,
        pagesize=letter,
        rightMargin=72,
        leftMargin=72,
        topMargin=72,
        bottomMargin=72,
    )

    # Estilos
    styles = getSampleStyleSheet()

    title_style = ParagraphStyle(
        "CustomTitle",
        parent=styles["Heading1"],
        fontSize=24,
        textColor=colors.HexColor("#2c3e50"),
        spaceAfter=30,
        alignment=TA_CENTER,
    )

    heading_style = ParagraphStyle(
        "CustomHeading",
        parent=styles["Heading2"],
        fontSize=14,
        textColor=colors.HexColor("#34495e"),
        spaceAfter=12,
    )

    # Contenido del PDF
    story = []

    # Header/Logo (opcional)
    story.append(Paragraph("Healthcare Lab Results", title_style))
    story.append(Spacer(1, 0.3 * inch))

    # Información del paciente
    story.append(Paragraph("Patient Information", heading_style))

    patient_data = [
        ["Name:", f"{data['first_name']} {data['last_name']}"],
        ["Patient ID:", data["patient_id"]],
        [
            "Date of Birth:",
            (
                data["date_of_birth"].strftime("%Y-%m-%d")
                if data["date_of_birth"]
                else "N/A"
            ),
        ],
        ["Report Generated:", datetime.utcnow().strftime("%Y-%m-%d %H:%M UTC")],
    ]

    patient_table = Table(patient_data, colWidths=[2 * inch, 4 * inch])
    patient_table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (0, -1), colors.HexColor("#ecf0f1")),
                ("TEXTCOLOR", (0, 0), (-1, -1), colors.black),
                ("ALIGN", (0, 0), (-1, -1), "LEFT"),
                ("FONTNAME", (0, 0), (0, -1), "Helvetica-Bold"),
                ("FONTNAME", (1, 0), (1, -1), "Helvetica"),
                ("FONTSIZE", (0, 0), (-1, -1), 10),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
                ("TOPPADDING", (0, 0), (-1, -1), 8),
                ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
            ]
        )
    )

    story.append(patient_table)
    story.append(Spacer(1, 0.3 * inch))

    # Información del test
    story.append(Paragraph("Test Information", heading_style))

    test_info_data = [
        ["Lab:", data["lab_name"]],
        ["Test Type:", data["test_type"].replace("_", " ").title()],
        [
            "Test Date:",
            (
                data["test_date"].strftime("%Y-%m-%d %H:%M")
                if data["test_date"]
                else "N/A"
            ),
        ],
        ["Physician:", data.get("physician_name", "N/A")],
        ["NPI:", data.get("physician_npi", "N/A")],
    ]

    test_info_table = Table(test_info_data, colWidths=[2 * inch, 4 * inch])
    test_info_table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (0, -1), colors.HexColor("#ecf0f1")),
                ("TEXTCOLOR", (0, 0), (-1, -1), colors.black),
                ("ALIGN", (0, 0), (-1, -1), "LEFT"),
                ("FONTNAME", (0, 0), (0, -1), "Helvetica-Bold"),
                ("FONTNAME", (1, 0), (1, -1), "Helvetica"),
                ("FONTSIZE", (0, 0), (-1, -1), 10),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
                ("TOPPADDING", (0, 0), (-1, -1), 8),
                ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
            ]
        )
    )

    story.append(test_info_table)
    story.append(Spacer(1, 0.4 * inch))

    # Resultados de tests
    story.append(Paragraph("Test Results", heading_style))

    # Header de la tabla de resultados
    results_data = [["Test", "Result", "Unit", "Reference Range", "Status"]]

    # Datos de los tests
    for test in data["test_values"]:
        status = "ABNORMAL" if test["is_abnormal"] else "Normal"

        results_data.append(
            [
                test["test_name"],
                str(test["value"]),
                test["unit"],
                test["reference_range"],
                status,
            ]
        )

    results_table = Table(
        results_data,
        colWidths=[2.2 * inch, 0.9 * inch, 0.9 * inch, 1.3 * inch, 1 * inch],
    )

    # Estilo de la tabla de resultados
    table_style = [
        # Header
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#3498db")),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.whitesmoke),
        ("ALIGN", (0, 0), (-1, 0), "CENTER"),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, 0), 11),
        ("BOTTOMPADDING", (0, 0), (-1, 0), 12),
        # Body
        ("TEXTCOLOR", (0, 1), (-1, -1), colors.black),
        ("ALIGN", (1, 1), (3, -1), "CENTER"),
        ("FONTNAME", (0, 1), (-1, -1), "Helvetica"),
        ("FONTSIZE", (0, 1), (-1, -1), 9),
        ("BOTTOMPADDING", (0, 1), (-1, -1), 8),
        ("TOPPADDING", (0, 1), (-1, -1), 8),
        ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
        # Alternar colores de fila
        (
            "ROWBACKGROUNDS",
            (0, 1),
            (-1, -1),
            [colors.white, colors.HexColor("#f8f9fa")],
        ),
    ]

    # Resaltar valores anormales
    for idx, test in enumerate(data["test_values"], start=1):
        if test["is_abnormal"]:
            table_style.extend(
                [
                    ("BACKGROUND", (4, idx), (4, idx), colors.HexColor("#e74c3c")),
                    ("TEXTCOLOR", (4, idx), (4, idx), colors.white),
                    ("FONTNAME", (4, idx), (4, idx), "Helvetica-Bold"),
                ]
            )

    results_table.setStyle(TableStyle(table_style))
    story.append(results_table)
    story.append(Spacer(1, 0.3 * inch))

    # Notas (si existen)
    if data.get("notes"):
        story.append(Paragraph("Additional Notes", heading_style))
        notes_style = ParagraphStyle(
            "Notes",
            parent=styles["Normal"],
            fontSize=10,
            leading=14,
        )
        story.append(Paragraph(data["notes"], notes_style))
        story.append(Spacer(1, 0.3 * inch))

    # Disclaimer
    disclaimer_style = ParagraphStyle(
        "Disclaimer",
        parent=styles["Normal"],
        fontSize=8,
        textColor=colors.HexColor("#7f8c8d"),
        leading=10,
    )

    disclaimer_text = """
    <b>Important Notice:</b> These results have been reviewed and released by your healthcare provider. 
    If you have any questions or concerns about your results, please contact your physician. 
    This report is confidential and intended only for the patient named above.
    """

    story.append(Spacer(1, 0.2 * inch))
    story.append(Paragraph(disclaimer_text, disclaimer_style))

    # Footer
    footer_style = ParagraphStyle(
        "Footer",
        parent=styles["Normal"],
        fontSize=8,
        textColor=colors.grey,
        alignment=TA_CENTER,
    )

    story.append(Spacer(1, 0.3 * inch))
    story.append(
        Paragraph(
            f"Result ID: {data['result_id']} | Generated: {datetime.utcnow().strftime('%Y-%m-%d %H:%M UTC')}",
            footer_style,
        )
    )

    # Construir PDF
    doc.build(story)

    buffer.seek(0)
    return buffer


# --------------------------------------------------
# S3 + SIGNED URL
# --------------------------------------------------
def save_pdf_to_s3(pdf_buffer: BytesIO, result_id: str) -> str:
    """Guarda el PDF en S3"""
    try:
        timestamp = datetime.utcnow().strftime("%Y/%m/%d")
        s3_key = f"reports/{timestamp}/{result_id}.pdf"

        s3_client.put_object(
            Bucket=S3_BUCKET,
            Key=s3_key,
            Body=pdf_buffer.getvalue(),
            ContentType="application/pdf",
            ServerSideEncryption="AES256",
            Metadata={
                "result-id": str(result_id),
                "generated-at": datetime.utcnow().isoformat(),
            },
        )

        logger.info(f"PDF saved to S3: s3://{S3_BUCKET}/{s3_key}")
        return s3_key

    except Exception as e:
        logger.error(f"Error saving PDF to S3: {str(e)}")
        raise


def generate_signed_url(s3_key: str, expiration: int = 3600) -> str:
    """Genera una signed URL para descargar el PDF"""
    try:
        url = s3_client.generate_presigned_url(
            "get_object",
            Params={"Bucket": S3_BUCKET, "Key": s3_key},
            ExpiresIn=expiration,
        )
        return url

    except Exception as e:
        logger.error(f"Error generating signed URL: {str(e)}")
        raise


# --------------------------------------------------
# RESPUESTAS HTTP
# --------------------------------------------------
def success_response(data: Dict[str, Any]) -> Dict[str, Any]:
    """Genera respuesta exitosa"""
    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(data),
    }


def error_response(status_code: int, message: str) -> Dict[str, Any]:
    """Genera respuesta de error"""
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(
            {"error": message, "timestamp": datetime.utcnow().isoformat()}
        ),
    }
