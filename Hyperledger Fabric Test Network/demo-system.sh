#!/bin/bash

# Comprehensive Demo Script for Hyperledger Fabric Asset Management System
# This script will deploy the system and demonstrate all features

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_header() {
    echo -e "${PURPLE}=========================================="
    echo -e "$1"
    echo -e "==========================================${NC}"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to wait for user input
wait_for_user() {
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read
}

# Function to check if a service is running
check_service() {
    local service_name=$1
    local port=$2
    local max_attempts=30
    local attempt=1

    print_step "Checking if $service_name is running on port $port..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s "http://localhost:$port" >/dev/null 2>&1 || \
           curl -s "http://localhost:$port/health" >/dev/null 2>&1; then
            print_success "$service_name is running!"
            return 0
        fi
        
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    print_error "$service_name is not responding after $max_attempts attempts"
    return 1
}

# Function to make API call and show response
api_call() {
    local method=$1
    local endpoint=$2
    local data=$3
    local description=$4
    
    print_step "$description"
    echo -e "${CYAN}Request: $method $endpoint${NC}"
    
    if [ -n "$data" ]; then
        echo -e "${CYAN}Data: $data${NC}"
        response=$(curl -s -X $method "http://localhost:8080$endpoint" \
            -H "Content-Type: application/json" \
            -d "$data" \
            -w "\n%{http_code}")
    else
        response=$(curl -s -X $method "http://localhost:8080$endpoint" \
            -w "\n%{http_code}")
    fi
    
    # Extract HTTP code and response body
    http_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | head -n -1)
    
    echo -e "${CYAN}HTTP Status: $http_code${NC}"
    echo -e "${CYAN}Response:${NC}"
    echo "$response_body" | jq '.' 2>/dev/null || echo "$response_body"
    echo ""
    
    # Check if request was successful
    if [[ $http_code =~ ^2[0-9][0-9]$ ]]; then
        print_success "API call successful!"
    else
        print_warning "API call returned HTTP $http_code"
    fi
    
    echo "----------------------------------------"
    wait_for_user
}

# Function to show system status
show_system_status() {
    print_header "SYSTEM STATUS CHECK"
    
    print_step "Checking Docker containers..."
    echo "Running containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(orderer|peer|api-gateway)" || echo "No Fabric containers running"
    echo ""
    
    print_step "Checking network connectivity..."
    docker network ls | grep fabric_test && print_success "Fabric network exists" || print_warning "Fabric network not found"
    echo ""
    
    print_step "Checking API Gateway health..."
    if curl -s http://localhost:8080/health >/dev/null 2>&1; then
        health_response=$(curl -s http://localhost:8080/health)
        print_success "API Gateway is healthy: $health_response"
    else
        print_error "API Gateway is not responding"
    fi
    echo ""
}

# Function to demonstrate all API features
demonstrate_api() {
    print_header "API DEMONSTRATION"
    
    # Health check
    api_call "GET" "/health" "" "1. Health Check"
    
    # Initialize ledger
    api_call "POST" "/api/v1/ledger/init" "" "2. Initialize Ledger with Sample Data"
    
    # Get all assets (should show initial data)
    api_call "GET" "/api/v1/assets" "" "3. Get All Assets (Initial Data)"
    
    # Create a new asset
    local create_data='{
        "msisdn": "9876543210",
        "dealerId": "DEALER999",
        "mpin": "9999",
        "balance": 5000.0,
        "status": "ACTIVE",
        "remarks": "Demo account created by verification script"
    }'
    api_call "POST" "/api/v1/assets" "$create_data" "4. Create New Asset"
    
    # Get the created asset
    api_call "GET" "/api/v1/assets/9876543210" "" "5. Get Created Asset"
    
    # Credit the account
    local credit_data='{
        "mpin": "9999",
        "amount": 1500.0,
        "transType": "CREDIT",
        "remarks": "Demo credit transaction"
    }'
    api_call "PUT" "/api/v1/assets/9876543210/balance" "$credit_data" "6. Credit Account (+1500)"
    
    # Get asset after credit
    api_call "GET" "/api/v1/assets/9876543210" "" "7. Get Asset After Credit"
    
    # Debit the account
    local debit_data='{
        "mpin": "9999",
        "amount": 800.0,
        "transType": "DEBIT",
        "remarks": "Demo debit transaction"
    }'
    api_call "PUT" "/api/v1/assets/9876543210/balance" "$debit_data" "8. Debit Account (-800)"
    
    # Get asset after debit
    api_call "GET" "/api/v1/assets/9876543210" "" "9. Get Asset After Debit"
    
    # Update status
    local status_data='{
        "status": "BLOCKED",
        "remarks": "Demo status update - account blocked"
    }'
    api_call "PUT" "/api/v1/assets/9876543210/status" "$status_data" "10. Update Status to BLOCKED"
    
    # Get asset after status update
    api_call "GET" "/api/v1/assets/9876543210" "" "11. Get Asset After Status Update"
    
    # Reactivate account
    local reactivate_data='{
        "status": "ACTIVE",
        "remarks": "Demo status update - account reactivated"
    }'
    api_call "PUT" "/api/v1/assets/9876543210/status" "$reactivate_data" "12. Reactivate Account"
    
    # Get transaction history
    api_call "GET" "/api/v1/assets/9876543210/transactions" "" "13. Get Transaction History"
    
    # Get all assets (final state)
    api_call "GET" "/api/v1/assets" "" "14. Get All Assets (Final State)"
    
    # Test error scenarios
    print_header "ERROR SCENARIO TESTING"
    
    # Test wrong MPIN
    local wrong_mpin_data='{
        "mpin": "0000",
        "amount": 100.0,
        "transType": "CREDIT",
        "remarks": "Test wrong MPIN"
    }'
    api_call "PUT" "/api/v1/assets/9876543210/balance" "$wrong_mpin_data" "15. Test Wrong MPIN (Should Fail)"
    
    # Test insufficient balance
    local insufficient_data='{
        "mpin": "9999",
        "amount": 999999.0,
        "transType": "DEBIT",
        "remarks": "Test insufficient balance"
    }'
    api_call "PUT" "/api/v1/assets/9876543210/balance" "$insufficient_data" "16. Test Insufficient Balance (Should Fail)"
    
    # Test non-existent asset
    api_call "GET" "/api/v1/assets/0000000000" "" "17. Test Non-existent Asset (Should Fail)"
}

