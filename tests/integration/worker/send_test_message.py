#!/usr/bin/env python3
"""
Send test messages to the healthcare lab platform
Tests the complete flow: API Gateway → Lambda → S3 → SQS → ECS Worker → RDS → SNS/SES
"""

import json
import sys
import requests
import argparse
from datetime import datetime, timedelta
import random

# DEBUG: para confirmar que el script se está ejecutando
print("✅ send_test_message.py: script started")

# Test data
PATIENT_IDS = ["P234567","P123456","P345678"]

LAB_SYSTEMS = [
    {"lab_id": "LAB001", "lab_name": "Quest Diagnostics"},
    {"lab_id": "LAB002", "lab_name": "LabCorp"},
    {"lab_id": "LAB003", "lab_name": "Mayo Clinic Labs"},
]

PHYSICIANS = [
    {"name": "Dr. Sarah Johnson", "npi": "1234567890"},
    {"name": "Dr. Michael Chen", "npi": "2345678901"},
    {"name": "Dr. Emily Rodriguez", "npi": "3456789012"},
]

TEST_TEMPLATES = {
    "complete_blood_count": [
        {"test_code": "WBC", "test_name": "White Blood Cell Count", "range": (4.5, 11.0), "unit": "10^3/uL", "ref": "4.5-11.0"},
        {"test_code": "RBC", "test_name": "Red Blood Cell Count", "range": (4.5, 5.5), "unit": "10^6/uL", "ref": "4.5-5.5"},
        {"test_code": "HGB", "test_name": "Hemoglobin", "range": (13.0, 17.0), "unit": "g/dL", "ref": "13.0-17.0"},
        {"test_code": "HCT", "test_name": "Hematocrit", "range": (39.0, 49.0), "unit": "%", "ref": "39.0-49.0"},
        {"test_code": "PLT", "test_name": "Platelet Count", "range": (150, 400), "unit": "10^3/uL", "ref": "150-400"},
    ],
    "complete_metabolic_panel": [
        {"test_code": "GLU", "test_name": "Glucose", "range": (70, 100), "unit": "mg/dL", "ref": "70-100"},
        {"test_code": "BUN", "test_name": "Blood Urea Nitrogen", "range": (7, 20), "unit": "mg/dL", "ref": "7-20"},
        {"test_code": "CREAT", "test_name": "Creatinine", "range": (0.7, 1.3), "unit": "mg/dL", "ref": "0.7-1.3"},
        {"test_code": "NA", "test_name": "Sodium", "range": (136, 145), "unit": "mmol/L", "ref": "136-145"},
        {"test_code": "K", "test_name": "Potassium", "range": (3.5, 5.0), "unit": "mmol/L", "ref": "3.5-5.0"},
    ],
    "lipid_panel": [
        {"test_code": "CHOL", "test_name": "Total Cholesterol", "range": (150, 220), "unit": "mg/dL", "ref": "<200"},
        {"test_code": "TRIG", "test_name": "Triglycerides", "range": (80, 170), "unit": "mg/dL", "ref": "<150"},
        {"test_code": "HDL", "test_name": "HDL Cholesterol", "range": (40, 70), "unit": "mg/dL", "ref": ">40"},
        {"test_code": "LDL", "test_name": "LDL Cholesterol", "range": (80, 130), "unit": "mg/dL", "ref": "<100"},
    ],
    "thyroid_panel": [
        {"test_code": "TSH", "test_name": "Thyroid Stimulating Hormone", "range": (0.4, 4.0), "unit": "uIU/mL", "ref": "0.4-4.0"},
        {"test_code": "T4", "test_name": "Thyroxine (T4)", "range": (4.5, 12.0), "unit": "ug/dL", "ref": "4.5-12.0"},
        {"test_code": "T3", "test_name": "Triiodothyronine (T3)", "range": (80, 200), "unit": "ng/dL", "ref": "80-200"},
    ],
}


