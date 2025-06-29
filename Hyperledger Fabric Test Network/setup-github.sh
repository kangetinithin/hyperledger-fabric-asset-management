#!/bin/bash

echo "=========================================="
echo "GitHub Repository Setup Script"
echo "=========================================="

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "Error: Git is not installed. Please install Git first."
    exit 1
fi

# Initialize git repository if not already initialized
if [ ! -d ".git" ]; then
    echo "Initializing Git repository..."
    git init
    echo "Git repository initialized!"
else
    echo "Git repository already exists."
fi

# Add all files to git
echo "Adding files to Git..."
git add .

# Create initial commit
echo "Creating initial commit..."
git commit -m "Initial commit: Hyperledger Fabric Asset Management System

Features:
- Complete Hyperledger Fabric test network setup
- Go-based smart contract for asset management
- REST API gateway with comprehensive endpoints
- Docker containerization
- Comprehensive testing and documentation
- Asset attributes: DEALERID, MSISDN, MPIN, BALANCE, STATUS, TRANSAMOUNT, TRANSTYPE, REMARKS"

echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo "1. Create a new repository on GitHub:"
echo "   - Go to https://github.com/new"
echo "   - Repository name: hyperledger-fabric-asset-management"
echo "   - Description: Blockchain-based Asset Management System using Hyperledger Fabric"
echo "   - Make it Public"
echo "   - Don't initialize with README (we already have one)"
echo ""
echo "2. After creating the repository, run these commands:"
echo "   git branch -M main"
echo "   git remote add origin https://github.com/YOUR_USERNAME/hyperledger-fabric-asset-management.git"
echo "   git push -u origin main"
echo ""
echo "3. Your repository will be available at:"
echo "   https://github.com/YOUR_USERNAME/hyperledger-fabric-asset-management"
echo ""
echo "=========================================="
echo "Local Deployment Instructions:"
echo "=========================================="
echo "To run the system locally:"
echo "1. Make sure Docker is running"
echo "2. Run: make full-deploy"
echo "3. Access API at: http://localhost:8080"
echo "4. Test with: make test-api"
echo "=========================================="