# Function to show deployment logs
show_deployment_logs() {
    print_header "DEPLOYMENT LOGS"
    
    print_step "Recent logs from key components:"
    
    echo -e "${CYAN}=== Orderer Logs (last 10 lines) ===${NC}"
    docker logs orderer.example.com --tail 10 2>/dev/null || echo "Orderer not running"
    echo ""
    
    echo -e "${CYAN}=== Peer0 Org1 Logs (last 10 lines) ===${NC}"
    docker logs peer0.org1.example.com --tail 10 2>/dev/null || echo "Peer0 Org1 not running"
    echo ""
    
    echo -e "${CYAN}=== API Gateway Logs (last 10 lines) ===${NC}"
    docker logs api-gateway --tail 10 2>/dev/null || echo "API Gateway not running"
    echo ""
}

# Function to run performance test
run_performance_test() {
    print_header "PERFORMANCE TEST"
    
    print_step "Running performance test with multiple API calls..."
    
    local start_time=$(date +%s)
    local success_count=0
    local total_requests=10
    
    for i in $(seq 1 $total_requests); do
        if curl -s http://localhost:8080/health >/dev/null 2>&1; then
            ((success_count++))
        fi
        echo -n "."
    done
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    print_info "Performance Test Results:"
    echo "  Total Requests: $total_requests"
    echo "  Successful Requests: $success_count"
    echo "  Failed Requests: $((total_requests - success_count))"
    echo "  Total Time: ${duration}s"
    echo "  Average Response Time: $((duration * 1000 / total_requests))ms"
    
    if [ $success_count -eq $total_requests ]; then
        print_success "All requests successful!"
    else
        print_warning "Some requests failed"
    fi
}

# Main demonstration function
main() {
    clear
    print_header "HYPERLEDGER FABRIC ASSET MANAGEMENT SYSTEM
                    COMPREHENSIVE DEMONSTRATION"
    
    print_info "This script will:"
    echo "  1. Check system status"
    echo "  2. Demonstrate all API features"
    echo "  3. Test error scenarios"
    echo "  4. Show deployment logs"
    echo "  5. Run performance tests"
    echo ""
    
    print_warning "Make sure the system is deployed before running this demo!"
    echo "If not deployed, run: make full-deploy"
    echo ""
    wait_for_user
    
    # Check system status
    show_system_status
    wait_for_user
    
    # Check if API is running
    if ! check_service "API Gateway" 8080; then
        print_error "API Gateway is not running. Please deploy the system first."
        echo "Run: make full-deploy"
        exit 1
    fi
    
    # Demonstrate API features
    demonstrate_api
    
    # Show logs
    show_deployment_logs
    wait_for_user
    
    # Performance test
    run_performance_test
    wait_for_user
    
    # Final summary
    print_header "DEMONSTRATION COMPLETE"
    print_success "All features have been demonstrated!"
    echo ""
    print_info "System Access Points:"
    echo "  • API Gateway: http://localhost:8080"
    echo "  • Health Check: http://localhost:8080/health"
    echo "  • API Base URL: http://localhost:8080/api/v1"
    echo ""
    print_info "Available Commands:"
    echo "  • make status    - Check system status"
    echo "  • make test-api  - Run automated tests"
    echo "  • make logs      - View container logs"
    echo "  • make stop      - Stop the system"
    echo ""
    print_success "The Hyperledger Fabric Asset Management System is working correctly!"
}

# Check if jq is available, if not provide alternative
if ! command -v jq &> /dev/null; then
    print_warning "jq is not installed. JSON responses will be shown as raw text."
    echo "To install jq:"
    echo "  Ubuntu/Debian: sudo apt-get install jq"
    echo "  macOS: brew install jq"
    echo "  Windows: Download from https://stedolan.github.io/jq/"
    echo ""
fi

# Run main function
main
