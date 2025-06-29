# Deployment Guide

This guide provides step-by-step instructions for deploying the Hyperledger Fabric Asset Management System.

## Prerequisites

### System Requirements
- **Operating System**: Linux (Ubuntu 18.04+), macOS, or Windows with WSL2
- **Memory**: Minimum 8GB RAM (16GB recommended)
- **Storage**: At least 20GB free space
- **Network**: Internet connection for downloading dependencies

### Software Dependencies
- **Docker**: Version 20.10 or later
- **Docker Compose**: Version 1.29 or later
- **Go**: Version 1.19 or later
- **Git**: For cloning repositories
- **curl**: For API testing
- **jq**: For JSON parsing (optional but recommended)

## Installation Steps

### 1. Install Docker and Docker Compose

#### Ubuntu/Debian
```bash
# Update package index
sudo apt-get update

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.12.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Logout and login again for group changes to take effect
```

#### macOS
```bash
# Install Docker Desktop from https://www.docker.com/products/docker-desktop
# Docker Compose is included with Docker Desktop
```

### 2. Install Go

#### Ubuntu/Debian
```bash
# Download and install Go
wget https://go.dev/dl/go1.19.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.19.linux-amd64.tar.gz

# Add to PATH
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc
```

#### macOS
```bash
# Using Homebrew
brew install go

# Or download from https://golang.org/dl/
```

### 3. Install Hyperledger Fabric Binaries

```bash
# Create directory for Fabric
mkdir -p ~/fabric-samples
cd ~/fabric-samples

# Download Fabric samples, binaries, and Docker images
curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.4.7 1.5.5

# Add binaries to PATH
export PATH=$PATH:~/fabric-samples/bin
echo 'export PATH=$PATH:~/fabric-samples/bin' >> ~/.bashrc
```

### 4. Clone and Setup Project

```bash
# Clone the project (replace with actual repository URL)
git clone <repository-url> hyperledger-fabric-asset-management
cd hyperledger-fabric-asset-management

# Make scripts executable
chmod +x network.sh
chmod +x scripts/*.sh
chmod +x test-api.sh
```

## Deployment Process

### Step 1: Generate Cryptographic Material

```bash
# Generate certificates and keys
./network.sh generate
```

This command will:
- Generate CA certificates
- Create peer and orderer certificates
- Generate user certificates
- Create genesis block

### Step 2: Start the Fabric Network

```bash
# Start the network
./network.sh up
```

This will start:
- Orderer node
- Peer nodes for Org1 and Org2
- CLI container

### Step 3: Create Channel

```bash
# Create and join channel
./network.sh createChannel
```

### Step 4: Deploy Chaincode

```bash
# Deploy the asset management chaincode
./scripts/deployCC.sh
```

This process includes:
- Package chaincode
- Install on all peers
- Approve chaincode definition
- Commit chaincode definition

### Step 5: Start API Gateway

#### Option A: Using Docker Compose (Recommended)
```bash
# Build and start API gateway
docker-compose -f docker-compose-api.yaml up -d api-gateway
```

#### Option B: Run Locally
```bash
# Navigate to API directory
cd api-gateway

# Install dependencies
go mod tidy

# Run the API gateway
go run main.go
```

### Step 6: Initialize Ledger

```bash
# Initialize with sample data
curl -X POST http://localhost:8080/api/v1/ledger/init
```

### Step 7: Verify Deployment

```bash
# Run comprehensive tests
./test-api.sh
```

## Configuration

### Environment Variables

Create a `.env` file in the project root:

```bash
# Fabric Configuration
FABRIC_CFG_PATH=./config
CHANNEL_NAME=mychannel
CHAINCODE_NAME=basic

# API Gateway Configuration
API_PORT=8080
PEER_ENDPOINT=localhost:7051
GATEWAY_PEER=peer0.org1.example.com

# Crypto Configuration
CRYPTO_PATH=./organizations/peerOrganizations/org1.example.com
MSP_ID=Org1MSP
```

### Network Ports

Ensure the following ports are available:
- **7050**: Orderer
- **7051**: Peer0 Org1
- **9051**: Peer0 Org2
- **8080**: API Gateway
- **9443-9445**: Operations and metrics

## Monitoring and Logs

### View Container Logs

```bash
# Network components
docker logs orderer.example.com
docker logs peer0.org1.example.com
docker logs peer0.org2.example.com

# API Gateway
docker logs api-gateway
```

### Monitor Network Status

