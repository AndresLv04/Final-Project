import csv
import io
import json
import logging
import os
from datetime import datetime
from typing import Any, Dict, List

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

lambda_client = boto3.client("lambda")

INGEST_FUNCTION_NAME = os.environ["INGEST_FUNCTION_NAME"]
LAB_NAME_DEFAULT = os.environ.get("LAB_NAME", "Small Lab")


def lambda_handler(event, context):
    """
    Adapter CSV -> JSON canónico para Lambda Ingest.

    Soporta:
      - Evento S3 con archivos CSV
      - Invocación directa con {"csv_body": "...csv..."}
    """
    logger.info("CSV adapter started")
    logger.info(f"Event: {json.dumps(event)}")

    # 1) Obtener CSV como texto
    csv_text = extract_csv_from_event(event)

    # 2) Parsear CSV a JSON normalizado
    normalized = parse_csv_to_json(csv_text)

    # 3) Invocar Lambda Ingest
    response = lambda_client.invoke(
        FunctionName=INGEST_FUNCTION_NAME,
        InvocationType="Event",  # async
        Payload=json.dumps(normalized).encode("utf-8"),
    )

    logger.info(
        "Invoked ingest function: %s, response: %s",
        INGEST_FUNCTION_NAME,
        response,
    )

    return {
        "statusCode": 202,
        "body": json.dumps(
            {
                "status": "accepted",
                "message": "CSV received, normalized and sent to ingest",
                "ingest_function": INGEST_FUNCTION_NAME,
            }
        ),
    }


def extract_csv_from_event(event: Dict[str, Any]) -> str:
    """
    Si viene directo: {"csv_body": "PatientID,LabID,..."}
    Si viene de S3: Records[0].s3.bucket.name / object.key
    """
    if "csv_body" in event:
        return event["csv_body"]

    if "Records" in event and event["Records"]:
        record = event["Records"][0]
        bucket = record["s3"]["bucket"]["name"]
        key = record["s3"]["object"]["key"]

        s3 = boto3.client("s3")
        obj = s3.get_object(Bucket=bucket, Key=key)
        body = obj["Body"].read().decode("utf-8")
        logger.info("Read CSV file from s3://%s/%s", bucket, key)
        return body

    raise ValueError("No CSV found in event")


def parse_csv_to_json(csv_text: str) -> Dict[str, Any]:
    """
    Espera columnas:
      PatientID,LabID,TestDate,TestCode,TestName,Value,Unit,RefRange

    Asumimos:
      - un solo paciente por archivo
      - misma fecha para todas las filas
    """
    file_obj = io.StringIO(csv_text)
    reader = csv.DictReader(file_obj)

    rows: List[Dict[str, str]] = list(reader)

    if not rows:
        raise ValueError("CSV has no data rows")

    first = rows[0]

    patient_id = first.get("PatientID", "UNKNOWN")
    lab_id = first.get("LabID", "").strip() or "SMALL001"
    test_date_raw = first.get("TestDate", "")
    test_code = first.get("TestCode", "")
    test_name = first.get("TestName", "")

    # Test type para el resultado “global”
    if test_name and test_code:
        test_type = f"{test_code} / {test_name}"
    else:
        test_type = test_name or test_code or "Unknown"

    # Normalizar fecha a ISO
    if test_date_raw:
        try:
            dt = datetime.strptime(test_date_raw, "%Y-%m-%d")
            test_date_iso = dt.isoformat() + "Z"
        except ValueError:
            # si falla, usamos el valor como venga
            test_date_iso = test_date_raw
    else:
        test_date_iso = datetime.utcnow().isoformat() + "Z"

    results: List[Dict[str, Any]] = []

    for row in rows:
        code = row.get("TestCode", "")
        name = row.get("TestName", "") or code
        value_str = row.get("Value", "")
        unit = row.get("Unit", "")
        ref_range = row.get("RefRange", "")

        try:
            value = float(value_str)
        except (ValueError, TypeError):
            value = None

        # Sin flags en CSV, asumimos normal por ahora
        is_abnormal = False
        severity = "normal"

        results.append(
            {
                "test_code": code,
                "test_name": name,
                "value": value,
                "unit": unit,
                "reference_range": ref_range,
                "is_abnormal": is_abnormal,
                "severity": severity,
            }
        )

    normalized: Dict[str, Any] = {
        "patient_id": patient_id,
        "lab_id": lab_id,
        "lab_name": LAB_NAME_DEFAULT,
        "test_type": test_type,
        "test_date": test_date_iso,
        "results": results,
    }

    logger.info("Normalized CSV to JSON: %s", json.dumps(normalized))
    return normalized
