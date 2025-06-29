package main

import (
	"crypto/x509"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"path"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/hyperledger/fabric-gateway/pkg/client"
	"github.com/hyperledger/fabric-gateway/pkg/identity"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
)

const (
	mspID        = "Org1MSP"
	cryptoPath   = "../organizations/peerOrganizations/org1.example.com"
	certPath     = cryptoPath + "/users/User1@org1.example.com/msp/signcerts/cert.pem"
	keyPath      = cryptoPath + "/users/User1@org1.example.com/msp/keystore/"
	tlsCertPath  = cryptoPath + "/peers/peer0.org1.example.com/tls/ca.crt"
	peerEndpoint = "localhost:7051"
	gatewayPeer  = "peer0.org1.example.com"
)

var (
	contract *client.Contract
)

// Asset represents the asset structure
type Asset struct {
	Balance      float64   `json:"balance"`
	DealerID     string    `json:"dealerId"`
	MPIN         string    `json:"mpin"`
	MSISDN       string    `json:"msisdn"`
	Remarks      string    `json:"remarks"`
	Status       string    `json:"status"`
	TransAmount  float64   `json:"transAmount"`
	TransType    string    `json:"transType"`
	CreatedAt    time.Time `json:"createdAt"`
	UpdatedAt    time.Time `json:"updatedAt"`
}

// Transaction represents a transaction history entry
type Transaction struct {
	ID          string    `json:"id"`
	AssetID     string    `json:"assetId"`
	TransType   string    `json:"transType"`
	Amount      float64   `json:"amount"`
	PrevBalance float64   `json:"prevBalance"`
	NewBalance  float64   `json:"newBalance"`
	Remarks     string    `json:"remarks"`
	Timestamp   time.Time `json:"timestamp"`
	TxID        string    `json:"txId"`
}

// CreateAssetRequest represents the request body for creating an asset
type CreateAssetRequest struct {
	MSISDN   string  `json:"msisdn" binding:"required"`
	DealerID string  `json:"dealerId" binding:"required"`
	MPIN     string  `json:"mpin" binding:"required"`
	Balance  float64 `json:"balance" binding:"required"`
	Status   string  `json:"status" binding:"required"`
	Remarks  string  `json:"remarks"`
}

// UpdateBalanceRequest represents the request body for updating balance
type UpdateBalanceRequest struct {
	MPIN      string  `json:"mpin" binding:"required"`
	Amount    float64 `json:"amount" binding:"required"`
	TransType string  `json:"transType" binding:"required"`
	Remarks   string  `json:"remarks"`
}

// UpdateStatusRequest represents the request body for updating status
type UpdateStatusRequest struct {
	Status  string `json:"status" binding:"required"`
	Remarks string `json:"remarks"`
}

func main() {
	// Initialize the gateway connection
	err := initGateway()
	if err != nil {
		log.Fatalf("Failed to initialize gateway: %v", err)
	}

	// Setup Gin router
	router := gin.Default()

	// Add CORS middleware
	router.Use(func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	})

	// API routes
	api := router.Group("/api/v1")
	{
		api.POST("/assets", createAsset)
		api.GET("/assets/:msisdn", getAsset)
		api.GET("/assets", getAllAssets)
		api.PUT("/assets/:msisdn/balance", updateBalance)
		api.PUT("/assets/:msisdn/status", updateStatus)
		api.DELETE("/assets/:msisdn", deleteAsset)
		api.GET("/assets/:msisdn/transactions", getTransactionHistory)
		api.POST("/ledger/init", initLedger)
	}

	// Health check endpoint
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "healthy"})
	})

	// Start server
	log.Println("Starting API Gateway on port 8080...")
	log.Fatal(router.Run(":8080"))
}

