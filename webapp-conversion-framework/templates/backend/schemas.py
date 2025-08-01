"""
Pydantic schemas for request/response models
"""
from typing import Optional, List, Dict, Any
from datetime import datetime
from pydantic import BaseModel, EmailStr, validator


# User schemas
class UserBase(BaseModel):
    """Base user schema"""
    email: EmailStr


class UserCreate(UserBase):
    """User creation schema"""
    password: str
    
    @validator('password')
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters long')
        return v


class UserResponse(UserBase):
    """User response schema"""
    id: int
    is_active: bool
    created_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True


# Authentication schemas
class Token(BaseModel):
    """Token response schema"""
    access_token: str
    token_type: str


class TokenData(BaseModel):
    """Token data schema"""
    email: Optional[str] = None


# File operation schemas
class FileUploadResponse(BaseModel):
    """File upload response schema"""
    file_id: int
    filename: str
    size: int
    status: str
    upload_time: Optional[datetime] = None


class FileDownloadRequest(BaseModel):
    """File download request schema"""
    file_id: int
    format: Optional[str] = "original"


class FileStatusResponse(BaseModel):
    """File status response schema"""
    file_id: int
    filename: str
    status: str  # uploaded, processing, completed, error
    progress: Optional[int] = None  # 0-100
    error_message: Optional[str] = None
    
    
class FileListResponse(BaseModel):
    """File list response schema"""
    files: List[FileStatusResponse]
    total: int
    page: int
    per_page: int


# BITS integration schemas
class BITSTransferRequest(BaseModel):
    """BITS transfer request schema"""
    source: str
    destination: str
    priority: Optional[str] = "normal"  # high, normal, low
    
    @validator('priority')
    def validate_priority(cls, v):
        if v not in ['high', 'normal', 'low']:
            raise ValueError('Priority must be high, normal, or low')
        return v


class BITSTransferResponse(BaseModel):
    """BITS transfer response schema"""
    transfer_id: str
    source: str
    destination: str
    status: str
    priority: str
    created_at: datetime


class BITSStatusResponse(BaseModel):
    """BITS transfer status response schema"""
    transfer_id: str
    status: str  # queued, transferring, completed, error, cancelled
    progress: Optional[int] = None  # 0-100
    bytes_transferred: Optional[int] = None
    total_bytes: Optional[int] = None
    transfer_rate: Optional[float] = None  # bytes per second
    estimated_completion: Optional[datetime] = None
    error_message: Optional[str] = None


# SMB integration schemas
class SMBCredentials(BaseModel):
    """SMB credentials schema"""
    username: str
    password: str
    domain: Optional[str] = None


class SMBMountRequest(BaseModel):
    """SMB mount request schema"""
    server: str
    share: str
    credentials: SMBCredentials
    mount_options: Optional[Dict[str, Any]] = {}
    
    @validator('server')
    def validate_server(cls, v):
        # Basic validation for server name/IP
        if not v or len(v.strip()) == 0:
            raise ValueError('Server name cannot be empty')
        return v.strip()


class SMBMountResponse(BaseModel):
    """SMB mount response schema"""
    server: str
    share: str
    mount_point: str
    status: str
    mounted_at: datetime


class SMBShareInfo(BaseModel):
    """SMB share information schema"""
    server: str
    share: str
    mount_point: str
    status: str
    mounted_at: datetime
    last_accessed: Optional[datetime] = None


# Background task schemas
class TaskRequest(BaseModel):
    """Background task request schema"""
    task_type: str
    parameters: Dict[str, Any]
    priority: Optional[str] = "normal"


class TaskResponse(BaseModel):
    """Background task response schema"""
    task_id: str
    task_type: str
    status: str  # queued, running, completed, failed
    created_at: datetime
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    result: Optional[Dict[str, Any]] = None
    error_message: Optional[str] = None


# API response schemas
class APIResponse(BaseModel):
    """Generic API response schema"""
    success: bool
    message: str
    data: Optional[Dict[str, Any]] = None
    errors: Optional[List[str]] = None


class PaginatedResponse(BaseModel):
    """Paginated response schema"""
    items: List[Any]
    total: int
    page: int
    per_page: int
    total_pages: int
    has_next: bool
    has_prev: bool


# Health check schemas
class HealthCheckResponse(BaseModel):
    """Health check response schema"""
    status: str
    timestamp: float
    version: str
    environment: str
    database_status: str
    redis_status: Optional[str] = None
    disk_usage: Optional[Dict[str, Any]] = None
    memory_usage: Optional[Dict[str, Any]] = None


# Configuration schemas
class AppConfig(BaseModel):
    """Application configuration schema"""
    max_file_size: int
    allowed_file_types: List[str]
    upload_dir: str
    download_dir: str
    features: Dict[str, bool]