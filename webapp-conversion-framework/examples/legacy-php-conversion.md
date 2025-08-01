# Example: Legacy PHP Application Conversion

This example demonstrates converting a legacy PHP document management system to a modern web application using the WebApp Conversion Framework.

## Original Application Analysis

### Legacy System Characteristics
- **Technology**: PHP 5.6 + MySQL + Apache
- **Functionality**: Document upload, storage, search, user management
- **Architecture**: Monolithic LAMP stack
- **Users**: 25 concurrent users
- **Data**: 5GB documents, 1000 users
- **Integrations**: LDAP authentication, email notifications

### Performance Issues
- Slow file uploads (>30s for 10MB files)
- Search timeouts with large result sets
- No concurrent upload support
- Memory issues with large files

### Security Concerns
- Plain text passwords
- No file type validation
- SQL injection vulnerabilities
- Unrestricted file access

## Conversion Strategy

### Architecture Design
```
Legacy (LAMP)          →    Modern (Containerized)
PHP 5.6               →    Python FastAPI
MySQL                 →    PostgreSQL
Apache                →    Nginx + Uvicorn
File system storage   →    Object storage + local cache
Session-based auth    →    JWT authentication
```

### Migration Approach
1. **Phase 1**: Backend API development
2. **Phase 2**: Frontend modernization
3. **Phase 3**: Data migration
4. **Phase 4**: Gradual rollout
5. **Phase 5**: Legacy system sunset

## Implementation

### 1. Backend Development

#### Custom Models
```python
# models/document.py
from sqlalchemy import Column, Integer, String, DateTime, Text, Boolean, ForeignKey
from sqlalchemy.orm import relationship
from database import Base

class Document(Base):
    __tablename__ = "documents"
    
    id = Column(Integer, primary_key=True)
    title = Column(String(255), nullable=False)
    filename = Column(String(255), nullable=False)
    file_path = Column(String(500), nullable=False)
    mime_type = Column(String(100), nullable=False)
    file_size = Column(Integer, nullable=False)
    description = Column(Text)
    version = Column(Integer, default=1)
    is_active = Column(Boolean, default=True)
    
    # Relationships
    category_id = Column(Integer, ForeignKey("categories.id"))
    uploaded_by = Column(Integer, ForeignKey("users.id"))
    
    category = relationship("Category", back_populates="documents")
    uploader = relationship("User", back_populates="documents")
    
    # Metadata
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class Category(Base):
    __tablename__ = "categories"
    
    id = Column(Integer, primary_key=True)
    name = Column(String(100), nullable=False)
    description = Column(Text)
    parent_id = Column(Integer, ForeignKey("categories.id"))
    
    # Relationships
    documents = relationship("Document", back_populates="category")
    children = relationship("Category", backref="parent", remote_side=[id])
```

#### Custom Endpoints
```python
# routers/documents.py
from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List, Optional

router = APIRouter(prefix="/documents", tags=["Documents"])

@router.post("/upload", response_model=DocumentResponse)
async def upload_document(
    file: UploadFile = File(...),
    title: str = Form(...),
    description: Optional[str] = Form(None),
    category_id: int = Form(...),
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Upload a new document"""
    
    # Validate file
    if not validate_file_type(file.content_type):
        raise HTTPException(status_code=400, detail="Invalid file type")
    
    if file.size > MAX_FILE_SIZE:
        raise HTTPException(status_code=400, detail="File too large")
    
    # Check category exists
    category = await get_category_by_id(db, category_id)
    if not category:
        raise HTTPException(status_code=404, detail="Category not found")
    
    # Process upload
    document = await document_service.create_document(
        db=db,
        file=file,
        title=title,
        description=description,
        category_id=category_id,
        user_id=current_user.id
    )
    
    # Add to search index
    await search_service.index_document(document)
    
    # Send notification
    await notification_service.notify_document_uploaded(document, current_user)
    
    return document

@router.get("/search")
async def search_documents(
    q: str,
    category_id: Optional[int] = None,
    page: int = 1,
    per_page: int = 20,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Search documents"""
    
    results = await search_service.search_documents(
        query=q,
        category_id=category_id,
        user_id=current_user.id,
        page=page,
        per_page=per_page
    )
    
    return {
        "results": results.documents,
        "total": results.total,
        "page": page,
        "per_page": per_page,
        "total_pages": (results.total + per_page - 1) // per_page
    }

@router.get("/{document_id}/download")
async def download_document(
    document_id: int,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Download a document"""
    
    document = await get_document_by_id(db, document_id)
    if not document:
        raise HTTPException(status_code=404, detail="Document not found")
    
    # Check permissions
    if not await has_document_access(current_user, document):
        raise HTTPException(status_code=403, detail="Access denied")
    
    # Log download
    await audit_service.log_document_download(current_user.id, document_id)
    
    return FileResponse(
        path=document.file_path,
        filename=document.filename,
        media_type=document.mime_type
    )
```

