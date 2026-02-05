import unittest
from unittest.mock import patch, MagicMock
import os
import json
import app

class TestBFFIntegration(unittest.TestCase):
    def setUp(self):
        self.app = app.app.test_client()
        self.app.testing = True

    @patch('app.requests.post')
    @patch('app.requests.get')
    @patch('app.boto3.client')
    @patch('app.subprocess.run')
    def test_convert_video_success_flow(self, mock_subprocess, mock_boto, mock_get, mock_post):
        # Setup Mocks
        
        # Mock Status API responses
        # 1. get_job_details response
        mock_get.return_value.status_code = 200
        mock_get.return_value.json.return_value = {
            "jobId": "test-job-uuid",
            "status": "waiting_upload_r2",
            "fileName": "test_input.mp4",
            "createdAt": "2023-01-01T00:00:00Z"
        }
        
        # 2. update_job_status response (post)
        mock_post.return_value.status_code = 200

        # Mock S3/R2 Client
        mock_s3_client = MagicMock()
        mock_boto.return_value = mock_s3_client

        # Patch globals in app module
        with patch('app.INPUT_BUCKET', 'in-bucket'), patch('app.OUTPUT_BUCKET', 'out-bucket'):
            # Payload sent to /convert
            payload = {
                "jobId": "test-job-uuid",
                "format": "mp4",
                "options": {"quality": "high"}
            }

            response = self.app.post('/convert', 
                                     data=json.dumps(payload),
                                     content_type='application/json')

            # Assertions
            self.assertEqual(response.status_code, 200)
            data = response.json
            self.assertEqual(data['status'], 'success')
            self.assertIn('outputKey', data)
            
            # Verify Status API calls
            # Expect calls: 
            # 1. "processing" (0%)
            # 2. GET status/{jobId}
            # 3. "processing" (10%) - after download
            # 4. "processing" (20%) - before convert
            # 5. "processing" (90%) - after convert/before upload
            # 6. "completed" (100%) - final
            
            # Check if GET was called (fetching metadata)
            mock_get.assert_called_with("https://converter-status.rajan-1si18cs083.workers.dev/status/test-job-uuid", timeout=10)
            
            # Check if POST was called for "completed"
            # We can check specific calls or just that it was called multiple times
            self.assertTrue(mock_post.call_count >= 2)
            
            # Check final completion call args
            last_call_args = mock_post.call_args_list[-1]
            last_call_json = last_call_args[1]['json']
            self.assertEqual(last_call_json['status'], 'completed')
            self.assertEqual(last_call_json['progress'], 100)
            self.assertIn('outputKey', last_call_json)

            # Verify S3 interactions
            mock_s3_client.download_file.assert_called()
            mock_s3_client.upload_file.assert_called()

            # Verify ffmpeg called
            mock_subprocess.assert_called()

    @patch('app.requests.post')
    def test_missing_job_id(self, mock_post):
        payload = {"format": "mp4"}
        response = self.app.post('/convert', 
                                 data=json.dumps(payload),
                                 content_type='application/json')
        self.assertEqual(response.status_code, 400)

if __name__ == '__main__':
    unittest.main()
