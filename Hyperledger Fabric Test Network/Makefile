# Hyperledger Fabric Asset Management System Makefile

.PHONY: help setup start stop restart clean test deploy-cc init-ledger test-api build-api logs demo check-status web-demo

# Default target
help:
	@echo "Hyperledger Fabric Asset Management System"
	@echo "Available commands:"
	@echo "  setup       - Generate crypto material and setup network"
	@echo "  start       - Start the Fabric network"
	@echo "  stop        - Stop the Fabric network"
	@echo "  restart     - Restart the Fabric network"
	@echo "  clean       - Clean up all containers and volumes"
	@echo "  deploy-cc   - Deploy the asset management chaincode"
	@echo "  init-ledger - Initialize the ledger with sample data"
	@echo "  build-api   - Build the API gateway"
	@echo "  start-api   - Start the API gateway"
	@echo "  test-api    - Run API tests"
	@echo "  test-cc     - Run chaincode unit tests"
	@echo "  logs        - Show logs from all containers"
	@echo "  full-deploy - Complete deployment (setup + start + deploy-cc + start-api)"
	@echo "  demo        - Run comprehensive system demonstration"
	@echo "  check-status- Quick status check"
	@echo "  web-demo    - Open web-based demo interface"

# Generate crypto material and setup network
setup:
	@echo "Setting up Hyperledger Fabric network..."
	./network.sh generate
	@echo "Network setup complete!"

# Start the Fabric network
start:
	@echo "Starting Hyperledger Fabric network..."
	./network.sh up
	./network.sh createChannel
	@echo "Network started successfully!"

# Stop the Fabric network
stop:
	@echo "Stopping Hyperledger Fabric network..."
	./network.sh down
	@echo "Network stopped!"

# Restart the network
restart: stop start

# Clean up everything
clean:
	@echo "Cleaning up containers and volumes..."
	./network.sh down
	docker system prune -f
	docker volume prune -f
	@echo "Cleanup complete!"

# Deploy chaincode
deploy-cc:
	@echo "Deploying asset management chaincode..."
	./scripts/deployCC.sh
	@echo "Chaincode deployed successfully!"

# Initialize ledger
init-ledger:
	@echo "Initializing ledger..."
	curl -X POST http://localhost:8080/api/v1/ledger/init
	@echo "Ledger initialized!"

# Build API gateway
build-api:
	@echo "Building API gateway..."
	cd api-gateway && go mod tidy && go build -o api-gateway main.go
	@echo "API gateway built successfully!"

# Start API gateway using Docker Compose
start-api:
	@echo "Starting API gateway..."
	docker-compose -f docker-compose-api.yaml up -d api-gateway
	@echo "API gateway started on port 8080!"

# Stop API gateway
stop-api:
	@echo "Stopping API gateway..."
	docker-compose -f docker-compose-api.yaml down
	@echo "API gateway stopped!"

# Run API tests
test-api:
	@echo "Running API tests..."
	chmod +x test-api.sh
	./test-api.sh

# Run chaincode unit tests
test-cc:
	@echo "Running chaincode unit tests..."
	cd chaincode/asset-management && go test -v

# Show logs from all containers
logs:
	@echo "Showing logs from all containers..."
	@echo "=== Orderer Logs ==="
	docker logs orderer.example.com --tail 50
	@echo "=== Peer0 Org1 Logs ==="
	docker logs peer0.org1.example.com --tail 50
	@echo "=== Peer0 Org2 Logs ==="
	docker logs peer0.org2.example.com --tail 50
	@echo "=== API Gateway Logs ==="
	docker logs api-gateway --tail 50 2>/dev/null || echo "API Gateway not running"

# Complete deployment
full-deploy: setup start deploy-cc start-api init-ledger
	@echo "Full deployment complete!"
	@echo "API Gateway is running on http://localhost:8080"
	@echo "Run 'make test-api' to test the system"

# Development helpers
dev-setup:
	@echo "Setting up development environment..."
	cd chaincode/asset-management && go mod tidy
	cd api-gateway && go mod tidy
	@echo "Development environment ready!"

# Check system status
status:
	@echo "System Status:"
	@echo "=============="
	@echo "Docker containers:"
	@docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
	@echo ""
	@echo "API Health Check:"
	@curl -s http://localhost:8080/health 2>/dev/null && echo "✓ API is healthy" || echo "✗ API is not responding"

# Backup the system
backup:
	@echo "Creating system backup..."
	@DATE=$$(date +%Y%m%d_%H%M%S) && \
	mkdir -p backup_$$DATE && \
	cp -r organizations backup_$$DATE/ 2>/dev/null || true && \
	cp -r channel-artifacts backup_$$DATE/ 2>/dev/null || true && \
	cp -r system-genesis-block backup_$$DATE/ 2>/dev/null || true && \
	tar -czf backup_$$DATE.tar.gz backup_$$DATE && \
	rm -rf backup_$$DATE && \
	echo "Backup created: backup_$$DATE.tar.gz"

# Monitor system resources
monitor:
	@echo "System Resource Usage:"
	@echo "====================="
	@docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

# Run comprehensive demonstration
demo:
	@echo "Running comprehensive system demonstration..."
	chmod +x demo-system.sh
	./demo-system.sh

# Quick status check
check-status:
	@echo "Running quick status check..."
	chmod +x check-status.sh
	./check-status.sh

# Open web-based demo
web-demo:
	@echo "Opening web-based demo interface..."
	@echo "Make sure the system is running first!"
	@echo "Web demo will be available at: file://$(PWD)/web-demo/index.html"
	@if command -v python3 >/dev/null 2>&1; then \
		echo "Starting local web server..."; \
		cd web-demo && python3 -m http.server 3000 & \
		echo "Web demo available at: http://localhost:3000"; \
	elif command -v python >/dev/null 2>&1; then \
		echo "Starting local web server..."; \
		cd web-demo && python -m SimpleHTTPServer 3000 & \
		echo "Web demo available at: http://localhost:3000"; \
	else \
		echo "Open web-demo/index.html in your browser"; \
	fi

# Verify system is working
verify:
	@echo "Verifying system functionality..."
	@make check-status
	@echo ""
	@echo "For comprehensive verification, run: make demo"
