"""
Backend API Tests using pytest and FastAPI TestClient
Comprehensive test suite for the WebApp Conversion Framework
"""
import asyncio
import pytest
import tempfile
import os
from pathlib import Path
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.pool import StaticPool

from main import app
from database import get_db, Base
from config import settings


# Test database setup
TEST_DATABASE_URL = "sqlite+aiosqlite:///./test.db"

engine = create_async_engine(
    TEST_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)

TestingSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False
)


async def override_get_db():
    """Override database dependency for testing"""
    async with TestingSessionLocal() as session:
        yield session


app.dependency_overrides[get_db] = override_get_db


@pytest.fixture(scope="session")
def event_loop():
    """Create an instance of the default event loop for the test session."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


@pytest.fixture(scope="session")
async def setup_database():
    """Set up test database"""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest.fixture
def client(setup_database):
    """Create test client"""
    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture
def test_user():
    """Test user data"""
    return {
        "email": "test@example.com",
        "password": "testpassword123"
    }


@pytest.fixture
def auth_headers(client, test_user):
    """Get authentication headers"""
    # Register user
    response = client.post("/auth/register", json=test_user)
    assert response.status_code == 200
    
    # Login to get token
    response = client.post(
        "/auth/login",
        data={"username": test_user["email"], "password": test_user["password"]}
    )
    assert response.status_code == 200
    
    token = response.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def temp_file():
    """Create temporary test file"""
    with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
        f.write("This is test file content")
        temp_path = f.name
    
    yield temp_path
    
    # Cleanup
    if os.path.exists(temp_path):
        os.unlink(temp_path)


class TestHealthCheck:
    """Test health check endpoint"""
    
    def test_health_check(self, client):
        """Test health check endpoint returns healthy status"""
        response = client.get("/health")
        assert response.status_code == 200
        
        data = response.json()
        assert data["status"] == "healthy"
        assert "timestamp" in data


class TestAuthentication:
    """Test authentication endpoints"""
    
    def test_register_user(self, client, test_user):
        """Test user registration"""
        response = client.post("/auth/register", json=test_user)
        assert response.status_code == 200
        
        data = response.json()
        assert data["email"] == test_user["email"]
        assert data["is_active"] == True
        assert "id" in data
    
    def test_register_duplicate_user(self, client, test_user):
        """Test registration with duplicate email fails"""
        # Register first user
        response = client.post("/auth/register", json=test_user)
        assert response.status_code == 200
        
        # Try to register same user again
        response = client.post("/auth/register", json=test_user)
        assert response.status_code == 400
    
    def test_login_user(self, client, test_user):
        """Test user login"""
        # Register user first
        client.post("/auth/register", json=test_user)
        
        # Login
        response = client.post(
            "/auth/login",
            data={"username": test_user["email"], "password": test_user["password"]}
        )
        assert response.status_code == 200
        
        data = response.json()
        assert data["access_token"]
        assert data["token_type"] == "bearer"
    
    def test_login_invalid_credentials(self, client, test_user):
        """Test login with invalid credentials"""
        response = client.post(
            "/auth/login",
            data={"username": test_user["email"], "password": "wrongpassword"}
        )
        assert response.status_code == 401


class TestFileOperations:
    """Test file operation endpoints"""
    
    def test_upload_file(self, client, auth_headers, temp_file):
        """Test file upload"""
        with open(temp_file, 'rb') as f:
            response = client.post(
                "/files/upload",
                files={"file": ("test.txt", f, "text/plain")},
                headers=auth_headers
            )
        
        assert response.status_code == 200
        
        data = response.json()
        assert "file_id" in data
        assert data["filename"] == "test.txt"
        assert data["status"] == "uploaded"
        assert data["size"] > 0
    
    def test_upload_file_unauthorized(self, client, temp_file):
        """Test file upload without authentication fails"""
        with open(temp_file, 'rb') as f:
            response = client.post(
                "/files/upload",
                files={"file": ("test.txt", f, "text/plain")}
            )
        
        assert response.status_code == 401
    
    def test_upload_empty_file(self, client, auth_headers):
        """Test upload with no file fails"""
        response = client.post(
            "/files/upload",
            headers=auth_headers
        )
        
        assert response.status_code == 422  # Validation error
    
    def test_get_file_status(self, client, auth_headers, temp_file):
        """Test getting file status"""
        # Upload file first
        with open(temp_file, 'rb') as f:
            upload_response = client.post(
                "/files/upload",
                files={"file": ("test.txt", f, "text/plain")},
                headers=auth_headers
            )
        
        file_id = upload_response.json()["file_id"]
        
        # Get status
        response = client.get(f"/files/{file_id}/status", headers=auth_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert data["file_id"] == file_id
        assert "status" in data
    
    def test_download_file(self, client, auth_headers, temp_file):
        """Test file download"""
        # Upload file first
        with open(temp_file, 'rb') as f:
            upload_response = client.post(
                "/files/upload",
                files={"file": ("test.txt", f, "text/plain")},
                headers=auth_headers
            )
        
        file_id = upload_response.json()["file_id"]
        
        # Download file
        response = client.get(f"/files/{file_id}/download", headers=auth_headers)
        assert response.status_code == 200
        assert response.headers["content-type"] == "application/octet-stream"
    
    def test_download_nonexistent_file(self, client, auth_headers):
        """Test downloading non-existent file returns 404"""
        response = client.get("/files/99999/download", headers=auth_headers)
        assert response.status_code == 404


class TestBITSIntegration:
    """Test BITS integration endpoints"""
    
    def test_start_bits_transfer(self, client, auth_headers):
        """Test starting BITS transfer"""
        transfer_data = {
            "source": "C:\\test\\source.txt",
            "destination": "\\\\server\\share\\dest.txt",
            "priority": "normal"
        }
        
        response = client.post(
            "/bits/transfer",
            json=transfer_data,
            headers=auth_headers
        )
        
        assert response.status_code == 200
        
        data = response.json()
        assert "transfer_id" in data
        assert data["status"] == "started"
        assert data["source"] == transfer_data["source"]
        assert data["destination"] == transfer_data["destination"]
    
    def test_start_bits_transfer_invalid_priority(self, client, auth_headers):
        """Test BITS transfer with invalid priority fails"""
        transfer_data = {
            "source": "C:\\test\\source.txt",
            "destination": "\\\\server\\share\\dest.txt",
            "priority": "invalid"
        }
        
        response = client.post(
            "/bits/transfer",
            json=transfer_data,
            headers=auth_headers
        )
        
        assert response.status_code == 422  # Validation error
    
    def test_get_bits_transfer_status(self, client, auth_headers):
        """Test getting BITS transfer status"""
        # Start transfer first
        transfer_data = {
            "source": "C:\\test\\source.txt",
            "destination": "\\\\server\\share\\dest.txt"
        }
        
        response = client.post(
            "/bits/transfer",
            json=transfer_data,
            headers=auth_headers
        )
        
        transfer_id = response.json()["transfer_id"]
        
        # Get status
        response = client.get(
            f"/bits/transfer/{transfer_id}/status",
            headers=auth_headers
        )
        
        assert response.status_code == 200
        
        data = response.json()
        assert data["transfer_id"] == transfer_id
        assert "status" in data


class TestSMBIntegration:
    """Test SMB integration endpoints"""
    
    def test_mount_smb_share(self, client, auth_headers):
        """Test mounting SMB share"""
        mount_data = {
            "server": "test-server",
            "share": "test-share",
            "credentials": {
                "username": "testuser",
                "password": "testpass",
                "domain": "testdomain"
            }
        }
        
        response = client.post(
            "/smb/mount",
            json=mount_data,
            headers=auth_headers
        )
        
        assert response.status_code == 200
        
        data = response.json()
        assert data["server"] == mount_data["server"]
        assert data["share"] == mount_data["share"]
        assert data["status"] == "mounted"
        assert "mount_point" in data
    
    def test_mount_smb_share_invalid_server(self, client, auth_headers):
        """Test mounting SMB share with invalid server fails"""
        mount_data = {
            "server": "",  # Empty server name
            "share": "test-share",
            "credentials": {
                "username": "testuser",
                "password": "testpass"
            }
        }
        
        response = client.post(
            "/smb/mount",
            json=mount_data,
            headers=auth_headers
        )
        
        assert response.status_code == 422  # Validation error
    
    def test_list_smb_shares(self, client, auth_headers):
        """Test listing mounted SMB shares"""
        response = client.get("/smb/shares", headers=auth_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert "shares" in data
        assert isinstance(data["shares"], list)


class TestErrorHandling:
    """Test error handling"""
    
    def test_404_endpoint(self, client):
        """Test non-existent endpoint returns 404"""
        response = client.get("/nonexistent")
        assert response.status_code == 404
    
    def test_unauthorized_access(self, client):
        """Test unauthorized access returns 401"""
        response = client.get("/files/1/status")
        assert response.status_code == 401
    
    def test_invalid_json(self, client, auth_headers):
        """Test invalid JSON request returns 422"""
        response = client.post(
            "/bits/transfer",
            data="invalid json",
            headers={**auth_headers, "Content-Type": "application/json"}
        )
        assert response.status_code == 422


class TestPerformance:
    """Test performance characteristics"""
    
    def test_concurrent_uploads(self, client, auth_headers):
        """Test handling multiple concurrent uploads"""
        import concurrent.futures
        import io
        
        def upload_file(file_content):
            file_data = io.BytesIO(file_content.encode())
            return client.post(
                "/files/upload",
                files={"file": ("test.txt", file_data, "text/plain")},
                headers=auth_headers
            )
        
        # Create multiple uploads concurrently
        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
            futures = [
                executor.submit(upload_file, f"Test content {i}")
                for i in range(10)
            ]
            
            results = [future.result() for future in futures]
        
        # All uploads should succeed
        for response in results:
            assert response.status_code == 200
    
    def test_large_file_upload(self, client, auth_headers):
        """Test uploading large file (within limits)"""
        # Create 1MB test file
        large_content = "x" * (1024 * 1024)
        file_data = io.BytesIO(large_content.encode())
        
        response = client.post(
            "/files/upload",
            files={"file": ("large.txt", file_data, "text/plain")},
            headers=auth_headers
        )
        
        assert response.status_code == 200
        
        data = response.json()
        assert data["size"] == len(large_content)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])