# Hyperledger Fabric Asset Management System

A comprehensive blockchain-based asset management system built with Hyperledger Fabric, featuring smart contracts for managing financial assets and a REST API gateway for easy integration.

## Features

- **Asset Management**: Create, read, update, and delete financial assets
- **Balance Management**: Credit and debit operations with transaction history
- **Status Management**: Update asset status (ACTIVE, INACTIVE, BLOCKED)
- **Transaction History**: Complete audit trail of all asset operations
- **REST API**: RESTful endpoints for easy integration
- **Security**: MPIN-based authentication for sensitive operations

## Architecture

### Components

1. **Hyperledger Fabric Network**
   - 2 Organizations (Org1, Org2)
   - 1 Orderer (Solo consensus)
   - 2 Peers (1 per organization)
   - TLS enabled for secure communication

2. **Smart Contract (Chaincode)**
   - Written in Go
   - Manages asset lifecycle
   - Implements business logic for financial operations

3. **REST API Gateway**
   - Go-based HTTP server using Gin framework
   - Connects to Fabric network using Fabric Gateway SDK
   - Provides RESTful endpoints for asset operations

### Asset Structure

Each asset contains the following attributes:
- `dealerId`: Unique dealer identifier
- `msisdn`: Mobile number (used as primary key)
- `mpin`: Mobile PIN for authentication
- `balance`: Current account balance
- `status`: Account status (ACTIVE, INACTIVE, BLOCKED)
- `transAmount`: Last transaction amount
- `transType`: Last transaction type (CREDIT, DEBIT, CREATE)
- `remarks`: Additional notes
- `createdAt`: Asset creation timestamp
- `updatedAt`: Last update timestamp

## Prerequisites

- Docker and Docker Compose
- Go 1.19 or later
- Hyperledger Fabric binaries and Docker images (v2.4+)

## Quick Start

### 1. Setup Hyperledger Fabric Network

```bash
# Generate crypto material
./network.sh generate

# Start the network
./network.sh up

# Create channel
./network.sh createChannel

# Deploy chaincode
./scripts/deployCC.sh
```

### 2. Start API Gateway

```bash
# Using Docker Compose
docker-compose -f docker-compose-api.yaml up -d

# Or run locally
cd api-gateway
go mod tidy
go run main.go
```

### 3. Initialize Ledger

```bash
curl -X POST http://localhost:8080/api/v1/ledger/init
```

## API Endpoints

### Asset Management

#### Create Asset
```bash
POST /api/v1/assets
Content-Type: application/json

{
  "msisdn": "1234567890",
  "dealerId": "DEALER001",
  "mpin": "1234",
  "balance": 1000.0,
  "status": "ACTIVE",
  "remarks": "Initial account creation"
}
```

#### Get Asset
```bash
GET /api/v1/assets/{msisdn}
```

#### Get All Assets
```bash
GET /api/v1/assets
```

#### Update Balance
```bash
PUT /api/v1/assets/{msisdn}/balance
Content-Type: application/json

{
  "mpin": "1234",
  "amount": 500.0,
  "transType": "CREDIT",
  "remarks": "Account top-up"
}
```

#### Update Status
```bash
PUT /api/v1/assets/{msisdn}/status
Content-Type: application/json

{
  "status": "BLOCKED",
  "remarks": "Account suspended"
}
```

#### Delete Asset
```bash
DELETE /api/v1/assets/{msisdn}
```

#### Get Transaction History
```bash
GET /api/v1/assets/{msisdn}/transactions
```

### System Endpoints

#### Health Check
```bash
GET /health
```

#### Initialize Ledger
```bash
POST /api/v1/ledger/init
```

## Testing

### Unit Tests

Run chaincode unit tests:
```bash
cd chaincode/asset-management
go test -v
```

### Integration Tests

Test API endpoints:
```bash
# Create an asset
curl -X POST http://localhost:8080/api/v1/assets \
  -H "Content-Type: application/json" \
  -d '{
    "msisdn": "9876543210",
    "dealerId": "DEALER999",
    "mpin": "9999",
    "balance": 5000.0,
    "status": "ACTIVE",
    "remarks": "Test account"
  }'

# Get the asset
curl http://localhost:8080/api/v1/assets/9876543210

# Credit the account
curl -X PUT http://localhost:8080/api/v1/assets/9876543210/balance \
  -H "Content-Type: application/json" \
  -d '{
    "mpin": "9999",
    "amount": 1000.0,
    "transType": "CREDIT",
    "remarks": "Test credit"
  }'

# Check transaction history
curl http://localhost:8080/api/v1/assets/9876543210/transactions
```

## Configuration

### Environment Variables

- `FABRIC_CFG_PATH`: Path to Fabric configuration files
- `CRYPTO_PATH`: Path to cryptographic material
- `PEER_ENDPOINT`: Peer endpoint for gateway connection
- `CHANNEL_NAME`: Fabric channel name (default: mychannel)
- `CHAINCODE_NAME`: Chaincode name (default: basic)

### Network Configuration

The network configuration can be modified in:
- `configtx.yaml`: Channel and organization configuration
- `docker-compose-test-net.yaml`: Docker services configuration
- `organizations/cryptogen/`: Crypto configuration files

## Security Considerations

1. **MPIN Authentication**: All balance operations require MPIN verification
2. **TLS Communication**: All network communication is encrypted
3. **Access Control**: Only authorized users can perform operations
4. **Audit Trail**: Complete transaction history is maintained
5. **Data Integrity**: Blockchain ensures data immutability

## Troubleshooting

### Common Issues

1. **Network startup fails**
   - Ensure Docker is running
   - Check port availability (7050, 7051, 9051, 8080)
   - Verify crypto material is generated

2. **API Gateway connection fails**
   - Verify network is running
   - Check crypto paths in API configuration
   - Ensure chaincode is deployed

3. **Chaincode deployment fails**
   - Check Go version compatibility
   - Verify chaincode syntax
   - Ensure network is properly initialized

### Logs

View container logs:
```bash
# Network logs
docker logs peer0.org1.example.com
docker logs orderer.example.com

# API Gateway logs
docker logs api-gateway
```

## Development

### Adding New Features

1. **Smart Contract**: Modify `chaincode/asset-management/assetTransfer.go`
2. **API Endpoints**: Update `api-gateway/main.go`
3. **Tests**: Add tests in respective test files
4. **Documentation**: Update this README

### Building from Source

```bash
# Build chaincode
cd chaincode/asset-management
go mod tidy
go build

# Build API Gateway
cd api-gateway
go mod tidy
go build
```

## License

This project is licensed under the Apache License 2.0 - see the LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review Hyperledger Fabric documentation
3. Open an issue in the repository
