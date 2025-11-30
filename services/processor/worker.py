#!/usr/bin/env python3
"""
Healthcare Lab Results Processor Worker
Processes lab results from SQS queue and stores in RDS PostgreSQL
"""

import os
import sys
import json
import time
import logging
import signal
from datetime import datetime
from typing import Dict, List, Optional

import boto3
import psycopg2
from psycopg2.extras import RealDictCursor  # noqa: F401  # si no lo usas todavía
from botocore.exceptions import ClientError

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger(__name__)

# Global flag for graceful shutdown
shutdown_flag = False


def signal_handler(signum, frame):
    """Handle shutdown signals gracefully"""
    global shutdown_flag
    logger.info(f"Received signal {signum}, initiating graceful shutdown...")
    shutdown_flag = True


# Register signal handlers
signal.signal(signal.SIGTERM, signal_handler)
signal.signal(signal.SIGINT, signal_handler)


class LabResultsProcessor:
    """Processes lab results from SQS to RDS"""

    def __init__(self):
        """Initialize AWS clients and database connection"""
        # Environment variables
        self.sqs_queue_url = os.environ["SQS_QUEUE_URL"]
        self.s3_bucket = os.environ["S3_BUCKET"]
        self.sns_topic_arn = os.environ.get("SNS_TOPIC_ARN")

        # Database configuration
        self.db_config = {
            "host": os.environ["DB_HOST"],
            "port": int(os.environ.get("DB_PORT", 5432)),
            "database": os.environ["DB_NAME"],
            "user": os.environ["DB_USER"],
            "password": os.environ["DB_PASSWORD"],
        }

        # AWS clients
        self.sqs = boto3.client("sqs")
        self.s3 = boto3.client("s3")
        self.sns = boto3.client("sns") if self.sns_topic_arn else None

        # Database connection
        self.db_conn = None
        self.connect_database()

        logger.info("LabResultsProcessor initialized successfully")

    def connect_database(self):
        """Establish database connection with retry logic"""
        max_retries = 5
        retry_delay = 5

        for attempt in range(max_retries):
            try:
                self.db_conn = psycopg2.connect(**self.db_config)
                self.db_conn.autocommit = False
                logger.info("Database connection established")
                return
            except psycopg2.OperationalError as e:
                logger.error(f"Database connection attempt {attempt + 1} failed: {e}")
                if attempt < max_retries - 1:
                    time.sleep(retry_delay)
                else:
                    raise

    def ensure_database_connection(self):
        """Ensure database connection is alive"""
        try:
            if self.db_conn is None or self.db_conn.closed:
                logger.warning("Database connection lost, reconnecting...")
                self.connect_database()
            else:
                # Test connection with a simple query
                with self.db_conn.cursor() as cursor:
                    cursor.execute("SELECT 1")
        except Exception as e:
            logger.error(f"Database connection check failed: {e}")
            self.connect_database()

    def poll_queue(self) -> List[Dict]:
        """Poll SQS queue for messages with long polling"""
        try:
            response = self.sqs.receive_message(
                QueueUrl=self.sqs_queue_url,
                MaxNumberOfMessages=10,  # Process up to 10 messages at once
                WaitTimeSeconds=20,  # Long polling
                MessageAttributeNames=["All"],
                AttributeNames=["All"],
            )

            messages = response.get("Messages", [])
            if messages:
                logger.info(f"Received {len(messages)} messages from queue")

            return messages

        except ClientError as e:
            logger.error(f"Error polling SQS queue: {e}")
            return []

    def download_from_s3(self, s3_key: str) -> Optional[Dict]:
        """Download JSON file from S3"""
        try:
            logger.info(f"Downloading from S3: s3://{self.s3_bucket}/{s3_key}")

            response = self.s3.get_object(
                Bucket=self.s3_bucket,
                Key=s3_key,
            )

            content = response["Body"].read().decode("utf-8")
            data = json.loads(content)

            logger.info("Successfully downloaded and parsed S3 object")
            return data

        except ClientError as e:
            logger.error(f"Error downloading from S3: {e}")
            return None
        except json.JSONDecodeError as e:
            logger.error(f"Error parsing JSON from S3: {e}")
            return None

    def validate_lab_result(self, data: Dict) -> bool:
        """Validate lab result data structure"""
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
                logger.error(f"Missing required field: {field}")
                return False

        if not isinstance(data["results"], list) or len(data["results"]) == 0:
            logger.error("Results must be a non-empty list")
            return False

        for result in data["results"]:
            required_result_fields = [
                "test_code",
                "test_name",
                "value",
                "unit",
                "reference_range",
            ]
            for field in required_result_fields:
                if field not in result:
                    logger.error(f"Missing required result field: {field}")
                    return False

        return True

    def store_lab_result(self, data: Dict, s3_key: str) -> Optional[int]:
        """Store lab result in PostgreSQL database"""
        try:
            self.ensure_database_connection()

            with self.db_conn.cursor() as cursor:
                # Insert into lab_results table
                cursor.execute(
                    """
                    INSERT INTO lab_results (
                        patient_id, lab_id, lab_name, test_type, test_date,
                        physician_name, physician_npi, status, s3_raw_key, notes
                    ) VALUES (
                        %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
                    ) RETURNING result_id
                    """,
                    (
                        data["patient_id"],
                        data["lab_id"],
                        data["lab_name"],
                        data["test_type"],
                        data["test_date"],
                        data.get("physician", {}).get("name"),
                        data.get("physician", {}).get("npi"),
                        "completed",
                        s3_key,
                        data.get("notes"),
                    ),
                )

                result_id = cursor.fetchone()[0]
                logger.info(f"Inserted lab_result with ID: {result_id}")

                # Insert test values
                for test in data["results"]:
                    cursor.execute(
                        """
                        INSERT INTO test_values (
                            result_id, test_code, test_name, value, unit,
                            reference_range, is_abnormal
                        ) VALUES (%s, %s, %s, %s, %s, %s, %s)
                        """,
                        (
                            result_id,
                            test["test_code"],
                            test["test_name"],
                            test["value"],
                            test["unit"],
                            test["reference_range"],
                            test.get("is_abnormal", False),
                        ),
                    )

                logger.info(f"Inserted {len(data['results'])} test values")

                # Log to audit_log
                cursor.execute(
                    """
                    INSERT INTO audit_log (
                        table_name, record_id, event_type, user_id, changes
                    ) VALUES (%s, %s, %s, %s, %s)
                    """,
                    (
                        "lab_results",
                        result_id,
                        "INSERT",
                        "worker",
                        json.dumps({"source": "sqs_processor"}),
                    ),
                )

                # Commit transaction
                self.db_conn.commit()
                logger.info(f"Successfully stored lab result {result_id}")

                return result_id

        except Exception as e:
            logger.error(f"Error storing lab result: {e}")
            if self.db_conn:
                self.db_conn.rollback()
            return None

    def move_to_processed(self, s3_key: str) -> Optional[str]:
        """Move file from incoming/ to processed/ in S3"""
        try:
            # Generate new key in processed/ folder
            processed_key = s3_key.replace("incoming/", "processed/", 1)

            # Copy object with server-side encryption (AES256)
            self.s3.copy_object(
                Bucket=self.s3_bucket,
                CopySource={"Bucket": self.s3_bucket, "Key": s3_key},
                Key=processed_key,
                ServerSideEncryption="AES256",
                MetadataDirective="COPY",
            )

            # Delete original
            self.s3.delete_object(
                Bucket=self.s3_bucket,
                Key=s3_key,
            )

            logger.info(f"Moved file to: s3://{self.s3_bucket}/{processed_key}")
            return processed_key

        except ClientError as e:
            logger.error(f"Error moving file in S3: {e}")
            return None

    def publish_notification(self, result_id: int, patient_id: str):
        """Publish notification to SNS topic"""
        if not self.sns or not self.sns_topic_arn:
            logger.warning("SNS not configured, skipping notification")
            return

        try:
            message = {
                "result_id": result_id,
                "patient_id": patient_id,
                "timestamp": datetime.utcnow().isoformat(),
                "event_type": "lab_result_ready",
            }

            self.sns.publish(
                TopicArn=self.sns_topic_arn,
                Message=json.dumps(message),
                Subject="Lab Result Ready for Patient",
                MessageAttributes={
                    "event_type": {
                        "DataType": "String",
                        "StringValue": "result_completed",
                    }
                },
            )

            logger.info(f"Published notification for result {result_id}")

        except ClientError as e:
            logger.error(f"Error publishing to SNS: {e}")

    def delete_message(self, receipt_handle: str):
        """Delete message from SQS queue"""
        try:
            self.sqs.delete_message(
                QueueUrl=self.sqs_queue_url,
                ReceiptHandle=receipt_handle,
            )
            logger.info("Message deleted from queue")
        except ClientError as e:
            logger.error(f"Error deleting message: {e}")

    def process_message(self, message: Dict) -> bool:
        """Process a single SQS message"""
        try:
            # Parse message body
            body = json.loads(message["Body"])
            s3_key = body["s3_key"]
            patient_id = body["patient_id"]

            logger.info(f"Processing message for patient {patient_id}")

            # Download from S3
            data = self.download_from_s3(s3_key)
            if not data:
                logger.error("Failed to download data from S3")
                return False

            # Validate data
            if not self.validate_lab_result(data):
                logger.error("Lab result validation failed")
                return False

            # Store in database
            result_id = self.store_lab_result(data, s3_key)
            if not result_id:
                logger.error("Failed to store lab result in database")
                return False

            # Move file to processed/
            processed_key = self.move_to_processed(s3_key)
            if processed_key:
                # Update s3_processed_key in database
                try:
                    with self.db_conn.cursor() as cursor:
                        cursor.execute(
                            """
                            UPDATE lab_results
                            SET s3_processed_key = %s
                            WHERE result_id = %s
                            """,
                            (processed_key, result_id),
                        )
                        self.db_conn.commit()
                except Exception as e:
                    logger.error(f"Failed to update processed key: {e}")

            # Publish notification
            self.publish_notification(result_id, patient_id)

            # Delete message from queue
            self.delete_message(message["ReceiptHandle"])

            logger.info(f"Successfully processed message for patient {patient_id}")
            return True

        except Exception as e:
            logger.error(f"Error processing message: {e}")
            return False

    def run(self):
        """Main processing loop"""
        logger.info("Worker started, polling for messages...")

        while not shutdown_flag:
            try:
                # Poll queue
                messages = self.poll_queue()

                # Process each message
                for message in messages:
                    if shutdown_flag:
                        logger.info("Shutdown flag set, stopping processing")
                        break

                    self.process_message(message)

                # If no messages, just continue polling
                if not messages:
                    logger.debug("No messages available, continuing to poll...")

            except Exception as e:
                logger.error(f"Unexpected error in main loop: {e}")
                time.sleep(5)  # Wait before retrying

        logger.info("Worker shutting down gracefully")
        if self.db_conn:
            self.db_conn.close()


def main():
    """Entry point"""
    logger.info("Healthcare Lab Results Processor Worker")
    logger.info("=" * 50)

    # Validate environment variables
    required_vars = [
        "SQS_QUEUE_URL",
        "S3_BUCKET",
        "DB_HOST",
        "DB_NAME",
        "DB_USER",
        "DB_PASSWORD",
    ]

    missing_vars = [var for var in required_vars if not os.environ.get(var)]
    if missing_vars:
        logger.error(f"Missing required environment variables: {missing_vars}")
        sys.exit(1)

    # Create and run processor
    processor = LabResultsProcessor()
    processor.run()


if __name__ == "__main__":
    main()
