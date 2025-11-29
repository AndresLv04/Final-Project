import json
import os
import boto3
import logging
from datetime import datetime
from typing import Dict, Any, List
import xml.etree.ElementTree as ET

logger = logging.getLogger()
logger.setLevel(logging.INFO)

lambda_client = boto3.client("lambda")

INGEST_FUNCTION_NAME = os.environ["INGEST_FUNCTION_NAME"]
LAB_ID_DEFAULT = os.environ.get("LAB_ID", "HOSP001")
LAB_NAME_DEFAULT = os.environ.get("LAB_NAME", "Hospital Lab")


def lambda_handler(event, context):
    """
    Adapter XML -> JSON canónico para Lambda Ingest.
    Soporta:
      - Evento S3 (archivo XML)
      - Invocación directa con {"xml_body": "<LabResult>...</LabResult>"}
    """
    logger.info("XML adapter started")
    logger.info(f"Event: {json.dumps(event)}")

    # 1) Obtener XML como texto
    xml_text = extract_xml_from_event(event)

    # 2) Parsear XML a JSON normalizado
    normalized = parse_xml_to_json(xml_text)

    # 3) Invocar Lambda Ingest
    response = lambda_client.invoke(
        FunctionName=INGEST_FUNCTION_NAME,
        InvocationType="Event",  # async
        Payload=json.dumps(normalized).encode("utf-8"),
    )

    logger.info(
        f"Invoked ingest function: {INGEST_FUNCTION_NAME}, response: {response}"
    )

    return {
        "statusCode": 202,
        "body": json.dumps(
            {
                "status": "accepted",
                "message": "XML received, normalized and sent to ingest",
                "ingest_function": INGEST_FUNCTION_NAME,
            }
        ),
    }


def extract_xml_from_event(event: Dict[str, Any]) -> str:
    """
    Si viene directo: {"xml_body": "<LabResult>...</LabResult>"}
    Si viene de S3: Records[0].s3.bucket.name / object.key
    """
    # Invocación directa para pruebas
    if "xml_body" in event:
        return event["xml_body"]

    # Evento S3
    if "Records" in event and event["Records"]:
        record = event["Records"][0]
        bucket = record["s3"]["bucket"]["name"]
        key = record["s3"]["object"]["key"]

        s3 = boto3.client("s3")
        obj = s3.get_object(Bucket=bucket, Key=key)
        body = obj["Body"].read().decode("utf-8")
        logger.info(f"Read XML file from s3://{bucket}/{key}")
        return body

    raise ValueError("No XML found in event")


def parse_xml_to_json(xml_text: str) -> Dict[str, Any]:
    """
    Ejemplo de XML:

    <LabResult>
      <LabID>HOSP001</LabID>
      <Patient ID="P345678">
        <Name>Maria Garcia</Name>
        <DOB>1985-03-15</DOB>   <!-- opcional -->
      </Patient>
      <Tests>
        <Test code="CBC" name="Complete Blood Count" date="2024-01-15T10:30:00Z">
          <Component code="WBC" name="White Blood Cell Count" value="7.5"
                     unit="10^3/uL" refRange="4.5-11.0" flag="N"/>
        </Test>
      </Tests>
    </LabResult>
    """

    root = ET.fromstring(xml_text)

    # Lab info
    lab_id_node = root.find("LabID")
    lab_id = (lab_id_node.text if lab_id_node is not None else LAB_ID_DEFAULT).strip()

    # Paciente
    patient_node = root.find("Patient")
    patient_id = patient_node.get("ID") if patient_node is not None else "UNKNOWN"

    name_node = patient_node.find("Name") if patient_node is not None else None
    patient_name = name_node.text.strip() if name_node is not None else ""

    # Tests
    tests_node = root.find("Tests")
    first_test_node = None
    if tests_node is not None:
        first_test_node = tests_node.find("Test")

    test_type_code = ""
    test_type_name = ""
    test_date_iso = None

    if first_test_node is not None:
        test_type_code = first_test_node.get("code", "") or ""
        test_type_name = first_test_node.get("name", "") or ""
        test_date_raw = first_test_node.get("date")

        if test_date_raw:
            # Ya viene ISO? usamos directo
            try:
                # Intentamos parsear por si viene sin Z
                dt = datetime.fromisoformat(test_date_raw.replace("Z", "+00:00"))
                test_date_iso = dt.isoformat().replace("+00:00", "Z")
            except Exception:
                test_date_iso = test_date_raw

    test_type = test_type_name or test_type_code or "Unknown"
    test_date_iso = test_date_iso or (datetime.utcnow().isoformat() + "Z")

    # Components -> results[]
    results: List[Dict[str, Any]] = []

    if tests_node is not None:
        for test_node in tests_node.findall("Test"):
            for comp in test_node.findall("Component"):
                code = comp.get("code", "")
                name = comp.get("name", "") or code
                value_str = comp.get("value", "")
                unit = comp.get("unit", "")
                ref_range = comp.get("refRange", "")
                flag = comp.get("flag", "N")

                try:
                    value = float(value_str)
                except (ValueError, TypeError):
                    value = None

                is_abnormal = flag not in ("N", "", None)
                severity = "normal"
                if flag in ("H", "HH"):
                    severity = "high"
                elif flag in ("L", "LL"):
                    severity = "low"

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

    logger.info(f"Normalized XML to JSON: {json.dumps(normalized)}")
    return normalized
