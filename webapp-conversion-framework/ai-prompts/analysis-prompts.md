# Analysis Prompt Templates

## 1. Legacy System Analysis Prompt

```
Analyze the following legacy system and provide a comprehensive assessment:

### System Information
- **Technology Stack**: [Current technologies used]
- **Architecture**: [Monolithic, microservices, etc.]
- **Database**: [Type, schema complexity]
- **User Interface**: [Desktop, web, mobile]
- **Integration Points**: [External systems, APIs]

### Assessment Criteria
1. **Complexity Analysis**
   - Code complexity and maintainability
   - Dependencies and coupling
   - Performance bottlenecks
   - Security vulnerabilities

2. **Business Logic Evaluation**
   - Core functionality mapping
   - User workflow analysis
   - Data processing requirements
   - Reporting and analytics needs

3. **Technical Debt Assessment**
   - Outdated frameworks/libraries
   - Scalability limitations
   - Maintenance overhead
   - Documentation gaps

### Output Requirements
Provide:
1. Risk assessment matrix
2. Conversion complexity rating (1-10)
3. Recommended conversion approach
4. Timeline estimation
5. Resource requirements
```

## 2. Requirements Gathering Prompt

```
Based on the legacy system analysis, define requirements for the modern web application:

### Functional Requirements
- **Core Features**: [List essential functionality]
- **User Roles**: [Authentication and authorization needs]
- **Data Operations**: [CRUD, reporting, analytics]
- **File Handling**: [Upload, download, processing]
- **Integration**: [External APIs, databases]

### Non-Functional Requirements
- **Performance**: [Response times, throughput]
- **Scalability**: [Concurrent users, data volume]
- **Security**: [Authentication, data protection]
- **Availability**: [Uptime requirements, disaster recovery]
- **Compliance**: [Regulatory requirements]

### Technical Requirements
- **Frontend**: [Responsive design, accessibility]
- **Backend**: [API design, async processing]
- **Database**: [ACID compliance, performance]
- **Infrastructure**: [Cloud, containerization]
- **Monitoring**: [Logging, metrics, alerting]

### Output Format
Generate:
1. User stories with acceptance criteria
2. Technical specifications
3. API contract definitions
4. Database schema requirements
5. Infrastructure requirements
```

## 3. Architecture Design Prompt

```
Design a modern web application architecture based on the requirements:

### Architecture Principles
- **Separation of Concerns**: Clear boundaries between layers
- **Scalability**: Horizontal and vertical scaling capabilities
- **Security**: Defense in depth, least privilege
- **Maintainability**: Clean code, documentation, testing
- **Performance**: Optimized for speed and efficiency

### Design Patterns
- **Frontend**: Component-based architecture
- **Backend**: RESTful API with async processing
- **Database**: Repository pattern with ORM
- **Security**: JWT authentication, RBAC
- **Caching**: Redis for session and data caching

### Technology Selection
- **Frontend**: HTML5, CSS3, Vanilla JavaScript
- **Backend**: Python FastAPI with async/await
- **Database**: PostgreSQL with SQLAlchemy
- **Containerization**: Docker with multi-stage builds
- **Orchestration**: Docker Compose
- **Reverse Proxy**: Nginx

### Output Requirements
Provide:
1. System architecture diagram
2. Component interaction flows
3. Database schema design
4. API endpoint specifications
5. Security architecture
6. Deployment architecture
```