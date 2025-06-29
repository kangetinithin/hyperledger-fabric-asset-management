#!/bin/bash

echo "=========================================="
echo "Hyperledger Fabric Asset Management System"
echo "Deployment Verification Script"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if Docker is running
check_docker() {
    print_status "Checking Docker..."
    if docker info >/dev/null 2>&1; then
        print_success "Docker is running"
        return 0
    else
        print_error "Docker is not running. Please start Docker first."
        return 1
    fi
}

# Check if required ports are available
check_ports() {
    print_status "Checking required ports..."
    local ports=(7050 7051 9051 8080)
    local all_available=true
    
    for port in "${ports[@]}"; do
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            print_warning "Port $port is already in use"
            all_available=false
        else
            echo "  ✓ Port $port is available"
        fi
    done
    
    if $all_available; then
        print_success "All required ports are available"
        return 0
    else
        print_warning "Some ports are in use. You may need to stop other services."
        return 1
    fi
}

# Check if Hyperledger Fabric binaries are available
check_fabric_binaries() {
    print_status "Checking Hyperledger Fabric binaries..."
    if command -v peer >/dev/null 2>&1 && command -v orderer >/dev/null 2>&1; then
        print_success "Fabric binaries are available"
        return 0
    else
        print_error "Fabric binaries not found. Please install Hyperledger Fabric."
        echo "Run: curl -sSL https://bit.ly/2ysbOFE | bash -s"
        return 1
    fi
}

# Check if Go is installed
check_go() {
    print_status "Checking Go installation..."
    if command -v go >/dev/null 2>&1; then
        local go_version=$(go version | awk '{print $3}')
        print_success "Go is installed: $go_version"
        return 0
    else
        print_error "Go is not installed. Please install Go 1.19 or later."
        return 1
    fi
}

# Display deployment instructions
show_deployment_instructions() {
    echo ""
    echo "=========================================="
    echo "DEPLOYMENT INSTRUCTIONS"
    echo "=========================================="
    echo ""
    echo "🚀 Quick Start (Automated):"
    echo "   make full-deploy"
    echo ""
    echo "📋 Step by Step:"
    echo "   1. make setup          # Generate crypto material"
    echo "   2. make start          # Start Fabric network"
    echo "   3. make deploy-cc      # Deploy chaincode"
    echo "   4. make start-api      # Start API gateway"
    echo "   5. make init-ledger    # Initialize with sample data"
    echo "   6. make test-api       # Run tests"
    echo ""
    echo "🌐 Access Points:"
    echo "   • API Gateway: http://localhost:8080"
    echo "   • Health Check: http://localhost:8080/health"
    echo "   • API Documentation: See README.md"
    echo ""
    echo "🧪 Testing:"
    echo "   • Run API tests: make test-api"
    echo "   • Run unit tests: make test-cc"
    echo "   • Check status: make status"
    echo ""
    echo "📚 Documentation:"
    echo "   • README.md - Complete project documentation"
    echo "   • DEPLOYMENT.md - Detailed deployment guide"
    echo "   • API endpoints documented in README.md"
    echo ""
    echo "🔧 Management Commands:"
    echo "   • make help     # Show all available commands"
    echo "   • make status   # Check system status"
    echo "   • make logs     # View container logs"
    echo "   • make stop     # Stop the network"
    echo "   • make clean    # Clean up everything"
    echo ""
}

# Display GitHub setup instructions
show_github_instructions() {
    echo "=========================================="
    echo "GITHUB REPOSITORY SETUP"
    echo "=========================================="
    echo ""
    echo "📤 To upload to GitHub:"
    echo "   1. Run: chmod +x setup-github.sh && ./setup-github.sh"
    echo "   2. Create repository at: https://github.com/new"
    echo "   3. Follow the instructions shown by the script"
    echo ""
    echo "🔗 Repository will be available at:"
    echo "   https://github.com/YOUR_USERNAME/hyperledger-fabric-asset-management"
    echo ""
}

# Main verification
main() {
    echo "Starting system verification..."
    echo ""
    
    local checks_passed=0
    local total_checks=4
    
    if check_docker; then
        ((checks_passed++))
    fi
    
    if check_go; then
        ((checks_passed++))
    fi
    
    if check_fabric_binaries; then
        ((checks_passed++))
    fi
    
    if check_ports; then
        ((checks_passed++))
    fi
    
    echo ""
    echo "=========================================="
    echo "VERIFICATION SUMMARY"
    echo "=========================================="
    
    if [ $checks_passed -eq $total_checks ]; then
        print_success "All checks passed! ($checks_passed/$total_checks)"
        print_success "System is ready for deployment!"
    elif [ $checks_passed -ge 2 ]; then
        print_warning "Most checks passed ($checks_passed/$total_checks)"
        print_warning "You can proceed but may encounter issues"
    else
        print_error "Multiple checks failed ($checks_passed/$total_checks)"
        print_error "Please resolve the issues before deployment"
    fi
    
    show_deployment_instructions
    show_github_instructions
}

# Run main function
main
