# Implementation Workflow Guide

## Phase 1: Analysis and Planning

### 1.1 Project Assessment
Use the master AI prompt to analyze your legacy application:

```
[Use the master prompt from ai-prompts/master-prompt.md]

## Current Project Context
- Legacy technology: PHP with MySQL
- Current functionality: Document management system with file uploads
- Integration requirements: Windows file shares, email notifications
- User base: 50 concurrent users, 10GB storage

## Conversion Requirements
- Target performance: <2s response times, 100 concurrent users
- Security needs: LDAP authentication, file encryption
- File operations: Large file uploads (1GB+), virus scanning
- Deployment environment: On-premise Docker containers
```

### 1.2 Technology Assessment
Evaluate current system:

1. **Codebase Analysis**
   - Map existing functionality
   - Identify reusable business logic
   - Document integration points
   - Assess database schema

2. **Performance Baseline**
   - Current response times
   - Resource utilization
   - Bottlenecks and limitations
   - Scalability constraints

3. **Security Review**
   - Authentication mechanisms
   - Data protection measures
   - Vulnerability assessment
   - Compliance requirements

### 1.3 Conversion Strategy
Based on assessment, choose approach:

- **Full Rewrite**: Complete modernization
- **Gradual Migration**: Phased replacement
- **Hybrid Approach**: Integrate with existing systems

## Phase 2: Backend Development

### 2.1 Setup Development Environment

```bash
# Clone framework templates
cp -r templates/backend/ my-project/backend/

# Install dependencies
cd my-project/backend/
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env with your settings

# Initialize database
python -c "from database import init_db; import asyncio; asyncio.run(init_db())"
```

### 2.2 Customize Backend Templates

1. **Update Configuration** (`config.py`)
   ```python
   # Add your specific settings
   class ProductionSettings(Settings):
       DATABASE_URL: str = "postgresql://..."
       LDAP_SERVER: str = "ldap://company.com"
       VIRUS_SCANNER_API: str = "http://scanner.local"
   ```

2. **Extend Database Models** (`database.py`)
   ```python
   # Add your domain models
   class Document(Base):
       __tablename__ = "documents"
       
       id = Column(Integer, primary_key=True)
       title = Column(String, nullable=False)
       category_id = Column(Integer, ForeignKey("categories.id"))
       # ... additional fields
   ```

3. **Implement Business Logic**
   - Create service classes for business operations
   - Add validation rules
   - Implement custom workflows

### 2.3 Add Custom Endpoints

```python
# In main.py or separate router files
@app.post("/documents/upload")
async def upload_document(
    file: UploadFile = File(...),
    title: str = Form(...),
    category_id: int = Form(...),
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Custom document upload logic
    document = await document_service.create_document(
        file, title, category_id, current_user.id, db
    )
    return document
```

### 2.4 Integration Implementation

1. **LDAP Authentication**
   ```python
   # auth.py
   async def authenticate_ldap(username: str, password: str):
       # Implement LDAP authentication
       pass
   ```

2. **File Operations**
   ```python
   # file_operations.py
   class CustomFileManager(FileManager):
       async def process_file(self, file_record, db):
           # Add virus scanning
           # Add file encryption
           # Add metadata extraction
           pass
   ```

3. **External Integrations**
   - Email notifications
   - Document indexing
   - Backup systems

## Phase 3: Frontend Development

### 3.1 Setup Frontend

```bash
# Copy frontend templates
cp -r templates/frontend/ my-project/frontend/

# Customize for your needs
cd my-project/frontend/
```

### 3.2 Customize UI Components

1. **Update Branding** (`css/styles.css`)
   ```css
   :root {
     --primary-color: #your-brand-color;
     --logo-url: url('/static/images/your-logo.png');
   }
   ```

2. **Add Custom Components**
   ```html
   <!-- Document viewer component -->
   <div class="document-viewer">
     <div class="document-preview" id="doc-preview"></div>
     <div class="document-actions">
       <button onclick="downloadDocument()">Download</button>
       <button onclick="shareDocument()">Share</button>
     </div>
   </div>
   ```

3. **Implement Custom JavaScript**
   ```javascript
   // documents.js
   class DocumentManager {
     async uploadDocument(file, metadata) {
       // Custom upload logic
     }
     
     async searchDocuments(query) {
       // Custom search logic
     }
   }
   ```

### 3.3 Responsive Design

Ensure your customizations maintain responsiveness:

```css
@media (max-width: 768px) {
  .document-viewer {
    flex-direction: column;
  }
  
  .document-actions {
    margin-top: 1rem;
  }
}
```

## Phase 4: Testing Implementation

### 4.1 Backend Testing

```bash
# Run backend tests
cd backend/
python -m pytest tests/ -v --cov=.

# Run specific test categories
python -m pytest tests/test_api.py -v
python -m pytest tests/test_integration.py -v
```

### 4.2 Frontend Testing

```bash
# Install testing dependencies
npm install --save-dev jest jsdom

# Run frontend tests
npm test

# Run with coverage
npm run test:coverage
```

### 4.3 Integration Testing

```bash
# Run end-to-end tests
python -m pytest tests/integration/ -v

# Run performance tests
python -m pytest tests/performance/ -v
```

### 4.4 Custom Test Implementation

