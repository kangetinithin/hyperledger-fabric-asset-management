package main

import (
	"encoding/json"
	"fmt"
	"log"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// SmartContract provides functions for managing an Asset
type SmartContract struct {
	contractapi.Contract
}

// Asset describes basic details of what makes up a simple asset
// Insert struct field in alphabetic order => to achieve determinism across languages
// golang keeps the order when marshal to json but doesn't order automatically
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

// InitLedger adds a base set of assets to the ledger
func (s *SmartContract) InitLedger(ctx contractapi.TransactionContextInterface) error {
	assets := []Asset{
		{DealerID: "DEALER001", MSISDN: "1234567890", MPIN: "1234", Balance: 1000.0, Status: "ACTIVE", TransAmount: 0, TransType: "INITIAL", Remarks: "Initial balance", CreatedAt: time.Now(), UpdatedAt: time.Now()},
		{DealerID: "DEALER002", MSISDN: "1234567891", MPIN: "5678", Balance: 2000.0, Status: "ACTIVE", TransAmount: 0, TransType: "INITIAL", Remarks: "Initial balance", CreatedAt: time.Now(), UpdatedAt: time.Now()},
		{DealerID: "DEALER003", MSISDN: "1234567892", MPIN: "9012", Balance: 1500.0, Status: "ACTIVE", TransAmount: 0, TransType: "INITIAL", Remarks: "Initial balance", CreatedAt: time.Now(), UpdatedAt: time.Now()},
	}

	for _, asset := range assets {
		assetJSON, err := json.Marshal(asset)
		if err != nil {
			return err
		}

		err = ctx.GetStub().PutState(asset.MSISDN, assetJSON)
		if err != nil {
			return fmt.Errorf("failed to put to world state. %v", err)
		}
	}

	return nil
}

// CreateAsset issues a new asset to the world state with given details.
func (s *SmartContract) CreateAsset(ctx contractapi.TransactionContextInterface, msisdn, dealerId, mpin string, balance float64, status, remarks string) error {
	exists, err := s.AssetExists(ctx, msisdn)
	if err != nil {
		return err
	}
	if exists {
		return fmt.Errorf("the asset %s already exists", msisdn)
	}

	asset := Asset{
		DealerID:    dealerId,
		MSISDN:      msisdn,
		MPIN:        mpin,
		Balance:     balance,
		Status:      status,
		TransAmount: 0,
		TransType:   "CREATE",
		Remarks:     remarks,
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}
	assetJSON, err := json.Marshal(asset)
	if err != nil {
		return err
	}

	err = ctx.GetStub().PutState(msisdn, assetJSON)
	if err != nil {
		return err
	}

	// Record the creation transaction
	txID := ctx.GetStub().GetTxID()
	transaction := Transaction{
		ID:          fmt.Sprintf("%s-CREATE-%d", msisdn, time.Now().Unix()),
		AssetID:     msisdn,
		TransType:   "CREATE",
		Amount:      balance,
		PrevBalance: 0,
		NewBalance:  balance,
		Remarks:     remarks,
		Timestamp:   time.Now(),
		TxID:        txID,
	}

	return s.recordTransaction(ctx, transaction)
}

// ReadAsset returns the asset stored in the world state with given id.
func (s *SmartContract) ReadAsset(ctx contractapi.TransactionContextInterface, msisdn string) (*Asset, error) {
	assetJSON, err := ctx.GetStub().GetState(msisdn)
	if err != nil {
		return nil, fmt.Errorf("failed to read from world state: %v", err)
	}
	if assetJSON == nil {
		return nil, fmt.Errorf("the asset %s does not exist", msisdn)
	}

	var asset Asset
	err = json.Unmarshal(assetJSON, &asset)
	if err != nil {
		return nil, err
	}

	return &asset, nil
}

// UpdateAssetBalance updates the balance of an existing asset in the world state.
func (s *SmartContract) UpdateAssetBalance(ctx contractapi.TransactionContextInterface, msisdn, mpin string, amount float64, transType, remarks string) error {
	asset, err := s.ReadAsset(ctx, msisdn)
	if err != nil {
		return err
	}

	// Verify MPIN
	if asset.MPIN != mpin {
		return fmt.Errorf("invalid MPIN for asset %s", msisdn)
	}

	// Check if account is active
	if asset.Status != "ACTIVE" {
		return fmt.Errorf("account %s is not active", msisdn)
	}

	prevBalance := asset.Balance

	// Update balance based on transaction type
	switch transType {
	case "CREDIT":
		asset.Balance += amount
	case "DEBIT":
		if asset.Balance < amount {
			return fmt.Errorf("insufficient balance. Current balance: %.2f, Requested: %.2f", asset.Balance, amount)
		}
		asset.Balance -= amount
	default:
		return fmt.Errorf("invalid transaction type: %s", transType)
	}

	asset.TransAmount = amount
	asset.TransType = transType
	asset.Remarks = remarks
	asset.UpdatedAt = time.Now()

	assetJSON, err := json.Marshal(asset)
	if err != nil {
		return err
	}

	err = ctx.GetStub().PutState(msisdn, assetJSON)
	if err != nil {
		return err
	}

	// Record the transaction
	txID := ctx.GetStub().GetTxID()
	transaction := Transaction{
		ID:          fmt.Sprintf("%s-%s-%d", msisdn, transType, time.Now().Unix()),
		AssetID:     msisdn,
		TransType:   transType,
		Amount:      amount,
		PrevBalance: prevBalance,
		NewBalance:  asset.Balance,
		Remarks:     remarks,
		Timestamp:   time.Now(),
		TxID:        txID,
	}

	return s.recordTransaction(ctx, transaction)
}

// UpdateAssetStatus updates the status of an existing asset.
func (s *SmartContract) UpdateAssetStatus(ctx contractapi.TransactionContextInterface, msisdn, newStatus, remarks string) error {
	asset, err := s.ReadAsset(ctx, msisdn)
	if err != nil {
		return err
	}

	asset.Status = newStatus
	asset.Remarks = remarks
	asset.UpdatedAt = time.Now()

	assetJSON, err := json.Marshal(asset)
	if err != nil {
		return err
	}

	return ctx.GetStub().PutState(msisdn, assetJSON)
}

// DeleteAsset deletes an given asset from the world state.
func (s *SmartContract) DeleteAsset(ctx contractapi.TransactionContextInterface, msisdn string) error {
	exists, err := s.AssetExists(ctx, msisdn)
	if err != nil {
		return err
	}
	if !exists {
		return fmt.Errorf("the asset %s does not exist", msisdn)
	}

	return ctx.GetStub().DelState(msisdn)
}

// AssetExists returns true when asset with given ID exists in world state
func (s *SmartContract) AssetExists(ctx contractapi.TransactionContextInterface, msisdn string) (bool, error) {
	assetJSON, err := ctx.GetStub().GetState(msisdn)
	if err != nil {
		return false, fmt.Errorf("failed to read from world state: %v", err)
	}

	return assetJSON != nil, nil
}

// GetAllAssets returns all assets found in world state
func (s *SmartContract) GetAllAssets(ctx contractapi.TransactionContextInterface) ([]*Asset, error) {
	// range query with empty string for startKey and endKey does an
	// open-ended query of all assets in the chaincode namespace.
	resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
	if err != nil {
		return nil, err
	}
	defer resultsIterator.Close()

	var assets []*Asset
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, err
		}

		var asset Asset
		err = json.Unmarshal(queryResponse.Value, &asset)
		if err != nil {
			return nil, err
		}
		assets = append(assets, &asset)
	}

	return assets, nil
}

