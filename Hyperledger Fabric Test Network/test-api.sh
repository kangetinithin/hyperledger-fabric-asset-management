#!/bin/bash

# API Testing Script for Hyperledger Fabric Asset Management System

API_URL="http://localhost:8080/api/v1"
TEST_MSISDN="9876543210"
TEST_DEALER="DEALER999"
TEST_MPIN="9999"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to check if API is running
check_api_health() {
    print_status "Checking API health..."
    response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health)
    if [ "$response" = "200" ]; then
        print_success "API is healthy"
        return 0
    else
        print_error "API is not responding (HTTP $response)"
        return 1
    fi
}

# Function to initialize ledger
init_ledger() {
    print_status "Initializing ledger..."
    response=$(curl -s -X POST "$API_URL/ledger/init" -w "%{http_code}")
    http_code="${response: -3}"
    if [ "$http_code" = "200" ]; then
        print_success "Ledger initialized successfully"
        return 0
    else
        print_error "Failed to initialize ledger (HTTP $http_code)"
        return 1
    fi
}

# Function to create a test asset
create_test_asset() {
    print_status "Creating test asset..."
    response=$(curl -s -X POST "$API_URL/assets" \
        -H "Content-Type: application/json" \
        -d "{
            \"msisdn\": \"$TEST_MSISDN\",
            \"dealerId\": \"$TEST_DEALER\",
            \"mpin\": \"$TEST_MPIN\",
            \"balance\": 5000.0,
            \"status\": \"ACTIVE\",
            \"remarks\": \"Test account creation\"
        }" \
        -w "%{http_code}")
    
    http_code="${response: -3}"
    if [ "$http_code" = "201" ]; then
        print_success "Test asset created successfully"
        return 0
    else
        print_error "Failed to create test asset (HTTP $http_code)"
        echo "Response: ${response%???}"
        return 1
    fi
}

# Function to get asset
get_asset() {
    print_status "Getting asset $TEST_MSISDN..."
    response=$(curl -s "$API_URL/assets/$TEST_MSISDN" -w "%{http_code}")
    http_code="${response: -3}"
    if [ "$http_code" = "200" ]; then
        print_success "Asset retrieved successfully"
        echo "Asset data: ${response%???}" | jq '.' 2>/dev/null || echo "${response%???}"
        return 0
    else
        print_error "Failed to get asset (HTTP $http_code)"
        return 1
    fi
}

# Function to get all assets
get_all_assets() {
    print_status "Getting all assets..."
    response=$(curl -s "$API_URL/assets" -w "%{http_code}")
    http_code="${response: -3}"
    if [ "$http_code" = "200" ]; then
        print_success "All assets retrieved successfully"
        echo "Assets count: $(echo "${response%???}" | jq 'length' 2>/dev/null || echo "Unable to parse JSON")"
        return 0
    else
        print_error "Failed to get all assets (HTTP $http_code)"
        return 1
    fi
}

# Function to credit account
credit_account() {
    local amount=$1
    print_status "Crediting account with $amount..."
    response=$(curl -s -X PUT "$API_URL/assets/$TEST_MSISDN/balance" \
        -H "Content-Type: application/json" \
        -d "{
            \"mpin\": \"$TEST_MPIN\",
            \"amount\": $amount,
            \"transType\": \"CREDIT\",
            \"remarks\": \"Test credit transaction\"
        }" \
        -w "%{http_code}")
    
    http_code="${response: -3}"
    if [ "$http_code" = "200" ]; then
        print_success "Account credited successfully"
        return 0
    else
        print_error "Failed to credit account (HTTP $http_code)"
        echo "Response: ${response%???}"
        return 1
    fi
}

# Function to debit account
debit_account() {
    local amount=$1
    print_status "Debiting account with $amount..."
    response=$(curl -s -X PUT "$API_URL/assets/$TEST_MSISDN/balance" \
        -H "Content-Type: application/json" \
        -d "{
            \"mpin\": \"$TEST_MPIN\",
            \"amount\": $amount,
            \"transType\": \"DEBIT\",
            \"remarks\": \"Test debit transaction\"
        }" \
        -w "%{http_code}")
    
    http_code="${response: -3}"
    if [ "$http_code" = "200" ]; then
        print_success "Account debited successfully"
        return 0
    else
        print_error "Failed to debit account (HTTP $http_code)"
        echo "Response: ${response%???}"
        return 1
    fi
}

