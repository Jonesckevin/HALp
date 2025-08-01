"""
Configuration settings for the FastAPI application
"""
import os
from typing import List
from pydantic import BaseSettings


class Settings(BaseSettings):
    """Application settings"""
    
    # Application settings
    APP_NAME: str = "WebApp Conversion Framework"
    DEBUG: bool = False
    VERSION: str = "1.0.0"
    
    # Database settings
    DATABASE_URL: str = "postgresql+asyncpg://user:password@localhost:5432/webapp"
    
    # Security settings
    SECRET_KEY: str = "your-super-secret-key-change-this-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    
    # CORS settings
    ALLOWED_ORIGINS: List[str] = ["http://localhost:3000", "http://localhost:8080"]
    ALLOWED_HOSTS: List[str] = ["localhost", "127.0.0.1"]
    
    # File storage settings
    UPLOAD_DIR: str = "./uploads"
    DOWNLOAD_DIR: str = "./downloads"
    MAX_FILE_SIZE: int = 100 * 1024 * 1024  # 100MB
    ALLOWED_FILE_TYPES: List[str] = [
        "image/jpeg", "image/png", "image/gif",
        "application/pdf", "text/plain", "application/json",
        "application/zip", "application/x-zip-compressed"
    ]
    
    # BITS integration settings
    BITS_ENDPOINT: str = "http://localhost:8080/bits"
    BITS_TIMEOUT: int = 300  # 5 minutes
    
    # SMB settings
    SMB_TIMEOUT: int = 30
    SMB_MOUNT_BASE: str = "./mounts"
    
    # Redis settings (for caching and background tasks)
    REDIS_URL: str = "redis://localhost:6379"
    
    # Logging settings
    LOG_LEVEL: str = "INFO"
    LOG_FILE: str = "./logs/app.log"
    
    # Performance settings
    MAX_WORKERS: int = 4
    KEEPALIVE_TIMEOUT: int = 5
    
    class Config:
        env_file = ".env"
        case_sensitive = True


# Create settings instance
settings = Settings()


# Environment-specific configurations
class DevelopmentSettings(Settings):
    """Development environment settings"""
    DEBUG: bool = True
    LOG_LEVEL: str = "DEBUG"
    ALLOWED_ORIGINS: List[str] = ["*"]


class ProductionSettings(Settings):
    """Production environment settings"""
    DEBUG: bool = False
    LOG_LEVEL: str = "WARNING"
    # Override with secure settings from environment variables


class TestingSettings(Settings):
    """Testing environment settings"""
    DATABASE_URL: str = "sqlite+aiosqlite:///./test.db"
    SECRET_KEY: str = "test-secret-key"
    UPLOAD_DIR: str = "./test_uploads"
    DOWNLOAD_DIR: str = "./test_downloads"


def get_settings() -> Settings:
    """Get settings based on environment"""
    env = os.getenv("ENVIRONMENT", "development").lower()
    
    if env == "production":
        return ProductionSettings()
    elif env == "testing":
        return TestingSettings()
    else:
        return DevelopmentSettings()


# Use appropriate settings
settings = get_settings()