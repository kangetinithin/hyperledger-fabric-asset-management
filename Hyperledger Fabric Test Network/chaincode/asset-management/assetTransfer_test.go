package main

import (
	"encoding/json"
	"fmt"
	"testing"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
	"github.com/hyperledger/fabric-chaincode-go/shim"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
)

//go:generate counterfeiter -o mocks/transaction.go -fake-name TransactionContext . transactionContext
type transactionContext interface {
	contractapi.TransactionContextInterface
}

//go:generate counterfeiter -o mocks/chaincodestub.go -fake-name ChaincodeStub . chaincodeStub
type chaincodeStub interface {
	shim.ChaincodeStubInterface
}

//go:generate counterfeiter -o mocks/statequeryiterator.go -fake-name StateQueryIterator . stateQueryIterator
type stateQueryIterator interface {
	shim.StateQueryIteratorInterface
}

func TestInitLedger(t *testing.T) {
	chaincodeStub := &mocks.ChaincodeStub{}
	transactionContext := &mocks.TransactionContext{}
	transactionContext.GetStubReturns(chaincodeStub)

	assetTransfer := SmartContract{}
	err := assetTransfer.InitLedger(transactionContext)
	assert.Nil(t, err)

	chaincodeStub.PutStateReturns(nil)
	assert.Equal(t, 3, chaincodeStub.PutStateCallCount())
}

func TestCreateAsset(t *testing.T) {
	chaincodeStub := &mocks.ChaincodeStub{}
	transactionContext := &mocks.TransactionContext{}
	transactionContext.GetStubReturns(chaincodeStub)

	assetTransfer := SmartContract{}
	
	// Test successful asset creation
	chaincodeStub.GetStateReturns(nil, nil) // Asset doesn't exist
	chaincodeStub.PutStateReturns(nil)
	chaincodeStub.GetTxIDReturns("txid123")

	err := assetTransfer.CreateAsset(transactionContext, "1234567890", "DEALER001", "1234", 1000.0, "ACTIVE", "Test asset")
	assert.Nil(t, err)

	// Test asset already exists
	existingAsset := Asset{
		DealerID: "DEALER001",
		MSISDN:   "1234567890",
		MPIN:     "1234",
		Balance:  1000.0,
		Status:   "ACTIVE",
	}
	existingAssetBytes, _ := json.Marshal(existingAsset)
	chaincodeStub.GetStateReturns(existingAssetBytes, nil)

	err = assetTransfer.CreateAsset(transactionContext, "1234567890", "DEALER001", "1234", 1000.0, "ACTIVE", "Test asset")
	assert.EqualError(t, err, "the asset 1234567890 already exists")
}

func TestReadAsset(t *testing.T) {
	chaincodeStub := &mocks.ChaincodeStub{}
	transactionContext := &mocks.TransactionContext{}
	transactionContext.GetStubReturns(chaincodeStub)

	expectedAsset := &Asset{
		DealerID:  "DEALER001",
		MSISDN:    "1234567890",
		MPIN:      "1234",
		Balance:   1000.0,
		Status:    "ACTIVE",
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	bytes, _ := json.Marshal(expectedAsset)
	chaincodeStub.GetStateReturns(bytes, nil)

	assetTransfer := SmartContract{}
	asset, err := assetTransfer.ReadAsset(transactionContext, "1234567890")
	assert.Nil(t, err)
	assert.Equal(t, expectedAsset.DealerID, asset.DealerID)
	assert.Equal(t, expectedAsset.MSISDN, asset.MSISDN)
	assert.Equal(t, expectedAsset.Balance, asset.Balance)
}

func TestUpdateAssetBalance(t *testing.T) {
	chaincodeStub := &mocks.ChaincodeStub{}
	transactionContext := &mocks.TransactionContext{}
	transactionContext.GetStubReturns(chaincodeStub)

	asset := &Asset{
		DealerID: "DEALER001",
		MSISDN:   "1234567890",
		MPIN:     "1234",
		Balance:  1000.0,
		Status:   "ACTIVE",
	}

	bytes, _ := json.Marshal(asset)
	chaincodeStub.GetStateReturns(bytes, nil)
	chaincodeStub.PutStateReturns(nil)
	chaincodeStub.GetTxIDReturns("txid123")

	assetTransfer := SmartContract{}

	// Test credit transaction
	err := assetTransfer.UpdateAssetBalance(transactionContext, "1234567890", "1234", 500.0, "CREDIT", "Credit test")
	assert.Nil(t, err)

	// Test debit transaction
	err = assetTransfer.UpdateAssetBalance(transactionContext, "1234567890", "1234", 200.0, "DEBIT", "Debit test")
	assert.Nil(t, err)

	// Test insufficient balance
	err = assetTransfer.UpdateAssetBalance(transactionContext, "1234567890", "1234", 2000.0, "DEBIT", "Insufficient balance test")
	assert.EqualError(t, err, "insufficient balance. Current balance: 1000.00, Requested: 2000.00")

	// Test invalid MPIN
	err = assetTransfer.UpdateAssetBalance(transactionContext, "1234567890", "wrong", 100.0, "CREDIT", "Wrong MPIN test")
	assert.EqualError(t, err, "invalid MPIN for asset 1234567890")
}

func TestAssetExists(t *testing.T) {
	chaincodeStub := &mocks.ChaincodeStub{}
	transactionContext := &mocks.TransactionContext{}
	transactionContext.GetStubReturns(chaincodeStub)

	// Test asset exists
	chaincodeStub.GetStateReturns([]byte("asset"), nil)
	assetTransfer := SmartContract{}
	exists, err := assetTransfer.AssetExists(transactionContext, "1234567890")
	assert.Nil(t, err)
	assert.True(t, exists)

	// Test asset doesn't exist
	chaincodeStub.GetStateReturns(nil, nil)
	exists, err = assetTransfer.AssetExists(transactionContext, "1234567890")
	assert.Nil(t, err)
	assert.False(t, exists)
}
