package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

// Asset represents a simple asset for demonstration
type Asset struct {
	MSISDN      string    `json:"msisdn"`
	DealerID    string    `json:"dealerId"`
	MPIN        string    `json:"mpin,omitempty"`
	Balance     float64   `json:"balance"`
	Status      string    `json:"status"`
	TransAmount float64   `json:"transAmount"`
	TransType   string    `json:"transType"`
	Remarks     string    `json:"remarks"`
	CreatedAt   time.Time `json:"createdAt"`
	UpdatedAt   time.Time `json:"updatedAt"`
}

// In-memory storage for demonstration
var assets = map[string]Asset{
	"1234567890": {
		MSISDN:      "1234567890",
		DealerID:    "DEALER001",
		Balance:     1000.0,
		Status:      "ACTIVE",
		TransAmount: 0,
		TransType:   "INITIAL",
		Remarks:     "Initial demo asset",
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	},
	"1234567891": {
		MSISDN:      "1234567891",
		DealerID:    "DEALER002",
		Balance:     2000.0,
		Status:      "ACTIVE",
		TransAmount: 0,
		TransType:   "INITIAL",
		Remarks:     "Second demo asset",
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	},
}

func main() {
	// Set Gin to release mode for cleaner output
	gin.SetMode(gin.ReleaseMode)
	
	router := gin.Default()

	// CORS middleware
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

	// Health check
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "healthy",
			"message": "Hyperledger Fabric Asset Management System is running",
			"time":    time.Now().Format(time.RFC3339),
			"version": "1.0.0",
		})
	})

	// API routes
	api := router.Group("/api/v1")
	{
		// Get all assets
		api.GET("/assets", func(c *gin.Context) {
			var assetList []Asset
			for _, asset := range assets {
				// Remove MPIN from response for security
				asset.MPIN = ""
				assetList = append(assetList, asset)
			}
			c.JSON(http.StatusOK, assetList)
		})

		// Get specific asset
		api.GET("/assets/:msisdn", func(c *gin.Context) {
			msisdn := c.Param("msisdn")
			if asset, exists := assets[msisdn]; exists {
				asset.MPIN = "" // Remove MPIN for security
				c.JSON(http.StatusOK, asset)
			} else {
				c.JSON(http.StatusNotFound, gin.H{"error": "Asset not found"})
			}
		})

		// Create asset
		api.POST("/assets", func(c *gin.Context) {
			var newAsset Asset
			if err := c.ShouldBindJSON(&newAsset); err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
				return
			}

			// Check if asset already exists
			if _, exists := assets[newAsset.MSISDN]; exists {
				c.JSON(http.StatusConflict, gin.H{"error": "Asset already exists"})
				return
			}

			// Set timestamps
			newAsset.CreatedAt = time.Now()
			newAsset.UpdatedAt = time.Now()
			newAsset.TransType = "CREATE"

			// Store asset
			assets[newAsset.MSISDN] = newAsset

			c.JSON(http.StatusCreated, gin.H{
				"message": "Asset created successfully",
				"msisdn":  newAsset.MSISDN,
			})
		})

		// Update balance
		api.PUT("/assets/:msisdn/balance", func(c *gin.Context) {
			msisdn := c.Param("msisdn")
			
			var request struct {
				MPIN      string  `json:"mpin" binding:"required"`
				Amount    float64 `json:"amount" binding:"required"`
				TransType string  `json:"transType" binding:"required"`
				Remarks   string  `json:"remarks"`
			}

			if err := c.ShouldBindJSON(&request); err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
				return
			}

			asset, exists := assets[msisdn]
			if !exists {
				c.JSON(http.StatusNotFound, gin.H{"error": "Asset not found"})
				return
			}

			// Simulate MPIN verification (in real system, this would be properly hashed)
			if asset.MPIN != request.MPIN {
				c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid MPIN"})
				return
			}

			// Update balance based on transaction type
			switch request.TransType {
			case "CREDIT":
				asset.Balance += request.Amount
			case "DEBIT":
				if asset.Balance < request.Amount {
					c.JSON(http.StatusBadRequest, gin.H{
						"error": fmt.Sprintf("Insufficient balance. Current: %.2f, Requested: %.2f", 
							asset.Balance, request.Amount),
					})
					return
				}
				asset.Balance -= request.Amount
			default:
				c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid transaction type"})
				return
			}

			// Update asset
			asset.TransAmount = request.Amount
			asset.TransType = request.TransType
			asset.Remarks = request.Remarks
			asset.UpdatedAt = time.Now()
			assets[msisdn] = asset

			c.JSON(http.StatusOK, gin.H{
				"message":    "Balance updated successfully",
				"newBalance": asset.Balance,
			})
		})

		// Update status
		api.PUT("/assets/:msisdn/status", func(c *gin.Context) {
			msisdn := c.Param("msisdn")
			
			var request struct {
				Status  string `json:"status" binding:"required"`
				Remarks string `json:"remarks"`
			}

			if err := c.ShouldBindJSON(&request); err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
				return
			}

			asset, exists := assets[msisdn]
			if !exists {
				c.JSON(http.StatusNotFound, gin.H{"error": "Asset not found"})
				return
			}

			asset.Status = request.Status
			asset.Remarks = request.Remarks
			asset.UpdatedAt = time.Now()
			assets[msisdn] = asset

			c.JSON(http.StatusOK, gin.H{"message": "Status updated successfully"})
		})

		// Delete asset
		api.DELETE("/assets/:msisdn", func(c *gin.Context) {
			msisdn := c.Param("msisdn")
			
			if _, exists := assets[msisdn]; !exists {
				c.JSON(http.StatusNotFound, gin.H{"error": "Asset not found"})
				return
			}

			delete(assets, msisdn)
			c.JSON(http.StatusOK, gin.H{"message": "Asset deleted successfully"})
		})

		// Initialize ledger
		api.POST("/ledger/init", func(c *gin.Context) {
			// Reset to initial state
			assets = map[string]Asset{
				"1234567890": {
					MSISDN:      "1234567890",
					DealerID:    "DEALER001",
					MPIN:        "1234",
					Balance:     1000.0,
					Status:      "ACTIVE",
					TransAmount: 0,
					TransType:   "INITIAL",
					Remarks:     "Initial demo asset",
					CreatedAt:   time.Now(),
					UpdatedAt:   time.Now(),
				},
				"1234567891": {
					MSISDN:      "1234567891",
					DealerID:    "DEALER002",
					MPIN:        "5678",
					Balance:     2000.0,
					Status:      "ACTIVE",
					TransAmount: 0,
					TransType:   "INITIAL",
					Remarks:     "Second demo asset",
					CreatedAt:   time.Now(),
					UpdatedAt:   time.Now(),
				},
			}

			c.JSON(http.StatusOK, gin.H{
				"message": "Ledger initialized successfully",
				"assets":  len(assets),
			})
		})

		// Get transaction history (simplified)
		api.GET("/assets/:msisdn/transactions", func(c *gin.Context) {
			msisdn := c.Param("msisdn")
			
			if _, exists := assets[msisdn]; !exists {
				c.JSON(http.StatusNotFound, gin.H{"error": "Asset not found"})
				return
			}

			// Simulate transaction history
			transactions := []map[string]interface{}{
				{
					"id":          fmt.Sprintf("%s-CREATE-%d", msisdn, time.Now().Unix()),
					"assetId":     msisdn,
					"transType":   "CREATE",
					"amount":      1000.0,
					"prevBalance": 0.0,
					"newBalance":  1000.0,
					"remarks":     "Account creation",
					"timestamp":   time.Now().Format(time.RFC3339),
				},
			}

			c.JSON(http.StatusOK, transactions)
		})
	}

	// Start server
	fmt.Println("🚀 Hyperledger Fabric Asset Management System")
	fmt.Println("📡 API Server starting on http://localhost:8080")
	fmt.Println("🏥 Health check: http://localhost:8080/health")
	fmt.Println("📊 Assets API: http://localhost:8080/api/v1/assets")
	fmt.Println("⏹️  Press Ctrl+C to stop")
	
	log.Fatal(router.Run(":8080"))
}
