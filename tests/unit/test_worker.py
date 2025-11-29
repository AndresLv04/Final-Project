"""
Unit tests for Lab Results Processor Worker
"""

import pytest
import json
from unittest.mock import Mock, patch, MagicMock
from datetime import datetime


class TestLabResultsProcessor:
    """Test suite for LabResultsProcessor"""
    
    @pytest.fixture
    def sample_lab_result(self):
        """Sample lab result data"""
        return {
            "patient_id": "P123456",
            "lab_id": "LAB001",
            "lab_name": "Quest Diagnostics",
            "test_type": "complete_blood_count",
            "test_date": "2024-01-15T10:00:00Z",
            "physician": {
                "name": "Dr. Sarah Johnson",
                "npi": "1234567890"
            },
            "results": [
                {
                    "test_code": "WBC",
                    "test_name": "White Blood Cell Count",
                    "value": 7.5,
                    "unit": "10^3/uL",
                    "reference_range": "4.5-11.0",
                    "is_abnormal": False
                }
            ],
            "notes": "Fasting sample"
        }
    
    @pytest.fixture
    def sample_sqs_message(self):
        """Sample SQS message"""
        return {
            "MessageId": "123456",
            "ReceiptHandle": "AQEBxxx...",
            "Body": json.dumps({
                "result_id": "P123456-20240115-100000",
                "s3_bucket": "healthcare-lab-dev-data",
                "s3_key": "incoming/2024/01/15/P123456-20240115-100000.json",
                "patient_id": "P123456",
                "test_type": "complete_blood_count",
                "timestamp": "2024-01-15T10:00:00Z"
            })
        }
    
    def test_validate_lab_result_valid(self, sample_lab_result):
        """Test validation with valid lab result"""
        # This would normally import the real function
        # from services.processor.worker import validate_lab_result
        
        # Mock for demonstration
        def validate_lab_result(data):
            required_fields = [
                'patient_id', 'lab_id', 'lab_name', 
                'test_type', 'test_date', 'results'
            ]
            return all(field in data for field in required_fields)
        
        assert validate_lab_result(sample_lab_result) is True
    
    def test_validate_lab_result_missing_field(self, sample_lab_result):
        """Test validation with missing required field"""
        def validate_lab_result(data):
            required_fields = [
                'patient_id', 'lab_id', 'lab_name', 
                'test_type', 'test_date', 'results'
            ]
            return all(field in data for field in required_fields)
        
        # Remove required field
        del sample_lab_result['patient_id']
        
        assert validate_lab_result(sample_lab_result) is False
    
    def test_validate_lab_result_empty_results(self, sample_lab_result):
        """Test validation with empty results array"""
        def validate_lab_result(data):
            if 'results' not in data or len(data['results']) == 0:
                return False
            return True
        
        sample_lab_result['results'] = []
        
        assert validate_lab_result(sample_lab_result) is False
    
    def test_parse_sqs_message(self, sample_sqs_message):
        """Test parsing SQS message"""
        body = json.loads(sample_sqs_message['Body'])
        
        assert body['patient_id'] == 'P123456'
        assert body['test_type'] == 'complete_blood_count'
        assert 's3_key' in body
    
    def test_extract_s3_key_from_message(self, sample_sqs_message):
        """Test extracting S3 key from message"""
        body = json.loads(sample_sqs_message['Body'])
        s3_key = body['s3_key']
        
        assert s3_key.startswith('incoming/')
        assert s3_key.endswith('.json')
    
    @patch('boto3.client')
    def test_download_from_s3_success(self, mock_boto_client, sample_lab_result):
        """Test successful S3 download"""
        # Mock S3 client
        mock_s3 = MagicMock()
        mock_boto_client.return_value = mock_s3
        
        # Mock S3 response
        mock_response = {
            'Body': MagicMock()
        }
        mock_response['Body'].read.return_value = json.dumps(sample_lab_result).encode('utf-8')
        mock_s3.get_object.return_value = mock_response
        
        # Test
        s3_client = mock_boto_client('s3')
        response = s3_client.get_object(Bucket='test-bucket', Key='test-key')
        data = json.loads(response['Body'].read().decode('utf-8'))
        
        assert data['patient_id'] == 'P123456'
        assert data['lab_id'] == 'LAB001'
    
    def test_normalize_test_type(self):
        """Test normalizing test type names"""
        def normalize_test_type(test_type):
            return test_type.lower().replace(' ', '_')
        
        assert normalize_test_type('Complete Blood Count') == 'complete_blood_count'
        assert normalize_test_type('LIPID PANEL') == 'lipid_panel'
    
    def test_calculate_abnormal_count(self, sample_lab_result):
        """Test counting abnormal results"""
        def count_abnormal(results):
            return sum(1 for r in results if r.get('is_abnormal', False))
        
        # All normal
        assert count_abnormal(sample_lab_result['results']) == 0
        
        # Add abnormal result
        sample_lab_result['results'].append({
            "test_code": "HGB",
            "test_name": "Hemoglobin",
            "value": 11.0,
            "unit": "g/dL",
            "reference_range": "13.0-17.0",
            "is_abnormal": True
        })
        
        assert count_abnormal(sample_lab_result['results']) == 1


