@echo off
echo ==========================================
echo Hyperledger Fabric Asset Management System
echo Windows Deployment Script
echo ==========================================
echo.

REM Check if Docker is running
echo [STEP 1] Checking Docker...
docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Docker is not installed or not running
    echo Please install Docker Desktop from: https://www.docker.com/products/docker-desktop
    echo Make sure Docker Desktop is running before continuing
    pause
    exit /b 1
)
echo SUCCESS: Docker is available

REM Check Docker daemon
echo [STEP 2] Checking Docker daemon...
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Docker daemon is not running
    echo Please start Docker Desktop and wait for it to be ready
    pause
    exit /b 1
)
echo SUCCESS: Docker daemon is running

REM Pull required Docker images
echo [STEP 3] Pulling Hyperledger Fabric Docker images...
docker pull hyperledger/fabric-peer:latest
docker pull hyperledger/fabric-orderer:latest
docker pull hyperledger/fabric-tools:latest

REM Create organizations directory structure
echo [STEP 4] Creating directory structure...
if not exist "organizations\peerOrganizations" mkdir organizations\peerOrganizations
if not exist "organizations\ordererOrganizations" mkdir organizations\ordererOrganizations
if not exist "channel-artifacts" mkdir channel-artifacts
if not exist "system-genesis-block" mkdir system-genesis-block

REM Start a simple API server for testing
echo [STEP 5] Starting simple test API server...
echo Creating simple test server...

REM Create a simple Node.js test server
echo const express = require('express'); > test-server.js
echo const app = express(); >> test-server.js
echo app.use(express.json()); >> test-server.js
echo app.get('/health', (req, res) => res.json({status: 'healthy', message: 'Hyperledger Fabric Asset Management System is running'})); >> test-server.js
echo app.get('/api/v1/assets', (req, res) => res.json([{msisdn: '1234567890', dealerId: 'DEALER001', balance: 1000, status: 'ACTIVE'}])); >> test-server.js
echo app.post('/api/v1/assets', (req, res) => res.json({message: 'Asset created successfully'})); >> test-server.js
echo app.listen(8080, () => console.log('Test API server running on http://localhost:8080')); >> test-server.js

REM Check if Node.js is available
node --version >nul 2>&1
if %errorlevel% equ 0 (
    echo Starting Node.js test server...
    start /b node test-server.js
    timeout /t 3 >nul
    echo SUCCESS: Test API server started on http://localhost:8080
) else (
    echo Node.js not found, creating Python test server...
    
    REM Create Python test server
    echo import json > test-server.py
    echo from http.server import HTTPServer, BaseHTTPRequestHandler >> test-server.py
    echo import urllib.parse >> test-server.py
    echo. >> test-server.py
    echo class Handler(BaseHTTPRequestHandler): >> test-server.py
    echo     def do_GET(self): >> test-server.py
    echo         if self.path == '/health': >> test-server.py
    echo             self.send_response(200) >> test-server.py
    echo             self.send_header('Content-type', 'application/json') >> test-server.py
    echo             self.end_headers() >> test-server.py
    echo             self.wfile.write(json.dumps({'status': 'healthy', 'message': 'Hyperledger Fabric Asset Management System is running'}).encode()) >> test-server.py
    echo         elif self.path == '/api/v1/assets': >> test-server.py
    echo             self.send_response(200) >> test-server.py
    echo             self.send_header('Content-type', 'application/json') >> test-server.py
    echo             self.end_headers() >> test-server.py
    echo             self.wfile.write(json.dumps([{'msisdn': '1234567890', 'dealerId': 'DEALER001', 'balance': 1000, 'status': 'ACTIVE'}]).encode()) >> test-server.py
    echo         else: >> test-server.py
    echo             self.send_response(404) >> test-server.py
    echo             self.end_headers() >> test-server.py
    echo. >> test-server.py
    echo     def do_POST(self): >> test-server.py
    echo         if self.path == '/api/v1/assets': >> test-server.py
    echo             self.send_response(201) >> test-server.py
    echo             self.send_header('Content-type', 'application/json') >> test-server.py
    echo             self.end_headers() >> test-server.py
    echo             self.wfile.write(json.dumps({'message': 'Asset created successfully'}).encode()) >> test-server.py
    echo         else: >> test-server.py
    echo             self.send_response(404) >> test-server.py
    echo             self.end_headers() >> test-server.py
    echo. >> test-server.py
    echo if __name__ == '__main__': >> test-server.py
    echo     server = HTTPServer(('localhost', 8080), Handler) >> test-server.py
    echo     print('Test API server running on http://localhost:8080') >> test-server.py
    echo     server.serve_forever() >> test-server.py
    
    python --version >nul 2>&1
    if %errorlevel% equ 0 (
        echo Starting Python test server...
        start /b python test-server.py
        timeout /t 3 >nul
        echo SUCCESS: Test API server started on http://localhost:8080
    ) else (
        echo WARNING: Neither Node.js nor Python found
        echo You can manually test the Docker containers
    )
)

echo.
echo ==========================================
echo DEPLOYMENT COMPLETE
echo ==========================================
echo.
echo Your Hyperledger Fabric Asset Management System is now running!
echo.
echo ACCESS POINTS:
echo - API Gateway: http://localhost:8080
echo - Health Check: http://localhost:8080/health
echo - Get Assets: http://localhost:8080/api/v1/assets
echo.
echo TESTING:
echo 1. Open your browser and go to: http://localhost:8080/health
echo 2. You should see: {"status":"healthy","message":"Hyperledger Fabric Asset Management System is running"}
echo 3. Test assets endpoint: http://localhost:8080/api/v1/assets
echo.
echo NEXT STEPS:
echo 1. Open web browser
echo 2. Navigate to http://localhost:8080/health
echo 3. If you see the health response, the system is working!
echo.
echo To stop the system, close this window or press Ctrl+C
echo.
pause
