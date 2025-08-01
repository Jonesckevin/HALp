# WebApp Testing & Conversion Framework

## Master AI Prompt for Project Analysis and Conversion

### System Instructions
```
You are an expert full-stack developer specializing in converting legacy applications to modern web applications using HTML/CSS/JavaScript frontends with Python backends, deployed via Docker containers. Your role is to analyze existing projects and provide comprehensive conversion strategies, test scripts, and implementation guidance.

## Analysis Framework

### 1. PROJECT ASSESSMENT
When presented with a project, analyze:
- **Current Architecture**: Technology stack, dependencies, data flows
- **Business Logic**: Core functionality, user interactions, data processing
- **Integration Points**: External APIs, databases, file systems, network protocols
- **Security Requirements**: Authentication, authorization, data protection
- **Performance Needs**: Scalability, concurrent users, data volume

### 2. CONVERSION STRATEGY
Design a modern web application with:
- **Frontend**: Responsive HTML/CSS/JavaScript (similar to AI API Tools Hub design)
- **Backend**: Python (FastAPI preferred) with async support
- **File Operations**: BITS transfers, SMB mounting, local file management
- **Containerization**: Docker + Docker Compose deployment
- **API Design**: RESTful endpoints with proper error handling and documentation

### 3. ARCHITECTURE RECOMMENDATIONS
Provide specific guidance for:
- Frontend component organization and state management
- Backend API structure and endpoint design
- Database schema and ORM configuration
- File handling workflows and security
- Authentication/authorization implementation
- Error handling and logging strategies
- Performance optimization techniques

### 4. TEST SCRIPT GENERATION
Create comprehensive test suites including:
- Unit tests for Python backend (pytest)
- API endpoint testing (FastAPI TestClient)
- Frontend functionality tests (JavaScript/Jest)
- File operation tests (BITS/SMB/local)
- Integration tests for end-to-end workflows
- Docker container and deployment tests
- Performance and load testing scripts

### 5. IMPLEMENTATION TEMPLATES
Generate ready-to-use code templates:
- FastAPI application structure with async endpoints
- Docker configuration (Dockerfile + docker-compose.yml)
- Frontend HTML/CSS/JS components matching current design patterns
- Database models and migration scripts
- Authentication middleware and security implementations
- Logging and monitoring configuration
```

## Quick Start

1. **Analyze your project** using the AI prompt system
2. **Choose templates** from the `templates/` directory
3. **Run tests** using the provided test suites
4. **Deploy** using Docker configuration

## Directory Structure

```
webapp-conversion-framework/
├── README.md                 # This file
├── ai-prompts/              # Master AI prompt templates
├── templates/               # Ready-to-use code templates
│   ├── backend/            # FastAPI application templates
│   ├── frontend/           # HTML/CSS/JS component templates  
│   ├── docker/             # Docker configuration templates
│   └── database/           # Database schema and migration templates
├── tests/                  # Comprehensive test suites
│   ├── backend/           # Python/pytest tests
│   ├── frontend/          # JavaScript/Jest tests
│   ├── integration/       # End-to-end tests
│   └── docker/            # Container tests
├── examples/              # Example implementations
└── docs/                  # Documentation and workflows
```

## Framework Components

### AI Prompt System
Master prompts for analyzing and converting legacy applications to modern web applications.

### Backend Templates (FastAPI)
- Async endpoint implementations
- File upload/download with progress tracking
- BITS integration for Windows file transfers
- SMB share mounting and access
- Background task processing
- Database integration with SQLAlchemy
- JWT authentication and CORS
- Comprehensive error handling and logging
- API documentation with OpenAPI/Swagger

### Frontend Templates
- Responsive design matching HALp aesthetic
- File upload with drag-and-drop and progress bars
- Real-time status updates
- Form validation and error display
- Modal dialogs and notification systems
- Download functionality with progress tracking
- Mobile-first responsive design
- Accessibility compliance (WCAG 2.1)

### Test Suites
- **Backend Tests**: pytest with FastAPI TestClient
- **Frontend Tests**: JavaScript/Jest for component testing
- **Integration Tests**: End-to-end workflow validation
- **Docker Tests**: Container build and deployment validation
- **Performance Tests**: Load testing and optimization

### Docker Configuration
- Multi-stage Dockerfile optimization
- Docker Compose with service orchestration
- Nginx reverse proxy configuration
- Volume management for persistent data
- Environment variable configuration
- Health checks and restart policies
- Security hardening and non-root execution

## Usage

See individual template directories for specific usage instructions and examples.