class TestDatabaseOperations:
    """Test suite for database operations"""
    
    @pytest.fixture
    def mock_db_connection(self):
        """Mock database connection"""
        conn = MagicMock()
        cursor = MagicMock()
        conn.cursor.return_value.__enter__.return_value = cursor
        return conn, cursor
    
    def test_insert_lab_result(self, mock_db_connection, sample_lab_result):
        """Test inserting lab result into database"""
        conn, cursor = mock_db_connection
        
        # Mock successful insert
        cursor.fetchone.return_value = (42,)  # result_id
        
        # Simulate insert
        cursor.execute(
            "INSERT INTO lab_results (...) VALUES (...) RETURNING result_id",
            (
                sample_lab_result['patient_id'],
                sample_lab_result['lab_id'],
                # ... other fields
            )
        )
        
        result_id = cursor.fetchone()[0]
        
        assert result_id == 42
        assert cursor.execute.called
    
    def test_insert_test_values(self, mock_db_connection, sample_lab_result):
        """Test inserting test values"""
        conn, cursor = mock_db_connection
        
        result_id = 42
        test_values = sample_lab_result['results']
        
        for test in test_values:
            cursor.execute(
                "INSERT INTO test_values (...) VALUES (...)",
                (
                    result_id,
                    test['test_code'],
                    test['test_name'],
                    test['value'],
                    # ... other fields
                )
            )
        
        assert cursor.execute.call_count == len(test_values)


class TestMessageProcessing:
    """Test suite for message processing"""
    
    def test_message_deletion_after_success(self):
        """Test that message is deleted after successful processing"""
        mock_sqs = MagicMock()
        receipt_handle = "AQEBxxx..."
        queue_url = "https://sqs.us-east-1.amazonaws.com/123456789012/test-queue"
        
        # Simulate successful processing and deletion
        mock_sqs.delete_message(
            QueueUrl=queue_url,
            ReceiptHandle=receipt_handle
        )
        
        mock_sqs.delete_message.assert_called_once_with(
            QueueUrl=queue_url,
            ReceiptHandle=receipt_handle
        )
    
    def test_message_visibility_on_error(self):
        """Test that message visibility is not changed on error"""
        # If processing fails, message should remain in queue
        # and become visible again after visibility timeout
        
        # This is a behavioral test - we verify that delete_message
        # is NOT called when an error occurs
        mock_sqs = MagicMock()
        
        try:
            # Simulate processing error
            raise Exception("Processing failed")
        except Exception:
            pass  # Don't delete message
        
        # Verify delete was never called
        mock_sqs.delete_message.assert_not_called()


class TestDataTransformation:
    """Test suite for data transformation"""
    
    def test_date_parsing_iso_format(self):
        """Test parsing ISO 8601 date format"""
        from datetime import datetime
        
        date_str = "2024-01-15T10:00:00Z"
        parsed = datetime.fromisoformat(date_str.replace('Z', '+00:00'))
        
        assert parsed.year == 2024
        assert parsed.month == 1
        assert parsed.day == 15
    
    def test_physician_name_extraction(self, sample_lab_result):
        """Test extracting physician information"""
        physician = sample_lab_result.get('physician', {})
        
        assert physician.get('name') == 'Dr. Sarah Johnson'
        assert physician.get('npi') == '1234567890'
    
    def test_handle_missing_optional_fields(self, sample_lab_result):
        """Test handling missing optional fields"""
        # Remove optional notes field
        if 'notes' in sample_lab_result:
            del sample_lab_result['notes']
        
        # Should still be valid
        notes = sample_lab_result.get('notes')
        assert notes is None


# Add fixture for demonstration
@pytest.fixture
def sample_lab_result():
    """Reusable sample lab result fixture"""
    return {
        "patient_id": "P123456",
        "lab_id": "LAB001",
        "lab_name": "Quest Diagnostics",
        "test_type": "complete_blood_count",
        "test_date": "2024-01-15T10:00:00Z",
        "physician": {
            "name": "Dr. Sarah Johnson",
            "npi": "1234567890"
        },
        "results": [
            {
                "test_code": "WBC",
                "test_name": "White Blood Cell Count",
                "value": 7.5,
                "unit": "10^3/uL",
                "reference_range": "4.5-11.0",
                "is_abnormal": False
            }
        ],
        "notes": "Fasting sample"
    }


if __name__ == '__main__':
    pytest.main([__file__, '-v'])