```python
# tests/test_documents.py
class TestDocumentWorkflow:
    def test_document_upload_and_search(self, authenticated_client):
        # Upload document
        response = authenticated_client.post(
            "/documents/upload",
            files={"file": ("test.pdf", file_content, "application/pdf")},
            data={"title": "Test Document", "category_id": 1}
        )
        assert response.status_code == 200
        
        # Search for document
        search_response = authenticated_client.get(
            "/documents/search?q=Test Document"
        )
        assert len(search_response.json()["results"]) >= 1
```

## Phase 5: Containerization

### 5.1 Docker Configuration

```bash
# Copy Docker templates
cp -r templates/docker/ my-project/

# Customize for your application
cd my-project/
```

### 5.2 Custom Dockerfile

```dockerfile
# Add custom dependencies
RUN apt-get update && apt-get install -y \
    your-custom-packages \
    && rm -rf /var/lib/apt/lists/*

# Add custom configuration
COPY config/your-config.conf /etc/your-app/

# Custom startup script
COPY scripts/startup.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/startup.sh
```

### 5.3 Docker Compose Customization

```yaml
# docker-compose.yml
services:
  your-app:
    build: .
    environment:
      - LDAP_SERVER=${LDAP_SERVER}
      - VIRUS_SCANNER_URL=${VIRUS_SCANNER_URL}
    volumes:
      - your-data:/app/data
      - /company/shares:/app/shares:ro
    
  your-database:
    image: postgres:15
    environment:
      - POSTGRES_DB=your_app_db
    volumes:
      - your-db-data:/var/lib/postgresql/data
```

### 5.4 Environment Configuration

```bash
# .env
LDAP_SERVER=ldap://company.com
VIRUS_SCANNER_URL=http://scanner.local
COMPANY_SHARE_PATH=/company/shares
EMAIL_SMTP_SERVER=smtp.company.com
```

## Phase 6: Deployment

### 6.1 Production Deployment

```bash
# Build and deploy
docker-compose -f docker-compose.prod.yml up -d

# Verify deployment
docker-compose ps
docker-compose logs
```

### 6.2 Health Monitoring

```bash
# Test all endpoints
./tests/docker/test_docker.sh

# Monitor logs
docker-compose logs -f your-app
```

### 6.3 Performance Tuning

1. **Database Optimization**
   ```sql
   -- Add indexes for your queries
   CREATE INDEX idx_documents_category ON documents(category_id);
   CREATE INDEX idx_documents_search ON documents USING gin(to_tsvector('english', title || ' ' || content));
   ```

2. **Caching Strategy**
   ```python
   # Add Redis caching
   @cache(expire=3600)
   async def get_popular_documents():
       # Expensive query
       pass
   ```

3. **File Storage Optimization**
   ```python
   # Implement file compression
   # Add CDN integration
   # Use object storage
   ```

## Phase 7: Migration Strategy

### 7.1 Data Migration

```python
# migration_script.py
async def migrate_documents():
    # Read from legacy system
    legacy_docs = await fetch_legacy_documents()
    
    # Transform data
    for doc in legacy_docs:
        new_doc = transform_document(doc)
        await create_document(new_doc)
    
    # Verify migration
    await verify_migration()
```

### 7.2 Gradual Rollout

1. **Parallel Operation**: Run both systems
2. **Feature Flagging**: Enable features gradually
3. **User Migration**: Migrate users in batches
4. **Data Synchronization**: Keep systems in sync

### 7.3 Rollback Plan

```bash
# Rollback procedures
docker-compose down
docker-compose -f docker-compose.legacy.yml up -d

# Restore data if needed
pg_restore backup_before_migration.sql
```

## Phase 8: Monitoring and Maintenance

### 8.1 Monitoring Setup

```yaml
# monitoring/docker-compose.yml
services:
  prometheus:
    image: prom/prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
  
  grafana:
    image: grafana/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
```

### 8.2 Log Management

```python
# logging_config.py
import logging
from pythonjsonlogger import jsonlogger

formatter = jsonlogger.JsonFormatter()
handler = logging.StreamHandler()
handler.setFormatter(formatter)

logger = logging.getLogger()
logger.addHandler(handler)
logger.setLevel(logging.INFO)
```

### 8.3 Backup Strategy

```bash
# backup_script.sh
#!/bin/bash
pg_dump $DATABASE_URL > backup_$(date +%Y%m%d).sql
tar czf files_backup_$(date +%Y%m%d).tar.gz /app/uploads
```

## Troubleshooting Guide

### Common Issues

1. **Database Connection Problems**
   ```bash
   # Check database connectivity
   docker-compose exec webapp-backend python -c "from database import engine; print(engine)"
   ```

2. **File Upload Issues**
   ```bash
   # Check file permissions
   docker-compose exec webapp-backend ls -la /app/uploads
   ```

3. **Performance Issues**
   ```bash
   # Monitor resource usage
   docker stats
   
   # Check slow queries
   docker-compose logs webapp-db | grep "slow query"
   ```

### Best Practices

1. **Security**
   - Regular security updates
   - Encrypted data transmission
   - Secure file handling
   - Authentication monitoring

2. **Performance**
   - Database query optimization
   - Caching implementation
   - CDN usage
   - Resource monitoring

3. **Maintenance**
   - Regular backups
   - Log rotation
   - Health checks
   - Documentation updates