func initGateway() error {
	// Load client certificate
	clientCertPem, err := ioutil.ReadFile(certPath)
	if err != nil {
		return fmt.Errorf("failed to read client certificate: %w", err)
	}

	clientCert, err := identity.CertificateFromPEM(clientCertPem)
	if err != nil {
		return fmt.Errorf("failed to parse client certificate: %w", err)
	}

	// Load client private key
	keyDir, err := ioutil.ReadDir(keyPath)
	if err != nil {
		return fmt.Errorf("failed to read private key directory: %w", err)
	}

	if len(keyDir) == 0 {
		return fmt.Errorf("no private key files found in %s", keyPath)
	}

	keyFile := path.Join(keyPath, keyDir[0].Name())
	clientKeyPem, err := ioutil.ReadFile(keyFile)
	if err != nil {
		return fmt.Errorf("failed to read private key: %w", err)
	}

	clientKey, err := identity.PrivateKeyFromPEM(clientKeyPem)
	if err != nil {
		return fmt.Errorf("failed to parse private key: %w", err)
	}

	// Load TLS certificate
	tlsCertPem, err := ioutil.ReadFile(tlsCertPath)
	if err != nil {
		return fmt.Errorf("failed to read TLS certificate: %w", err)
	}

	tlsCert, err := identity.CertificateFromPEM(tlsCertPem)
	if err != nil {
		return fmt.Errorf("failed to parse TLS certificate: %w", err)
	}

	// Create gRPC connection
	certPool := x509.NewCertPool()
	certPool.AddCert(tlsCert)
	transportCredentials := credentials.NewClientTLSFromCert(certPool, gatewayPeer)

	connection, err := grpc.Dial(peerEndpoint, grpc.WithTransportCredentials(transportCredentials))
	if err != nil {
		return fmt.Errorf("failed to create gRPC connection: %w", err)
	}

	// Create client identity
	id := identity.NewX509Identity(mspID, clientCert, clientKey)

	// Create gateway
	gw, err := client.Connect(
		id,
		client.WithSign(identity.NewPrivateKeySign(clientKey)),
		client.WithHash(identity.SHA256),
		client.WithClientConnection(connection),
		client.WithEvaluateTimeout(5*time.Second),
		client.WithEndorseTimeout(15*time.Second),
		client.WithSubmitTimeout(5*time.Second),
		client.WithCommitStatusTimeout(1*time.Minute),
	)
	if err != nil {
		return fmt.Errorf("failed to connect to gateway: %w", err)
	}

	// Get network and contract
	network := gw.GetNetwork("mychannel")
	contract = network.GetContract("basic")

	return nil
}

// API Handlers

func createAsset(c *gin.Context) {
	var req CreateAssetRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	_, err := contract.SubmitTransaction("CreateAsset", req.MSISDN, req.DealerID, req.MPIN, 
		fmt.Sprintf("%.2f", req.Balance), req.Status, req.Remarks)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"message": "Asset created successfully"})
}

func getAsset(c *gin.Context) {
	msisdn := c.Param("msisdn")

	result, err := contract.EvaluateTransaction("ReadAsset", msisdn)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}

	c.Data(http.StatusOK, "application/json", result)
}

func getAllAssets(c *gin.Context) {
	result, err := contract.EvaluateTransaction("GetAllAssets")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.Data(http.StatusOK, "application/json", result)
}

func updateBalance(c *gin.Context) {
	msisdn := c.Param("msisdn")
	var req UpdateBalanceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	_, err := contract.SubmitTransaction("UpdateAssetBalance", msisdn, req.MPIN, 
		fmt.Sprintf("%.2f", req.Amount), req.TransType, req.Remarks)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Balance updated successfully"})
}

func updateStatus(c *gin.Context) {
	msisdn := c.Param("msisdn")
	var req UpdateStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	_, err := contract.SubmitTransaction("UpdateAssetStatus", msisdn, req.Status, req.Remarks)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Status updated successfully"})
}

func deleteAsset(c *gin.Context) {
	msisdn := c.Param("msisdn")

	_, err := contract.SubmitTransaction("DeleteAsset", msisdn)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Asset deleted successfully"})
}

func getTransactionHistory(c *gin.Context) {
	msisdn := c.Param("msisdn")

	result, err := contract.EvaluateTransaction("GetTransactionHistory", msisdn)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.Data(http.StatusOK, "application/json", result)
}

func initLedger(c *gin.Context) {
	_, err := contract.SubmitTransaction("InitLedger")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Ledger initialized successfully"})
}
