"""
FastAPI Application Main Module
Modern web application backend with async support, file operations, and comprehensive features.
"""
import asyncio
import logging
import os
from contextlib import asynccontextmanager
from pathlib import Path

import uvicorn
from fastapi import FastAPI, HTTPException, Depends, UploadFile, File, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, FileResponse
from sqlalchemy.ext.asyncio import AsyncSession

from .config import settings
from .database import get_db, init_db
from .models import User, FileRecord
from .auth import verify_token, create_access_token
from .file_operations import FileManager
from .bits_integration import BITSManager
from .smb_integration import SMBManager
from .schemas import (
    UserCreate, UserResponse, Token, 
    FileUploadResponse, FileDownloadRequest,
    BITSTransferRequest, SMBMountRequest
)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan context manager"""
    # Startup
    logger.info("Starting application...")
    await init_db()
    
    # Create upload directories
    Path(settings.UPLOAD_DIR).mkdir(parents=True, exist_ok=True)
    Path(settings.DOWNLOAD_DIR).mkdir(parents=True, exist_ok=True)
    
    yield
    
    # Shutdown
    logger.info("Shutting down application...")


# Create FastAPI application
app = FastAPI(
    title="WebApp Conversion Framework API",
    description="Modern web application with file operations, BITS integration, and SMB support",
    version="1.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    lifespan=lifespan
)

# Add middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_middleware(
    TrustedHostMiddleware, 
    allowed_hosts=settings.ALLOWED_HOSTS
)

# Security
security = HTTPBearer()

# Initialize managers
file_manager = FileManager()
bits_manager = BITSManager()
smb_manager = SMBManager()


# Health check endpoint
@app.get("/health", tags=["Health"])
async def health_check():
    """Health check endpoint for container monitoring"""
    return {"status": "healthy", "timestamp": asyncio.get_event_loop().time()}


# Authentication endpoints
@app.post("/auth/register", response_model=UserResponse, tags=["Authentication"])
async def register(user_data: UserCreate, db: AsyncSession = Depends(get_db)):
    """Register a new user"""
    # Implementation would check if user exists, hash password, etc.
    # This is a simplified version
    logger.info(f"User registration attempt: {user_data.email}")
    return {"id": 1, "email": user_data.email, "is_active": True}


@app.post("/auth/login", response_model=Token, tags=["Authentication"])
async def login(email: str, password: str, db: AsyncSession = Depends(get_db)):
    """User login endpoint"""
    # Implementation would verify credentials
    logger.info(f"Login attempt: {email}")
    access_token = create_access_token(data={"sub": email})
    return {"access_token": access_token, "token_type": "bearer"}


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db)
):
    """Get current authenticated user"""
    payload = verify_token(credentials.credentials)
    if payload is None:
        raise HTTPException(status_code=401, detail="Invalid authentication credentials")
    
    # In real implementation, fetch user from database
    return {"email": payload.get("sub"), "id": 1}


# File operations endpoints
@app.post("/files/upload", response_model=FileUploadResponse, tags=["File Operations"])
async def upload_file(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Upload file with progress tracking"""
    try:
        file_record = await file_manager.upload_file(file, current_user["id"], db)
        
        # Process file in background
        background_tasks.add_task(file_manager.process_file, file_record.id, db)
        
        logger.info(f"File uploaded: {file.filename} by user {current_user['id']}")
        
        return FileUploadResponse(
            file_id=file_record.id,
            filename=file_record.filename,
            size=file_record.size,
            status="uploaded"
        )
    
    except Exception as e:
        logger.error(f"File upload error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")


@app.get("/files/{file_id}/download", tags=["File Operations"])
async def download_file(
    file_id: int,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Download file by ID"""
    try:
        file_path = await file_manager.get_file_path(file_id, current_user["id"], db)
        
        if not Path(file_path).exists():
            raise HTTPException(status_code=404, detail="File not found")
        
        logger.info(f"File download: {file_id} by user {current_user['id']}")
        
        return FileResponse(
            path=file_path,
            media_type='application/octet-stream',
            filename=Path(file_path).name
        )
    
    except Exception as e:
        logger.error(f"File download error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Download failed: {str(e)}")


@app.get("/files/{file_id}/status", tags=["File Operations"])
async def get_file_status(
    file_id: int,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get file processing status"""
    try:
        status = await file_manager.get_file_status(file_id, current_user["id"], db)
        return {"file_id": file_id, "status": status}
    
    except Exception as e:
        logger.error(f"Status check error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Status check failed: {str(e)}")


# BITS integration endpoints
@app.post("/bits/transfer", tags=["BITS Integration"])
async def start_bits_transfer(
    transfer_request: BITSTransferRequest,
    background_tasks: BackgroundTasks,
    current_user=Depends(get_current_user)
):
    """Start BITS file transfer"""
    try:
        transfer_id = await bits_manager.start_transfer(
            transfer_request.source,
            transfer_request.destination,
            current_user["id"]
        )
        
        # Monitor transfer in background
        background_tasks.add_task(bits_manager.monitor_transfer, transfer_id)
        
        logger.info(f"BITS transfer started: {transfer_id} by user {current_user['id']}")
        
        return {
            "transfer_id": transfer_id,
            "status": "started",
            "source": transfer_request.source,
            "destination": transfer_request.destination
        }
    
    except Exception as e:
        logger.error(f"BITS transfer error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"BITS transfer failed: {str(e)}")


@app.get("/bits/transfer/{transfer_id}/status", tags=["BITS Integration"])
async def get_bits_transfer_status(
    transfer_id: str,
    current_user=Depends(get_current_user)
):
    """Get BITS transfer status"""
    try:
        status = await bits_manager.get_transfer_status(transfer_id, current_user["id"])
        return {"transfer_id": transfer_id, **status}
    
    except Exception as e:
        logger.error(f"BITS status error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Status check failed: {str(e)}")


# SMB integration endpoints
@app.post("/smb/mount", tags=["SMB Integration"])
async def mount_smb_share(
    mount_request: SMBMountRequest,
    current_user=Depends(get_current_user)
):
    """Mount SMB share"""
    try:
        mount_point = await smb_manager.mount_share(
            mount_request.server,
            mount_request.share,
            mount_request.credentials,
            current_user["id"]
        )
        
        logger.info(f"SMB share mounted: {mount_request.server}/{mount_request.share} by user {current_user['id']}")
        
        return {
            "server": mount_request.server,
            "share": mount_request.share,
            "mount_point": mount_point,
            "status": "mounted"
        }
    
    except Exception as e:
        logger.error(f"SMB mount error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"SMB mount failed: {str(e)}")


@app.get("/smb/shares", tags=["SMB Integration"])
async def list_smb_shares(current_user=Depends(get_current_user)):
    """List mounted SMB shares for user"""
    try:
        shares = await smb_manager.list_user_shares(current_user["id"])
        return {"shares": shares}
    
    except Exception as e:
        logger.error(f"SMB list error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to list shares: {str(e)}")


# Static files and frontend
app.mount("/static", StaticFiles(directory="static"), name="static")


@app.get("/", response_class=HTMLResponse, tags=["Frontend"])
async def serve_frontend():
    """Serve the main frontend application"""
    with open("static/index.html", "r") as f:
        return HTMLResponse(content=f.read())


if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.DEBUG,
        log_level="info"
    )