// recordTransaction records a transaction in the ledger
func (s *SmartContract) recordTransaction(ctx contractapi.TransactionContextInterface, transaction Transaction) error {
	transactionJSON, err := json.Marshal(transaction)
	if err != nil {
		return err
	}

	transactionKey := fmt.Sprintf("TXN_%s", transaction.ID)
	return ctx.GetStub().PutState(transactionKey, transactionJSON)
}

// GetTransactionHistory returns the transaction history for a given asset
func (s *SmartContract) GetTransactionHistory(ctx contractapi.TransactionContextInterface, msisdn string) ([]*Transaction, error) {
	// Use range query to get all transaction records for this asset
	startKey := fmt.Sprintf("TXN_%s-", msisdn)
	endKey := fmt.Sprintf("TXN_%s~", msisdn)

	resultsIterator, err := ctx.GetStub().GetStateByRange(startKey, endKey)
	if err != nil {
		return nil, err
	}
	defer resultsIterator.Close()

	var transactions []*Transaction
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, err
		}

		var transaction Transaction
		err = json.Unmarshal(queryResponse.Value, &transaction)
		if err != nil {
			return nil, err
		}
		transactions = append(transactions, &transaction)
	}

	return transactions, nil
}

func main() {
	assetChaincode, err := contractapi.NewChaincode(&SmartContract{})
	if err != nil {
		log.Panicf("Error creating asset-transfer-basic chaincode: %v", err)
	}

	if err := assetChaincode.Start(); err != nil {
		log.Panicf("Error starting asset-transfer-basic chaincode: %v", err)
	}
}