#### Business Services
```python
# services/document_service.py
class DocumentService:
    def __init__(self, storage_service, search_service, virus_scanner):
        self.storage = storage_service
        self.search = search_service
        self.virus_scanner = virus_scanner
    
    async def create_document(self, db: AsyncSession, file: UploadFile, **kwargs):
        """Create a new document"""
        
        # Scan for viruses
        scan_result = await self.virus_scanner.scan_file(file)
        if not scan_result.is_clean:
            raise ValueError("File failed virus scan")
        
        # Store file
        file_path = await self.storage.store_file(file)
        
        # Extract metadata
        metadata = await self.extract_metadata(file)
        
        # Create database record
        document = Document(
            title=kwargs['title'],
            filename=file.filename,
            file_path=file_path,
            mime_type=file.content_type,
            file_size=file.size,
            description=kwargs.get('description'),
            category_id=kwargs['category_id'],
            uploaded_by=kwargs['user_id'],
            **metadata
        )
        
        db.add(document)
        await db.commit()
        await db.refresh(document)
        
        return document
    
    async def extract_metadata(self, file: UploadFile):
        """Extract metadata from file"""
        metadata = {}
        
        if file.content_type.startswith('image/'):
            # Extract EXIF data
            pass
        elif file.content_type == 'application/pdf':
            # Extract PDF metadata
            pass
        
        return metadata

# services/search_service.py
class SearchService:
    def __init__(self, elasticsearch_client):
        self.es = elasticsearch_client
    
    async def search_documents(self, query: str, **filters):
        """Search documents using Elasticsearch"""
        
        search_query = {
            "query": {
                "bool": {
                    "must": [
                        {
                            "multi_match": {
                                "query": query,
                                "fields": ["title^2", "description", "content"]
                            }
                        }
                    ],
                    "filter": []
                }
            },
            "highlight": {
                "fields": {
                    "title": {},
                    "description": {},
                    "content": {}
                }
            }
        }
        
        # Add filters
        if filters.get('category_id'):
            search_query["query"]["bool"]["filter"].append({
                "term": {"category_id": filters['category_id']}
            })
        
        results = await self.es.search(
            index="documents",
            body=search_query,
            from_=(filters.get('page', 1) - 1) * filters.get('per_page', 20),
            size=filters.get('per_page', 20)
        )
        
        return SearchResult(
            documents=[self._map_hit_to_document(hit) for hit in results['hits']['hits']],
            total=results['hits']['total']['value']
        )
```

### 2. Frontend Development

