"""
Database models and configuration
"""
import asyncio
from datetime import datetime
from typing import AsyncGenerator

from sqlalchemy import Column, Integer, String, Boolean, DateTime, Text, BigInteger, ForeignKey
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship

from .config import settings

# Create async engine
engine = create_async_engine(
    settings.DATABASE_URL,
    echo=settings.DEBUG,
    future=True
)

# Create async session factory
AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False
)

# Create base class
Base = declarative_base()


class User(Base):
    """User model"""
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    is_active = Column(Boolean, default=True)
    is_superuser = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    files = relationship("FileRecord", back_populates="owner")
    bits_transfers = relationship("BITSTransfer", back_populates="user")
    smb_mounts = relationship("SMBMount", back_populates="user")


class FileRecord(Base):
    """File record model"""
    __tablename__ = "file_records"
    
    id = Column(Integer, primary_key=True, index=True)
    filename = Column(String, nullable=False)
    original_filename = Column(String, nullable=False)
    file_path = Column(String, nullable=False)
    file_size = Column(BigInteger, nullable=False)
    mime_type = Column(String, nullable=False)
    status = Column(String, default="uploaded")  # uploaded, processing, completed, error
    progress = Column(Integer, default=0)  # 0-100
    error_message = Column(Text, nullable=True)
    
    # Timestamps
    uploaded_at = Column(DateTime, default=datetime.utcnow)
    processed_at = Column(DateTime, nullable=True)
    
    # Foreign keys
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    # Relationships
    owner = relationship("User", back_populates="files")


class BITSTransfer(Base):
    """BITS transfer model"""
    __tablename__ = "bits_transfers"
    
    id = Column(Integer, primary_key=True, index=True)
    transfer_id = Column(String, unique=True, index=True, nullable=False)
    source = Column(String, nullable=False)
    destination = Column(String, nullable=False)
    priority = Column(String, default="normal")
    status = Column(String, default="queued")  # queued, transferring, completed, error, cancelled
    progress = Column(Integer, default=0)  # 0-100
    bytes_transferred = Column(BigInteger, default=0)
    total_bytes = Column(BigInteger, nullable=True)
    transfer_rate = Column(BigInteger, nullable=True)  # bytes per second
    error_message = Column(Text, nullable=True)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    started_at = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)
    
    # Foreign keys
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    # Relationships
    user = relationship("User", back_populates="bits_transfers")


class SMBMount(Base):
    """SMB mount model"""
    __tablename__ = "smb_mounts"
    
    id = Column(Integer, primary_key=True, index=True)
    server = Column(String, nullable=False)
    share = Column(String, nullable=False)
    mount_point = Column(String, nullable=False)
    status = Column(String, default="mounted")  # mounted, unmounted, error
    mount_options = Column(Text, nullable=True)  # JSON string
    error_message = Column(Text, nullable=True)
    
    # Timestamps
    mounted_at = Column(DateTime, default=datetime.utcnow)
    last_accessed = Column(DateTime, nullable=True)
    unmounted_at = Column(DateTime, nullable=True)
    
    # Foreign keys
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    # Relationships
    user = relationship("User", back_populates="smb_mounts")


class BackgroundTask(Base):
    """Background task model"""
    __tablename__ = "background_tasks"
    
    id = Column(Integer, primary_key=True, index=True)
    task_id = Column(String, unique=True, index=True, nullable=False)
    task_type = Column(String, nullable=False)
    status = Column(String, default="queued")  # queued, running, completed, failed
    priority = Column(String, default="normal")
    parameters = Column(Text, nullable=True)  # JSON string
    result = Column(Text, nullable=True)  # JSON string
    error_message = Column(Text, nullable=True)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    started_at = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)
    
    # Foreign keys
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)


class AuditLog(Base):
    """Audit log model"""
    __tablename__ = "audit_logs"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    action = Column(String, nullable=False)
    resource_type = Column(String, nullable=False)
    resource_id = Column(String, nullable=True)
    details = Column(Text, nullable=True)  # JSON string
    ip_address = Column(String, nullable=True)
    user_agent = Column(String, nullable=True)
    
    # Timestamp
    created_at = Column(DateTime, default=datetime.utcnow)


# Database dependency
async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """Get database session"""
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()


# Database initialization
async def init_db():
    """Initialize database tables"""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


# Database cleanup
async def close_db():
    """Close database connections"""
    await engine.dispose()


# Utility functions
async def get_user_by_email(db: AsyncSession, email: str):
    """Get user by email"""
    from sqlalchemy import select
    result = await db.execute(select(User).where(User.email == email))
    return result.scalar_one_or_none()


async def create_user(db: AsyncSession, email: str, hashed_password: str):
    """Create new user"""
    user = User(email=email, hashed_password=hashed_password)
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


async def get_user_files(db: AsyncSession, user_id: int, skip: int = 0, limit: int = 100):
    """Get user files with pagination"""
    from sqlalchemy import select
    result = await db.execute(
        select(FileRecord)
        .where(FileRecord.owner_id == user_id)
        .offset(skip)
        .limit(limit)
        .order_by(FileRecord.uploaded_at.desc())
    )
    return result.scalars().all()


async def get_user_bits_transfers(db: AsyncSession, user_id: int):
    """Get user BITS transfers"""
    from sqlalchemy import select
    result = await db.execute(
        select(BITSTransfer)
        .where(BITSTransfer.user_id == user_id)
        .order_by(BITSTransfer.created_at.desc())
    )
    return result.scalars().all()


async def get_user_smb_mounts(db: AsyncSession, user_id: int):
    """Get user SMB mounts"""
    from sqlalchemy import select
    result = await db.execute(
        select(SMBMount)
        .where(SMBMount.user_id == user_id)
        .where(SMBMount.status == "mounted")
        .order_by(SMBMount.mounted_at.desc())
    )
    return result.scalars().all()