```bash
# Check running containers
docker ps

# Check network connectivity
docker network ls
docker network inspect fabric_test
```

## Troubleshooting

### Common Issues

#### 1. Port Conflicts
```bash
# Check port usage
netstat -tulpn | grep :7050
netstat -tulpn | grep :8080

# Kill processes using required ports
sudo kill -9 $(sudo lsof -t -i:7050)
```

#### 2. Permission Issues
```bash
# Fix Docker permissions
sudo chmod 666 /var/run/docker.sock

# Fix file permissions
sudo chown -R $USER:$USER ./organizations
```

#### 3. Network Startup Failures
```bash
# Clean up and restart
./network.sh down
docker system prune -f
./network.sh up
```

#### 4. Chaincode Deployment Issues
```bash
# Check chaincode logs
docker logs dev-peer0.org1.example.com-basic_1.0

# Redeploy chaincode
./scripts/deployCC.sh mychannel basic ../chaincode/asset-management/ golang 1.1 2
```

### Log Analysis

#### Enable Debug Logging
```bash
# Set environment variable for detailed logs
export FABRIC_LOGGING_SPEC=DEBUG

# Restart network with debug logging
./network.sh restart
```

#### Check Specific Component Logs
```bash
# Peer logs
docker exec peer0.org1.example.com peer logging getlevel

# Orderer logs
docker exec orderer.example.com orderer logging getlevel
```

## Performance Tuning

### Resource Allocation

Update `docker-compose-test-net.yaml` for production:

```yaml
services:
  peer0.org1.example.com:
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '1.0'
        reservations:
          memory: 1G
          cpus: '0.5'
```

### Database Configuration

For production, consider using CouchDB:

```bash
# Start network with CouchDB
./network.sh up -s couchdb
```

## Security Considerations

### Production Deployment

1. **Change Default Credentials**: Update all default passwords and keys
2. **Enable TLS**: Ensure all communication is encrypted
3. **Network Isolation**: Use private networks for peer communication
4. **Access Control**: Implement proper authentication and authorization
5. **Regular Updates**: Keep Fabric and dependencies updated

### Certificate Management

```bash
# Backup certificates
tar -czf crypto-backup.tar.gz organizations/

# Rotate certificates (advanced)
# Follow Hyperledger Fabric documentation for certificate rotation
```

## Backup and Recovery

### Backup Procedure

```bash
# Create backup script
cat > backup.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="backup_$DATE"

mkdir -p $BACKUP_DIR
cp -r organizations $BACKUP_DIR/
cp -r channel-artifacts $BACKUP_DIR/
cp -r system-genesis-block $BACKUP_DIR/

tar -czf $BACKUP_DIR.tar.gz $BACKUP_DIR
rm -rf $BACKUP_DIR

echo "Backup created: $BACKUP_DIR.tar.gz"
EOF

chmod +x backup.sh
```

### Recovery Procedure

```bash
# Stop network
./network.sh down

# Restore from backup
tar -xzf backup_YYYYMMDD_HHMMSS.tar.gz
cp -r backup_YYYYMMDD_HHMMSS/* ./

# Restart network
./network.sh up
```

## Scaling

### Adding Organizations

1. Update `configtx.yaml` with new organization
2. Generate crypto material for new org
3. Create channel update transaction
4. Join new peers to channel
5. Install and approve chaincode on new peers

### Load Balancing

For high availability, deploy multiple API gateway instances:

```yaml
# docker-compose-ha.yaml
services:
  api-gateway-1:
    build: ./api-gateway
    ports:
      - "8080:8080"
  
  api-gateway-2:
    build: ./api-gateway
    ports:
      - "8081:8080"
  
  nginx:
    image: nginx
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
```

## Maintenance

### Regular Tasks

1. **Monitor Disk Space**: Fabric generates logs and data
2. **Update Dependencies**: Keep Go modules and Docker images updated
3. **Certificate Renewal**: Monitor certificate expiration
4. **Performance Monitoring**: Track transaction throughput and latency

### Automated Maintenance

```bash
# Create maintenance script
cat > maintenance.sh << 'EOF'
#!/bin/bash
# Clean up old Docker images
docker image prune -f

# Backup data
./backup.sh

# Check certificate expiration
openssl x509 -in organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/server.crt -noout -dates
EOF

chmod +x maintenance.sh

# Add to crontab for weekly execution
echo "0 2 * * 0 /path/to/maintenance.sh" | crontab -
```