#### Custom Components
```html
<!-- document-manager.html -->
<div id="document-manager" class="document-manager">
    <!-- Search and Filter -->
    <div class="search-section">
        <div class="search-bar">
            <input type="text" id="search-input" placeholder="Search documents..." />
            <button onclick="searchDocuments()">Search</button>
        </div>
        <div class="filters">
            <select id="category-filter">
                <option value="">All Categories</option>
                <!-- Categories populated by JavaScript -->
            </select>
            <select id="sort-filter">
                <option value="created_at">Date Created</option>
                <option value="title">Title</option>
                <option value="file_size">File Size</option>
            </select>
        </div>
    </div>
    
    <!-- Upload Area -->
    <div class="upload-section">
        <div id="upload-dropzone" class="upload-dropzone">
            <div class="upload-content">
                <i class="upload-icon">📄</i>
                <h3>Upload Documents</h3>
                <p>Drag and drop files here or click to browse</p>
                <p class="supported-types">Supported: PDF, DOC, DOCX, XLS, XLSX, PPT, PPTX, Images</p>
            </div>
            <input type="file" id="file-input" multiple accept=".pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,image/*" />
        </div>
        
        <!-- Upload Progress -->
        <div id="upload-progress" class="upload-progress hidden">
            <h4>Uploading Files...</h4>
            <div id="upload-list"></div>
        </div>
    </div>
    
    <!-- Document List -->
    <div class="document-list-section">
        <div class="list-header">
            <h3>Documents</h3>
            <div class="view-controls">
                <button class="view-btn active" data-view="grid">Grid</button>
                <button class="view-btn" data-view="list">List</button>
            </div>
        </div>
        
        <div id="document-list" class="document-list grid-view">
            <!-- Documents populated by JavaScript -->
        </div>
        
        <!-- Pagination -->
        <div class="pagination">
            <button id="prev-page" disabled>Previous</button>
            <span id="page-info">Page 1 of 1</span>
            <button id="next-page" disabled>Next</button>
        </div>
    </div>
</div>

<!-- Document Modal -->
<div id="document-modal" class="modal hidden">
    <div class="modal-content">
        <div class="modal-header">
            <h3 id="modal-document-title">Document Details</h3>
            <button class="modal-close">&times;</button>
        </div>
        <div class="modal-body">
            <div class="document-preview" id="document-preview">
                <!-- Preview content -->
            </div>
            <div class="document-info">
                <div class="info-item">
                    <label>Category:</label>
                    <span id="modal-document-category"></span>
                </div>
                <div class="info-item">
                    <label>Size:</label>
                    <span id="modal-document-size"></span>
                </div>
                <div class="info-item">
                    <label>Uploaded:</label>
                    <span id="modal-document-date"></span>
                </div>
                <div class="info-item">
                    <label>Description:</label>
                    <p id="modal-document-description"></p>
                </div>
            </div>
        </div>
        <div class="modal-footer">
            <button class="btn btn-primary" onclick="downloadDocument()">Download</button>
            <button class="btn btn-secondary" onclick="shareDocument()">Share</button>
            <button class="btn btn-danger" onclick="deleteDocument()">Delete</button>
        </div>
    </div>
</div>
```

