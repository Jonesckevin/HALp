"""
Integration Tests for WebApp Conversion Framework
End-to-end testing of complete workflows
"""
import asyncio
import pytest
import tempfile
import os
import json
from pathlib import Path
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import AsyncSession

from main import app
from database import get_db


class TestEndToEndWorkflows:
    """Test complete user workflows"""
    
    @pytest.fixture
    def authenticated_client(self, client):
        """Get authenticated test client"""
        # Register and login user
        user_data = {"email": "test@example.com", "password": "testpass123"}
        
        response = client.post("/auth/register", json=user_data)
        assert response.status_code == 200
        
        response = client.post(
            "/auth/login",
            data={"username": user_data["email"], "password": user_data["password"]}
        )
        assert response.status_code == 200
        
        token = response.json()["access_token"]
        client.headers.update({"Authorization": f"Bearer {token}"})
        
        return client
    
    def test_complete_file_workflow(self, authenticated_client):
        """Test complete file upload, processing, and download workflow"""
        # Step 1: Upload file
        test_content = "This is test file content for integration testing"
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
            f.write(test_content)
            temp_path = f.name
        
        try:
            with open(temp_path, 'rb') as f:
                upload_response = authenticated_client.post(
                    "/files/upload",
                    files={"file": ("integration_test.txt", f, "text/plain")}
                )
            
            assert upload_response.status_code == 200
            upload_data = upload_response.json()
            
            file_id = upload_data["file_id"]
            assert upload_data["filename"] == "integration_test.txt"
            assert upload_data["status"] == "uploaded"
            
            # Step 2: Check file status
            status_response = authenticated_client.get(f"/files/{file_id}/status")
            assert status_response.status_code == 200
            
            status_data = status_response.json()
            assert status_data["file_id"] == file_id
            assert status_data["status"] in ["uploaded", "processing", "completed"]
            
            # Step 3: Download file
            download_response = authenticated_client.get(f"/files/{file_id}/download")
            assert download_response.status_code == 200
            assert download_response.headers["content-type"] == "application/octet-stream"
            
            # Verify downloaded content
            downloaded_content = download_response.content.decode()
            assert downloaded_content == test_content
            
        finally:
            if os.path.exists(temp_path):
                os.unlink(temp_path)
    
    def test_bits_transfer_workflow(self, authenticated_client):
        """Test BITS transfer workflow"""
        # Step 1: Start BITS transfer
        transfer_data = {
            "source": "C:\\test\\source.txt",
            "destination": "\\\\server\\share\\dest.txt",
            "priority": "high"
        }
        
        start_response = authenticated_client.post("/bits/transfer", json=transfer_data)
        assert start_response.status_code == 200
        
        start_data = start_response.json()
        transfer_id = start_data["transfer_id"]
        assert start_data["status"] == "started"
        assert start_data["source"] == transfer_data["source"]
        assert start_data["destination"] == transfer_data["destination"]
        
        # Step 2: Check transfer status
        status_response = authenticated_client.get(f"/bits/transfer/{transfer_id}/status")
        assert status_response.status_code == 200
        
        status_data = status_response.json()
        assert status_data["transfer_id"] == transfer_id
        assert "status" in status_data
        
        # Transfer should be in one of the expected states
        assert status_data["status"] in [
            "queued", "transferring", "completed", "error"
        ]
    
    def test_smb_mount_workflow(self, authenticated_client):
        """Test SMB mount workflow"""
        # Step 1: Mount SMB share
        mount_data = {
            "server": "test-server.local",
            "share": "shared-folder",
            "credentials": {
                "username": "testuser",
                "password": "testpass",
                "domain": "TESTDOMAIN"
            }
        }
        
        mount_response = authenticated_client.post("/smb/mount", json=mount_data)
        assert mount_response.status_code == 200
        
        mount_result = mount_response.json()
        assert mount_result["server"] == mount_data["server"]
        assert mount_result["share"] == mount_data["share"]
        assert mount_result["status"] == "mounted"
        assert "mount_point" in mount_result
        
        # Step 2: List mounted shares
        list_response = authenticated_client.get("/smb/shares")
        assert list_response.status_code == 200
        
        shares_data = list_response.json()
        assert "shares" in shares_data
        assert len(shares_data["shares"]) >= 1
        
        # Verify our share is in the list
        share_found = any(
            share["server"] == mount_data["server"] and 
            share["share"] == mount_data["share"]
            for share in shares_data["shares"]
        )
        assert share_found
    
    def test_concurrent_operations(self, authenticated_client):
        """Test concurrent file operations"""
        import concurrent.futures
        import io
        
        def upload_file(content, filename):
            file_data = io.BytesIO(content.encode())
            return authenticated_client.post(
                "/files/upload",
                files={"file": (filename, file_data, "text/plain")}
            )
        
        # Create multiple concurrent uploads
        upload_tasks = [
            ("Content for file 1", "concurrent_1.txt"),
            ("Content for file 2", "concurrent_2.txt"),
            ("Content for file 3", "concurrent_3.txt"),
            ("Content for file 4", "concurrent_4.txt"),
            ("Content for file 5", "concurrent_5.txt"),
        ]
        
        with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
            futures = [
                executor.submit(upload_file, content, filename)
                for content, filename in upload_tasks
            ]
            
            results = [future.result() for future in futures]
        
        # All uploads should succeed
        for i, response in enumerate(results):
            assert response.status_code == 200, f"Upload {i+1} failed"
            
            data = response.json()
            assert "file_id" in data
            assert data["status"] == "uploaded"
    
    def test_error_handling_workflow(self, authenticated_client):
        """Test error handling in various scenarios"""
        # Test 1: Upload invalid file type
        invalid_content = b"\x00\x01\x02\x03"  # Binary content
        file_data = io.BytesIO(invalid_content)
        
        response = authenticated_client.post(
            "/files/upload",
            files={"file": ("malicious.exe", file_data, "application/x-executable")}
        )
        # Should either reject or handle safely
        assert response.status_code in [400, 422, 200]
        
        # Test 2: Access non-existent file
        response = authenticated_client.get("/files/99999/download")
        assert response.status_code == 404
        
        # Test 3: Invalid BITS transfer data
        invalid_transfer = {
            "source": "",  # Empty source
            "destination": "\\\\server\\share\\dest.txt"
        }
        
        response = authenticated_client.post("/bits/transfer", json=invalid_transfer)
        assert response.status_code == 422
        
        # Test 4: Invalid SMB mount data
        invalid_mount = {
            "server": "",  # Empty server
            "share": "test-share",
            "credentials": {"username": "test", "password": "test"}
        }
        
        response = authenticated_client.post("/smb/mount", json=invalid_mount)
        assert response.status_code == 422
    
    def test_performance_workflow(self, authenticated_client):
        """Test system performance under load"""
        import time
        
        # Measure response times for multiple operations
        operations = []
        
        # Health check performance
        start_time = time.time()
        for _ in range(10):
            response = authenticated_client.get("/health")
            assert response.status_code == 200
        health_time = (time.time() - start_time) / 10
        operations.append(("health_check", health_time))
        
        # File status check performance
        # First upload a file to get valid ID
        test_file = io.BytesIO(b"test content")
        upload_response = authenticated_client.post(
            "/files/upload",
            files={"file": ("perf_test.txt", test_file, "text/plain")}
        )
        assert upload_response.status_code == 200
        file_id = upload_response.json()["file_id"]
        
        start_time = time.time()
        for _ in range(10):
            response = authenticated_client.get(f"/files/{file_id}/status")
            assert response.status_code == 200
        status_time = (time.time() - start_time) / 10
        operations.append(("file_status", status_time))
        
        # Assert reasonable response times (< 1 second per operation)
        for operation, avg_time in operations:
            assert avg_time < 1.0, f"{operation} took {avg_time:.3f}s (too slow)"
    
    def test_data_persistence(self, authenticated_client):
        """Test data persistence across operations"""
        # Upload multiple files
        files_uploaded = []
        
        for i in range(3):
            content = f"Persistent test content {i+1}"
            file_data = io.BytesIO(content.encode())
            
            response = authenticated_client.post(
                "/files/upload",
                files={"file": (f"persistent_{i+1}.txt", file_data, "text/plain")}
            )
            assert response.status_code == 200
            
            file_id = response.json()["file_id"]
            files_uploaded.append((file_id, content))
        
        # Verify all files can be retrieved
        for file_id, original_content in files_uploaded:
            # Check status
            status_response = authenticated_client.get(f"/files/{file_id}/status")
            assert status_response.status_code == 200
            
            # Download and verify content
            download_response = authenticated_client.get(f"/files/{file_id}/download")
            assert download_response.status_code == 200
            
            downloaded_content = download_response.content.decode()
            assert downloaded_content == original_content
    
    def test_security_workflow(self, client):
        """Test security aspects of the system"""
        # Test 1: Unauthorized access
        response = client.get("/files/1/status")
        assert response.status_code == 401
        
        response = client.post("/files/upload")
        assert response.status_code == 401
        
        response = client.post("/bits/transfer")
        assert response.status_code == 401
        
        response = client.post("/smb/mount")
        assert response.status_code == 401
        
        # Test 2: Invalid token
        client.headers.update({"Authorization": "Bearer invalid-token"})
        
        response = client.get("/files/1/status")
        assert response.status_code == 401
        
        # Test 3: SQL injection attempts (should be handled by ORM)
        malicious_data = {
            "email": "test'; DROP TABLE users; --",
            "password": "password"
        }
        
        response = client.post("/auth/register", json=malicious_data)
        # Should either fail validation or be safely handled
        assert response.status_code in [400, 422]


class TestSystemIntegration:
    """Test system-level integration"""
    
    def test_database_integration(self):
        """Test database operations"""
        # This would test actual database connectivity
        # In a real environment, you'd test with a test database
        pass
    
    def test_redis_integration(self):
        """Test Redis connectivity for caching and background tasks"""
        # This would test Redis connectivity
        # In a real environment, you'd test with a test Redis instance
        pass
    
    def test_external_service_integration(self):
        """Test integration with external services"""
        # This would test BITS, SMB, and other external integrations
        # In a real environment, you'd use mock services or test endpoints
        pass


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])