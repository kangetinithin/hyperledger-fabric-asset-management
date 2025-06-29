@echo off
echo ==========================================
echo Hyperledger Fabric Asset Management System
echo Simple Demo Server
echo ==========================================
echo.

echo [INFO] Starting simple API server for demonstration...
echo.

REM Check if Go is installed
go version >nul 2>&1
if %errorlevel% equ 0 (
    echo [SUCCESS] Go is installed
    echo [INFO] Starting Go-based API server...
    cd simple-api
    go mod tidy
    echo.
    echo ==========================================
    echo SERVER STARTING
    echo ==========================================
    echo API Gateway: http://localhost:8080
    echo Health Check: http://localhost:8080/health
    echo Assets API: http://localhost:8080/api/v1/assets
    echo ==========================================
    echo.
    go run main.go
) else (
    echo [WARNING] Go not found, trying Node.js...
    
    REM Check if Node.js is available
    node --version >nul 2>&1
    if %errorlevel% equ 0 (
        echo [SUCCESS] Node.js is installed
        echo [INFO] Creating Node.js server...
        
        REM Create package.json
        echo { > package.json
        echo   "name": "fabric-demo-api", >> package.json
        echo   "version": "1.0.0", >> package.json
        echo   "main": "server.js", >> package.json
        echo   "dependencies": { >> package.json
        echo     "express": "^4.18.0" >> package.json
        echo   } >> package.json
        echo } >> package.json
        
        REM Create simple Express server
        echo const express = require('express'); > server.js
        echo const app = express(); >> server.js
        echo app.use(express.json()); >> server.js
        echo. >> server.js
        echo // CORS middleware >> server.js
        echo app.use((req, res, next) => { >> server.js
        echo   res.header('Access-Control-Allow-Origin', '*'); >> server.js
        echo   res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS'); >> server.js
        echo   res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization'); >> server.js
        echo   if (req.method === 'OPTIONS') return res.sendStatus(204); >> server.js
        echo   next(); >> server.js
        echo }); >> server.js
        echo. >> server.js
        echo // Sample data >> server.js
        echo let assets = { >> server.js
        echo   '1234567890': { msisdn: '1234567890', dealerId: 'DEALER001', balance: 1000, status: 'ACTIVE', mpin: '1234' }, >> server.js
        echo   '1234567891': { msisdn: '1234567891', dealerId: 'DEALER002', balance: 2000, status: 'ACTIVE', mpin: '5678' } >> server.js
        echo }; >> server.js
        echo. >> server.js
        echo // Routes >> server.js
        echo app.get('/health', (req, res) => res.json({status: 'healthy', message: 'Hyperledger Fabric Asset Management System is running'})); >> server.js
        echo app.get('/api/v1/assets', (req, res) => { >> server.js
        echo   const result = Object.values(assets).map(a => ({...a, mpin: undefined})); >> server.js
        echo   res.json(result); >> server.js
        echo }); >> server.js
        echo app.get('/api/v1/assets/:msisdn', (req, res) => { >> server.js
        echo   const asset = assets[req.params.msisdn]; >> server.js
        echo   if (!asset) return res.status(404).json({error: 'Asset not found'}); >> server.js
        echo   res.json({...asset, mpin: undefined}); >> server.js
        echo }); >> server.js
        echo app.post('/api/v1/assets', (req, res) => { >> server.js
        echo   const {msisdn, dealerId, mpin, balance, status} = req.body; >> server.js
        echo   if (assets[msisdn]) return res.status(409).json({error: 'Asset already exists'}); >> server.js
        echo   assets[msisdn] = {msisdn, dealerId, mpin, balance, status, createdAt: new Date()}; >> server.js
        echo   res.status(201).json({message: 'Asset created successfully'}); >> server.js
        echo }); >> server.js
        echo app.post('/api/v1/ledger/init', (req, res) => res.json({message: 'Ledger initialized successfully'})); >> server.js
        echo. >> server.js
        echo const PORT = 8080; >> server.js
        echo app.listen(PORT, () => { >> server.js
        echo   console.log('🚀 Hyperledger Fabric Asset Management System'); >> server.js
        echo   console.log(`📡 API Server running on http://localhost:${PORT}`); >> server.js
        echo   console.log(`🏥 Health check: http://localhost:${PORT}/health`); >> server.js
        echo   console.log(`📊 Assets API: http://localhost:${PORT}/api/v1/assets`); >> server.js
        echo   console.log('⏹️  Press Ctrl+C to stop'); >> server.js
        echo }); >> server.js
        
        echo [INFO] Installing dependencies...
        npm install express
        
        echo.
        echo ==========================================
        echo SERVER STARTING
        echo ==========================================
        echo API Gateway: http://localhost:8080
        echo Health Check: http://localhost:8080/health
        echo Assets API: http://localhost:8080/api/v1/assets
        echo ==========================================
        echo.
        node server.js
    ) else (
        echo [ERROR] Neither Go nor Node.js found
        echo.
        echo Please install one of the following:
        echo 1. Go: https://golang.org/dl/
        echo 2. Node.js: https://nodejs.org/
        echo.
        echo Or use the Python version:
        echo python -m http.server 8080
        echo.
        pause
        exit /b 1
    )
)

pause