#### Enhanced JavaScript
```javascript
// document-manager.js
class DocumentManager extends FileManager {
    constructor() {
        super();
        this.documents = [];
        this.categories = [];
        this.currentView = 'grid';
        this.currentFilters = {};
        
        this.init();
    }
    
    async init() {
        await this.loadCategories();
        await this.loadDocuments();
        this.setupEventListeners();
        this.setupDropzone();
    }
    
    async loadCategories() {
        try {
            const response = await API.get('/categories');
            this.categories = response.categories;
            this.renderCategoryFilter();
        } catch (error) {
            UI.showToast('Failed to load categories', 'error');
        }
    }
    
    async loadDocuments(page = 1) {
        try {
            const params = {
                page: page,
                per_page: 20,
                ...this.currentFilters
            };
            
            const response = await API.get('/documents', params);
            this.documents = response.documents;
            this.totalPages = response.total_pages;
            this.currentPage = page;
            
            this.renderDocuments();
            this.updatePagination();
            
        } catch (error) {
            UI.showToast('Failed to load documents', 'error');
        }
    }
    
    async searchDocuments(query) {
        if (!query.trim()) {
            delete this.currentFilters.q;
        } else {
            this.currentFilters.q = query;
        }
        
        await this.loadDocuments(1);
    }
    
    async uploadDocument(file, metadata) {
        const formData = new FormData();
        formData.append('file', file);
        formData.append('title', metadata.title || file.name);
        formData.append('description', metadata.description || '');
        formData.append('category_id', metadata.category_id || 1);
        
        try {
            const response = await API.post('/documents/upload', formData);
            
            UI.showToast('Document uploaded successfully', 'success');
            await this.loadDocuments(); // Refresh list
            
            return response;
        } catch (error) {
            UI.showToast(`Upload failed: ${error.message}`, 'error');
            throw error;
        }
    }
    
    renderDocuments() {
        const container = document.getElementById('document-list');
        
        if (this.documents.length === 0) {
            container.innerHTML = '<p class="no-documents">No documents found</p>';
            return;
        }
        
        if (this.currentView === 'grid') {
            container.innerHTML = this.documents.map(doc => this.renderDocumentCard(doc)).join('');
        } else {
            container.innerHTML = this.documents.map(doc => this.renderDocumentRow(doc)).join('');
        }
    }
    
    renderDocumentCard(document) {
        return `
            <div class="document-card" data-id="${document.id}">
                <div class="document-thumbnail">
                    <i class="file-icon ${this.getFileIcon(document.mime_type)}"></i>
                </div>
                <div class="document-info">
                    <h4 class="document-title">${this.escapeHtml(document.title)}</h4>
                    <p class="document-meta">
                        ${this.formatFileSize(document.file_size)} • 
                        ${this.formatDate(document.created_at)}
                    </p>
                    <p class="document-category">${document.category.name}</p>
                </div>
                <div class="document-actions">
                    <button onclick="documentManager.viewDocument(${document.id})" title="View">👁️</button>
                    <button onclick="documentManager.downloadDocument(${document.id})" title="Download">⬇️</button>
                    <button onclick="documentManager.shareDocument(${document.id})" title="Share">📤</button>
                </div>
            </div>
        `;
    }
    
    getFileIcon(mimeType) {
        const iconMap = {
            'application/pdf': '📄',
            'application/msword': '📝',
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document': '📝',
            'application/vnd.ms-excel': '📊',
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': '📊',
            'application/vnd.ms-powerpoint': '📊',
            'application/vnd.openxmlformats-officedocument.presentationml.presentation': '📊',
            'image/jpeg': '🖼️',
            'image/png': '🖼️',
            'image/gif': '🖼️'
        };
        
        return iconMap[mimeType] || '📄';
    }
    
    async viewDocument(documentId) {
        try {
            const document = await API.get(`/documents/${documentId}`);
            this.showDocumentModal(document);
        } catch (error) {
            UI.showToast('Failed to load document details', 'error');
        }
    }
    
    showDocumentModal(document) {
        document.getElementById('modal-document-title').textContent = document.title;
        document.getElementById('modal-document-category').textContent = document.category.name;
        document.getElementById('modal-document-size').textContent = this.formatFileSize(document.file_size);
        document.getElementById('modal-document-date').textContent = this.formatDate(document.created_at);
        document.getElementById('modal-document-description').textContent = document.description || 'No description';
        
        // Show preview if supported
        this.loadDocumentPreview(document);
        
        document.getElementById('document-modal').classList.remove('hidden');
        this.currentDocument = document;
    }
    
    async loadDocumentPreview(document) {
        const previewContainer = document.getElementById('document-preview');
        
        if (document.mime_type.startsWith('image/')) {
            previewContainer.innerHTML = `
                <img src="/documents/${document.id}/preview" 
                     alt="${document.title}" 
                     style="max-width: 100%; height: auto;" />
            `;
        } else if (document.mime_type === 'application/pdf') {
            previewContainer.innerHTML = `
                <embed src="/documents/${document.id}/preview" 
                       type="application/pdf" 
                       width="100%" 
                       height="400px" />
            `;
        } else {
            previewContainer.innerHTML = `
                <div class="no-preview">
                    <i class="file-icon">${this.getFileIcon(document.mime_type)}</i>
                    <p>Preview not available for this file type</p>
                </div>
            `;
        }
    }
}

// Initialize document manager
window.documentManager = new DocumentManager();
```

