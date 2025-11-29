import json
import os
import boto3
import logging
from datetime import datetime
from typing import Dict, Any, List

logger = logging.getLogger()
logger.setLevel(logging.INFO)

lambda_client = boto3.client("lambda")

INGEST_FUNCTION_NAME = os.environ["INGEST_FUNCTION_NAME"]
LAB_ID_DEFAULT = os.environ.get("LAB_ID", "LAB002")
LAB_NAME_DEFAULT = os.environ.get("LAB_NAME", "LabCorp")

def lambda_handler(event, context):
    """
    Adapter HL7 -> JSON canónico para Lambda Ingest.
    Espera como entrada:
      - Evento S3 (archivos HL7 en texto plano), o
      - Invocación directa con 'hl7_message' en el body.
    """
    logger.info("HL7 adapter started")
    logger.info(f"Event: {json.dumps(event)}")

    # 1) Obtener el texto HL7
    hl7_text = extract_hl7_from_event(event)

    # 2) Parsear HL7 a un dict normalizado
    normalized = parse_hl7_to_json(hl7_text)

    # 3) Invocar lambda Ingest con el JSON
    response = lambda_client.invoke(
        FunctionName=INGEST_FUNCTION_NAME,
        InvocationType="Event",  # async, no esperamos la respuesta completa
        Payload=json.dumps(normalized).encode("utf-8"),
    )

    logger.info(f"Invoked ingest function: {INGEST_FUNCTION_NAME}, response: {response}")

    return {
        "statusCode": 202,
        "body": json.dumps({
            "status": "accepted",
            "message": "HL7 received, normalized and sent to ingest",
            "ingest_function": INGEST_FUNCTION_NAME
        })
    }


def extract_hl7_from_event(event: Dict[str, Any]) -> str:
    """
    Soporta:
      - Evento S3 (Records -> bucket/key)
      - Invocación directa con {'hl7_message': 'MSH|...'}
    """
    # Caso invocación directa desde consola / tests
    if "hl7_message" in event:
        return event["hl7_message"]

    # Caso evento S3
    if "Records" in event and event["Records"]:
        record = event["Records"][0]
        bucket = record["s3"]["bucket"]["name"]
        key = record["s3"]["object"]["key"]

        s3 = boto3.client("s3")
        obj = s3.get_object(Bucket=bucket, Key=key)
        body = obj["Body"].read().decode("utf-8")
        logger.info(f"Read HL7 file from s3://{bucket}/{key}")
        return body

    raise ValueError("No HL7 message found in event")


def parse_hl7_to_json(hl7_text: str) -> Dict[str, Any]:
    """
    Parseo MUY simple para el ejemplo:

    MSH|^~\&|LABCORP|LAB002|PORTAL|SYSTEM|20240115103000||ORU^R01|MSG001|P|2.5
    PID|1||P234567||Smith^John^A||19850315|M
    OBR|1||20240115-001|CBC^Complete Blood Count
    OBX|1|NM|WBC^White Blood Cell Count||7.5|10^3/uL|4.5-11.0|N|||F
    """

    lines = [l.strip() for l in hl7_text.splitlines() if l.strip()]
    segments = {line.split("|")[0]: line.split("|") for line in lines}

    # --- MSH ---
    msh = segments.get("MSH", [])
    sending_app  = msh[2] if len(msh) > 2 else ""
    sending_fac  = msh[3] if len(msh) > 3 else LAB_ID_DEFAULT
    ts_str       = msh[6] if len(msh) > 6 else ""  # 20240115103000

    test_datetime_iso = None
    if ts_str:
        try:
            dt = datetime.strptime(ts_str, "%Y%m%d%H%M%S")
            test_datetime_iso = dt.isoformat() + "Z"
        except ValueError:
            test_datetime_iso = None

    # --- PID ---
    pid = segments.get("PID", [])
    patient_id = pid[3] if len(pid) > 3 else "UNKNOWN"
    patient_name_field = pid[5] if len(pid) > 5 else ""
    # Smith^John^A
    name_parts = patient_name_field.split("^")
    last_name = name_parts[0] if len(name_parts) > 0 else ""
    first_name = name_parts[1] if len(name_parts) > 1 else ""
    patient_name = f"{first_name} {last_name}".strip()

    # --- OBR ---
    obr = segments.get("OBR", [])
    test_type_code = ""
    test_type_name = ""
    if len(obr) > 4:
        # CBC^Complete Blood Count
        parts = obr[4].split("^")
        test_type_code = parts[0]
        test_type_name = parts[1] if len(parts) > 1 else ""

    test_type = test_type_name or test_type_code or "Unknown"

    # --- OBX (puede haber varios) ---
    results: List[Dict[str, Any]] = []
    for line in lines:
        if not line.startswith("OBX|"):
            continue
        fields = line.split("|")
        # OBX|1|NM|WBC^White Blood Cell Count||7.5|10^3/uL|4.5-11.0|N|||F
        observation_id = fields[3] if len(fields) > 3 else ""
        value = fields[5] if len(fields) > 5 else ""
        unit = fields[6] if len(fields) > 6 else ""
        ref_range = fields[7] if len(fields) > 7 else ""
        flag = fields[8] if len(fields) > 8 else "N"

        comp_parts = observation_id.split("^")
        test_code = comp_parts[0]
        test_name = comp_parts[1] if len(comp_parts) > 1 else test_code

        is_abnormal = flag not in ("N", "", None)
        severity = "normal"
        if flag in ("H", "HH"):
            severity = "high"
        elif flag in ("L", "LL"):
            severity = "low"

        try:
            numeric_value = float(value)
        except (ValueError, TypeError):
            numeric_value = None

        results.append({
            "test_code": test_code,
            "test_name": test_name,
            "value": numeric_value,
            "unit": unit,
            "reference_range": ref_range,
            "is_abnormal": is_abnormal,
            "severity": severity,
        })

    normalized: Dict[str, Any] = {
        "patient_id": patient_id,
        "lab_id": sending_fac or LAB_ID_DEFAULT,
        "lab_name": LAB_NAME_DEFAULT or sending_app,
        "test_type": test_type,
        "test_date": test_datetime_iso or datetime.utcnow().isoformat() + "Z",
        "results": results,
    }

    logger.info(f"Normalized HL7 to JSON: {json.dumps(normalized)}")
    return normalized