# Function to test insufficient balance
test_insufficient_balance() {
    print_status "Testing insufficient balance scenario..."
    response=$(curl -s -X PUT "$API_URL/assets/$TEST_MSISDN/balance" \
        -H "Content-Type: application/json" \
        -d "{
            \"mpin\": \"$TEST_MPIN\",
            \"amount\": 999999.0,
            \"transType\": \"DEBIT\",
            \"remarks\": \"Test insufficient balance\"
        }" \
        -w "%{http_code}")
    
    http_code="${response: -3}"
    if [ "$http_code" = "500" ]; then
        print_success "Insufficient balance test passed (correctly rejected)"
        return 0
    else
        print_warning "Insufficient balance test unexpected result (HTTP $http_code)"
        return 1
    fi
}

# Function to test wrong MPIN
test_wrong_mpin() {
    print_status "Testing wrong MPIN scenario..."
    response=$(curl -s -X PUT "$API_URL/assets/$TEST_MSISDN/balance" \
        -H "Content-Type: application/json" \
        -d "{
            \"mpin\": \"0000\",
            \"amount\": 100.0,
            \"transType\": \"CREDIT\",
            \"remarks\": \"Test wrong MPIN\"
        }" \
        -w "%{http_code}")
    
    http_code="${response: -3}"
    if [ "$http_code" = "500" ]; then
        print_success "Wrong MPIN test passed (correctly rejected)"
        return 0
    else
        print_warning "Wrong MPIN test unexpected result (HTTP $http_code)"
        return 1
    fi
}

# Function to update asset status
update_status() {
    local status=$1
    print_status "Updating asset status to $status..."
    response=$(curl -s -X PUT "$API_URL/assets/$TEST_MSISDN/status" \
        -H "Content-Type: application/json" \
        -d "{
            \"status\": \"$status\",
            \"remarks\": \"Test status update to $status\"
        }" \
        -w "%{http_code}")
    
    http_code="${response: -3}"
    if [ "$http_code" = "200" ]; then
        print_success "Asset status updated successfully"
        return 0
    else
        print_error "Failed to update asset status (HTTP $http_code)"
        return 1
    fi
}

# Function to get transaction history
get_transaction_history() {
    print_status "Getting transaction history..."
    response=$(curl -s "$API_URL/assets/$TEST_MSISDN/transactions" -w "%{http_code}")
    http_code="${response: -3}"
    if [ "$http_code" = "200" ]; then
        print_success "Transaction history retrieved successfully"
        echo "Transaction history: ${response%???}" | jq '.' 2>/dev/null || echo "${response%???}"
        return 0
    else
        print_error "Failed to get transaction history (HTTP $http_code)"
        return 1
    fi
}

# Function to delete asset
delete_asset() {
    print_status "Deleting test asset..."
    response=$(curl -s -X DELETE "$API_URL/assets/$TEST_MSISDN" -w "%{http_code}")
    http_code="${response: -3}"
    if [ "$http_code" = "200" ]; then
        print_success "Asset deleted successfully"
        return 0
    else
        print_error "Failed to delete asset (HTTP $http_code)"
        return 1
    fi
}

# Main test execution
main() {
    echo "=========================================="
    echo "Hyperledger Fabric Asset Management API Tests"
    echo "=========================================="
    
    # Check if API is running
    if ! check_api_health; then
        print_error "API is not running. Please start the API gateway first."
        exit 1
    fi
    
    # Initialize ledger
    init_ledger
    
    # Test asset creation
    if create_test_asset; then
        # Test asset retrieval
        get_asset
        
        # Test getting all assets
        get_all_assets
        
        # Test credit operation
        credit_account 1000.0
        
        # Get asset after credit
        get_asset
        
        # Test debit operation
        debit_account 500.0
        
        # Get asset after debit
        get_asset
        
        # Test insufficient balance
        test_insufficient_balance
        
        # Test wrong MPIN
        test_wrong_mpin
        
        # Test status update
        update_status "BLOCKED"
        get_asset
        
        # Reactivate account
        update_status "ACTIVE"
        
        # Get transaction history
        get_transaction_history
        
        # Clean up - delete test asset
        delete_asset
        
        print_success "All tests completed!"
    else
        print_error "Failed to create test asset. Skipping remaining tests."
        exit 1
    fi
}

# Run main function
main