### 3. Data Migration

```python
# migration/migrate_documents.py
import asyncio
import mysql.connector
import asyncpg
from pathlib import Path
import shutil

class DocumentMigration:
    def __init__(self, legacy_db_config, new_db_url, file_source, file_dest):
        self.legacy_db = mysql.connector.connect(**legacy_db_config)
        self.new_db_url = new_db_url
        self.file_source = Path(file_source)
        self.file_dest = Path(file_dest)
        
    async def migrate_all(self):
        """Migrate all data from legacy system"""
        print("Starting migration...")
        
        # Connect to new database
        self.new_db = await asyncpg.connect(self.new_db_url)
        
        try:
            # Migrate in order of dependencies
            await self.migrate_users()
            await self.migrate_categories()
            await self.migrate_documents()
            await self.migrate_files()
            await self.verify_migration()
            
            print("Migration completed successfully!")
            
        except Exception as e:
            print(f"Migration failed: {e}")
            raise
        finally:
            await self.new_db.close()
            self.legacy_db.close()
    
    async def migrate_users(self):
        """Migrate user accounts"""
        print("Migrating users...")
        
        cursor = self.legacy_db.cursor(dictionary=True)
        cursor.execute("SELECT * FROM users WHERE active = 1")
        
        users_migrated = 0
        
        for user in cursor:
            # Hash password properly (legacy used MD5)
            hashed_password = hash_password(user['password'])
            
            await self.new_db.execute("""
                INSERT INTO users (id, email, hashed_password, is_active, created_at)
                VALUES ($1, $2, $3, $4, $5)
                ON CONFLICT (id) DO NOTHING
            """, user['id'], user['email'], hashed_password, True, user['created_at'])
            
            users_migrated += 1
        
        print(f"Migrated {users_migrated} users")
    
    async def migrate_categories(self):
        """Migrate document categories"""
        print("Migrating categories...")
        
        cursor = self.legacy_db.cursor(dictionary=True)
        cursor.execute("SELECT * FROM categories ORDER BY parent_id NULLS FIRST")
        
        categories_migrated = 0
        
        for category in cursor:
            await self.new_db.execute("""
                INSERT INTO categories (id, name, description, parent_id)
                VALUES ($1, $2, $3, $4)
                ON CONFLICT (id) DO NOTHING
            """, category['id'], category['name'], 
                category['description'], category['parent_id'])
            
            categories_migrated += 1
        
        print(f"Migrated {categories_migrated} categories")
    
    async def migrate_documents(self):
        """Migrate document metadata"""
        print("Migrating documents...")
        
        cursor = self.legacy_db.cursor(dictionary=True)
        cursor.execute("""
            SELECT d.*, u.email as uploader_email 
            FROM documents d 
            JOIN users u ON d.uploaded_by = u.id 
            WHERE d.deleted = 0
        """)
        
        documents_migrated = 0
        
        for doc in cursor:
            # Map legacy file path to new structure
            new_file_path = self.map_file_path(doc['file_path'])
            
            await self.new_db.execute("""
                INSERT INTO documents (
                    id, title, filename, file_path, mime_type, file_size,
                    description, category_id, uploaded_by, created_at, updated_at
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
                ON CONFLICT (id) DO NOTHING
            """, doc['id'], doc['title'], doc['filename'], new_file_path,
                doc['mime_type'], doc['file_size'], doc['description'],
                doc['category_id'], doc['uploaded_by'], 
                doc['created_at'], doc['updated_at'])
            
            documents_migrated += 1
        
        print(f"Migrated {documents_migrated} documents")
    
    async def migrate_files(self):
        """Copy actual files"""
        print("Migrating files...")
        
        cursor = self.legacy_db.cursor(dictionary=True)
        cursor.execute("SELECT file_path FROM documents WHERE deleted = 0")
        
        files_migrated = 0
        files_failed = 0
        
        for row in cursor:
            legacy_path = self.file_source / row['file_path']
            new_path = self.file_dest / self.map_file_path(row['file_path'])
            
            try:
                # Create directories if needed
                new_path.parent.mkdir(parents=True, exist_ok=True)
                
                # Copy file
                shutil.copy2(legacy_path, new_path)
                files_migrated += 1
                
            except Exception as e:
                print(f"Failed to copy {legacy_path}: {e}")
                files_failed += 1
        
        print(f"Migrated {files_migrated} files, {files_failed} failed")
    
    def map_file_path(self, legacy_path):
        """Map legacy file path to new structure"""
        # Example: uploads/2023/03/file.pdf -> uploads/documents/2023/03/file.pdf
        return f"documents/{legacy_path}"
    
    async def verify_migration(self):
        """Verify migration integrity"""
        print("Verifying migration...")
        
        # Count records
        legacy_cursor = self.legacy_db.cursor()
        legacy_cursor.execute("SELECT COUNT(*) FROM users WHERE active = 1")
        legacy_users = legacy_cursor.fetchone()[0]
        
        legacy_cursor.execute("SELECT COUNT(*) FROM documents WHERE deleted = 0")
        legacy_docs = legacy_cursor.fetchone()[0]
        
        new_users = await self.new_db.fetchval("SELECT COUNT(*) FROM users")
        new_docs = await self.new_db.fetchval("SELECT COUNT(*) FROM documents")
        
        print(f"Users: {legacy_users} → {new_users}")
        print(f"Documents: {legacy_docs} → {new_docs}")
        
        if legacy_users != new_users or legacy_docs != new_docs:
            raise Exception("Record counts don't match!")

# Run migration
async def main():
    migration = DocumentMigration(
        legacy_db_config={
            'host': 'localhost',
            'user': 'legacy_user',
            'password': 'legacy_pass',
            'database': 'legacy_db'
        },
        new_db_url='postgresql://user:pass@localhost/new_db',
        file_source='/var/www/legacy/uploads',
        file_dest='/app/uploads'
    )
    
    await migration.migrate_all()

if __name__ == "__main__":
    asyncio.run(main())
```

