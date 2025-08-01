#!/bin/bash
# Docker Container Tests
# Comprehensive testing for container build and deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test configuration
IMAGE_NAME="webapp-framework"
CONTAINER_NAME="webapp-test"
TEST_PORT="8001"
TIMEOUT=60

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up test containers and images..."
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
    docker rmi "$IMAGE_NAME:test" 2>/dev/null || true
}

# Trap cleanup on exit
trap cleanup EXIT

# Test 1: Docker Build
test_docker_build() {
    log_info "Testing Docker build..."
    
    if docker build -t "$IMAGE_NAME:test" .; then
        log_info "✅ Docker build successful"
    else
        log_error "❌ Docker build failed"
        exit 1
    fi
}

# Test 2: Container Startup
test_container_startup() {
    log_info "Testing container startup..."
    
    # Start container
    docker run -d \
        --name "$CONTAINER_NAME" \
        -p "$TEST_PORT:8000" \
        -e DEBUG=true \
        -e DATABASE_URL=sqlite:///./test.db \
        "$IMAGE_NAME:test"
    
    # Wait for container to be healthy
    local count=0
    while [ $count -lt $TIMEOUT ]; do
        if docker ps | grep -q "$CONTAINER_NAME"; then
            sleep 2
            count=$((count + 2))
            
            # Check if the application is responding
            if curl -f "http://localhost:$TEST_PORT/health" >/dev/null 2>&1; then
                log_info "✅ Container started successfully"
                return 0
            fi
        else
            log_error "❌ Container failed to start"
            docker logs "$CONTAINER_NAME"
            exit 1
        fi
    done
    
    log_error "❌ Container startup timeout"
    docker logs "$CONTAINER_NAME"
    exit 1
}

# Test 3: Health Check
test_health_endpoint() {
    log_info "Testing health endpoint..."
    
    local response
    response=$(curl -s "http://localhost:$TEST_PORT/health")
    
    if echo "$response" | grep -q '"status":"healthy"'; then
        log_info "✅ Health endpoint working"
    else
        log_error "❌ Health endpoint failed"
        echo "Response: $response"
        exit 1
    fi
}

# Test 4: API Endpoints
test_api_endpoints() {
    log_info "Testing API endpoints..."
    
    # Test endpoints that should be accessible without auth
    local endpoints=(
        "/health"
        "/api/docs"
        "/api/redoc"
    )
    
    for endpoint in "${endpoints[@]}"; do
        local status_code
        status_code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$TEST_PORT$endpoint")
        
        if [ "$status_code" = "200" ]; then
            log_info "✅ Endpoint $endpoint: $status_code"
        else
            log_warn "⚠️  Endpoint $endpoint: $status_code"
        fi
    done
}

# Test 5: Container Resource Usage
test_resource_usage() {
    log_info "Testing container resource usage..."
    
    local stats
    stats=$(docker stats "$CONTAINER_NAME" --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}")
    
    log_info "Resource usage:"
    echo "$stats"
    
    # Check if memory usage is reasonable (less than 1GB)
    local mem_usage
    mem_usage=$(docker stats "$CONTAINER_NAME" --no-stream --format "{{.MemUsage}}" | cut -d'/' -f1 | sed 's/[^0-9.]//g')
    
    if (( $(echo "$mem_usage < 1000" | bc -l) )); then
        log_info "✅ Memory usage within acceptable limits"
    else
        log_warn "⚠️  High memory usage: ${mem_usage}MB"
    fi
}

# Test 6: File Upload Test
test_file_upload() {
    log_info "Testing file upload functionality..."
    
    # Create test file
    echo "Test file content for upload" > test_upload.txt
    
    # Test file upload (should fail without auth, but endpoint should exist)
    local status_code
    status_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST \
        -F "file=@test_upload.txt" \
        "http://localhost:$TEST_PORT/files/upload")
    
    if [ "$status_code" = "401" ] || [ "$status_code" = "422" ]; then
        log_info "✅ File upload endpoint accessible (auth required as expected)"
    else
        log_warn "⚠️  Unexpected file upload response: $status_code"
    fi
    
    rm -f test_upload.txt
}

# Test 7: Security Headers
test_security_headers() {
    log_info "Testing security headers..."
    
    local headers
    headers=$(curl -s -I "http://localhost:$TEST_PORT/health")
    
    # Check for security headers (when served through reverse proxy)
    if echo "$headers" | grep -qi "x-content-type-options"; then
        log_info "✅ X-Content-Type-Options header present"
    else
        log_warn "⚠️  X-Content-Type-Options header missing"
    fi
}

# Test 8: Container Logs
test_container_logs() {
    log_info "Testing container logs..."
    
    local logs
    logs=$(docker logs "$CONTAINER_NAME" 2>&1)
    
    if echo "$logs" | grep -q "Started server process"; then
        log_info "✅ Application started successfully"
    else
        log_warn "⚠️  Application startup not confirmed in logs"
    fi
    
    # Check for errors in logs
    if echo "$logs" | grep -qi "error\|exception\|traceback"; then
        log_warn "⚠️  Errors found in container logs:"
        echo "$logs" | grep -i "error\|exception\|traceback"
    else
        log_info "✅ No errors found in container logs"
    fi
}

# Test 9: Container Stop/Restart
test_container_lifecycle() {
    log_info "Testing container lifecycle..."
    
    # Stop container
    docker stop "$CONTAINER_NAME"
    
    # Start container again
    docker start "$CONTAINER_NAME"
    
    # Wait for restart
    sleep 5
    
    # Test health again
    if curl -f "http://localhost:$TEST_PORT/health" >/dev/null 2>&1; then
        log_info "✅ Container restart successful"
    else
        log_error "❌ Container restart failed"
        exit 1
    fi
}

# Test 10: Multi-stage Build Verification
test_multistage_build() {
    log_info "Testing multi-stage build targets..."
    
    # Test development target
    if docker build --target development -t "$IMAGE_NAME:dev" . >/dev/null 2>&1; then
        log_info "✅ Development stage build successful"
    else
        log_warn "⚠️  Development stage build failed"
    fi
    
    # Test production target
    if docker build --target production -t "$IMAGE_NAME:prod" . >/dev/null 2>&1; then
        log_info "✅ Production stage build successful"
    else
        log_error "❌ Production stage build failed"
        exit 1
    fi
    
    # Cleanup additional images
    docker rmi "$IMAGE_NAME:dev" 2>/dev/null || true
    docker rmi "$IMAGE_NAME:prod" 2>/dev/null || true
}

# Performance Test
test_performance() {
    log_info "Running basic performance test..."
    
    # Simple load test with curl
    local start_time end_time duration
    start_time=$(date +%s.%N)
    
    for i in {1..10}; do
        curl -s "http://localhost:$TEST_PORT/health" >/dev/null
    done
    
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc -l)
    
    log_info "✅ 10 health check requests completed in ${duration} seconds"
}

# Main test execution
main() {
    log_info "Starting Docker container tests..."
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    # Check if curl is available
    if ! command -v curl &> /dev/null; then
        log_error "curl is not installed or not in PATH"
        exit 1
    fi
    
    # Run tests
    test_docker_build
    test_multistage_build
    test_container_startup
    test_health_endpoint
    test_api_endpoints
    test_resource_usage
    test_file_upload
    test_security_headers
    test_container_logs
    test_container_lifecycle
    test_performance
    
    log_info "🎉 All Docker tests completed successfully!"
}

# Run main function
main "$@"