def generate_result(template):
    """Generate a single test result"""
    if random.random() < 0.8:
        value = round(random.uniform(template["range"][0], template["range"][1]), 1)
        is_abnormal = False
    else:
        if random.random() < 0.5:
            value = round(random.uniform(template["range"][0] * 0.7, template["range"][0]), 1)
        else:
            value = round(random.uniform(template["range"][1], template["range"][1] * 1.3), 1)
        is_abnormal = True

    return {
        "test_code": template["test_code"],
        "test_name": template["test_name"],
        "value": value,
        "unit": template["unit"],
        "reference_range": template["ref"],
        "is_abnormal": is_abnormal,
    }


def generate_lab_result():
    """Generate a complete lab result"""
    patient_id = random.choice(PATIENT_IDS)
    lab = random.choice(LAB_SYSTEMS)
    physician = random.choice(PHYSICIANS)
    test_type = random.choice(list(TEST_TEMPLATES.keys()))

    days_ago = random.randint(0, 30)
    test_date = datetime.now() - timedelta(days=days_ago)

    results = [generate_result(t) for t in TEST_TEMPLATES[test_type]]

    return {
        "patient_id": patient_id,
        "lab_id": lab["lab_id"],
        "lab_name": lab["lab_name"],
        "test_type": test_type,
        "test_date": test_date.isoformat(),
        "physician": physician,
        "results": results,
        "notes": random.choice(
            [
                "Fasting sample. Patient reported no recent illness.",
                "Non-fasting sample.",
                "Patient reported taking medications as prescribed.",
                "Follow-up test as recommended.",
                "Annual wellness check.",
            ]
        ),
    }


def send_to_api(api_url, api_key, data):
    """Send lab result to API"""
    headers = {
        "Content-Type": "application/json",
        "x-api-key": api_key,
    }

    url = f"{api_url.rstrip('/')}/api/v1/ingest"
    print(f"→ Sending POST {url}")

    try:
        resp = requests.post(url, json=data, headers=headers, timeout=10)
        print(f"  HTTP {resp.status_code}")
        resp.raise_for_status()
        return resp.json()
    except requests.exceptions.RequestException as e:
        print(f"❌ Error sending data: {e}")
        if hasattr(e, "response") and e.response is not None:
            print(f"   Response body: {e.response.text}")
        return None


def main():
    parser = argparse.ArgumentParser(description="Send test messages to healthcare lab platform")
    parser.add_argument("--api-url", required=True, help="API Gateway URL (terraform output api_endpoint)")
    parser.add_argument("--api-key", required=True, help="API Key (terraform output api_key_value)")
    parser.add_argument("--count", type=int, default=1, help="Number of messages to send")
    parser.add_argument("--save", action="store_true", help="Save messages to files instead of sending")

    args = parser.parse_args()

    print("=" * 70)
    print("Healthcare Lab Results Test Message Generator")
    print("=" * 70)
    print(f"API URL: {args.api_url}")
    print(f"Messages to send: {args.count}")
    print("=" * 70)
    print()

    success_count = 0

    for i in range(args.count):
        result = generate_lab_result()

        print(f"[{i+1}/{args.count}] Generating result for patient {result['patient_id']}")
        print(f"  Test Type: {result['test_type']}")
        print(f"  Lab: {result['lab_name']}")

        if args.save:
            filename = f"test_message_{i+1}.json"
            with open(filename, "w") as f:
                json.dump(result, f, indent=2)
            print(f"  ✓ Saved to {filename}")
        else:
            response = send_to_api(args.api_url, args.api_key, result)
            if response:
                print("  ✓ Sent successfully")
                print(f"    Result ID: {response.get('result_id', 'N/A')}")
                print(f"    Status: {response.get('status', 'N/A')}")
                success_count += 1
            else:
                print("  ❌ Failed to send")

        print()

    print("=" * 70)
    if args.save:
        print(f"Saved {args.count} messages to files")
    else:
        print(f"Sent {success_count}/{args.count} messages successfully")
    print("=" * 70)


if __name__ == "__main__":
    main()