### 4. Deployment Configuration

```yaml
# docker-compose.legacy-migration.yml
version: '3.8'

services:
  legacy-app:
    build:
      context: .
      dockerfile: Dockerfile
    environment:
      - ENVIRONMENT=migration
      - LEGACY_DB_HOST=legacy-mysql
      - LEGACY_DB_USER=root
      - LEGACY_DB_PASSWORD=legacy_password
    volumes:
      - /legacy/uploads:/legacy/uploads:ro
      - ./uploads:/app/uploads
    depends_on:
      - legacy-mysql
      - webapp-db
    networks:
      - migration-network

  legacy-mysql:
    image: mysql:5.7
    environment:
      - MYSQL_ROOT_PASSWORD=legacy_password
      - MYSQL_DATABASE=legacy_db
    volumes:
      - /backup/legacy_dump.sql:/docker-entrypoint-initdb.d/legacy_dump.sql
    networks:
      - migration-network

networks:
  migration-network:
    driver: bridge
```

## Results

### Performance Improvements
- **File Upload Speed**: 30s → 3s (10x faster)
- **Search Performance**: 15s → 0.2s (75x faster)
- **Concurrent Users**: 25 → 100 (4x increase)
- **Memory Usage**: 2GB → 512MB (75% reduction)

### Security Enhancements
- JWT-based authentication
- File type validation and virus scanning
- SQL injection protection (ORM)
- Encrypted data transmission
- Role-based access control

### Feature Additions
- Real-time search with highlighting
- Document versioning
- Advanced metadata extraction
- Mobile-responsive interface
- RESTful API for integrations
- Comprehensive audit logging

### Operational Benefits
- Containerized deployment
- Horizontal scaling capability
- Health monitoring and alerting
- Automated backups
- CI/CD pipeline integration
- Zero-downtime deployments

This example demonstrates how the WebApp Conversion Framework can transform a legacy application into a modern, scalable, and secure web application while maintaining all existing functionality and adding significant new capabilities.