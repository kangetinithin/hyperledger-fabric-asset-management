#!/bin/bash

# Quick Status Check Script for Hyperledger Fabric Asset Management System

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[CHECK]${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

echo "=========================================="
echo "Hyperledger Fabric Asset Management System"
echo "Quick Status Check"
echo "=========================================="
echo ""

# Check Docker
print_status "Checking Docker..."
if docker info >/dev/null 2>&1; then
    print_success "Docker is running"
else
    print_error "Docker is not running"
    exit 1
fi

# Check containers
print_status "Checking Fabric containers..."
ORDERER_STATUS=$(docker ps --filter "name=orderer.example.com" --format "{{.Status}}" 2>/dev/null)
PEER1_STATUS=$(docker ps --filter "name=peer0.org1.example.com" --format "{{.Status}}" 2>/dev/null)
PEER2_STATUS=$(docker ps --filter "name=peer0.org2.example.com" --format "{{.Status}}" 2>/dev/null)
API_STATUS=$(docker ps --filter "name=api-gateway" --format "{{.Status}}" 2>/dev/null)

if [ -n "$ORDERER_STATUS" ]; then
    print_success "Orderer: $ORDERER_STATUS"
else
    print_error "Orderer: Not running"
fi

if [ -n "$PEER1_STATUS" ]; then
    print_success "Peer0 Org1: $PEER1_STATUS"
else
    print_error "Peer0 Org1: Not running"
fi

if [ -n "$PEER2_STATUS" ]; then
    print_success "Peer0 Org2: $PEER2_STATUS"
else
    print_error "Peer0 Org2: Not running"
fi

if [ -n "$API_STATUS" ]; then
    print_success "API Gateway: $API_STATUS"
else
    print_error "API Gateway: Not running"
fi

# Check API health
print_status "Checking API Gateway health..."
if curl -s http://localhost:8080/health >/dev/null 2>&1; then
    HEALTH_RESPONSE=$(curl -s http://localhost:8080/health)
    print_success "API Gateway is healthy: $HEALTH_RESPONSE"
    
    # Quick API test
    print_status "Testing API endpoint..."
    if curl -s http://localhost:8080/api/v1/assets >/dev/null 2>&1; then
        print_success "API endpoints are responding"
    else
        print_warning "API endpoints may not be fully ready"
    fi
else
    print_error "API Gateway is not responding on http://localhost:8080"
fi

# Check ports
print_status "Checking port availability..."
PORTS=(7050 7051 9051 8080)
for port in "${PORTS[@]}"; do
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        print_success "Port $port is in use (service running)"
    else
        print_warning "Port $port is not in use"
    fi
done

echo ""
echo "=========================================="
echo "SYSTEM ACCESS POINTS"
echo "=========================================="
echo "🌐 API Gateway: http://localhost:8080"
echo "🏥 Health Check: http://localhost:8080/health"
echo "📡 API Base URL: http://localhost:8080/api/v1"
echo ""

echo "=========================================="
echo "QUICK COMMANDS"
echo "=========================================="
echo "📊 Full demo: ./demo-system.sh"
echo "🧪 Run tests: make test-api"
echo "📋 Show help: make help"
echo "🔍 View logs: make logs"
echo "⏹️  Stop system: make stop"
echo ""

# Final status
if [ -n "$ORDERER_STATUS" ] && [ -n "$PEER1_STATUS" ] && [ -n "$API_STATUS" ]; then
    print_success "System is running! You can access the API at http://localhost:8080"
    echo ""
    echo "Try these quick tests:"
    echo "curl http://localhost:8080/health"
    echo "curl http://localhost:8080/api/v1/assets"
else
    print_error "System is not fully running. Deploy with: make full-deploy"
fi
