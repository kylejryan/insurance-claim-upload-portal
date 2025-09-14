// Package ddb provides a simple repository for interacting with DynamoDB for claim records.
package ddb

import (
	"context"
	"fmt"
	"time"

	"github.com/kylejryan/insurance-claim-upload-portal/internal/models"

	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
)

// Repo wraps a DynamoDB client and table name for claim operations.
type Repo struct {
	DB    *dynamodb.Client
	Table string
}

// PutPending inserts a new claim record with status UPLOADING, ensuring no duplicate exists.
func (r *Repo) PutPending(ctx context.Context, c models.Claim) error {
	item, err := attributevalue.MarshalMap(c)
	if err != nil {
		return err
	}
	_, err = r.DB.PutItem(ctx, &dynamodb.PutItemInput{
		TableName:           &r.Table,
		Item:                item,
		ConditionExpression: awsStr("attribute_not_exists(PK) AND attribute_not_exists(SK)"),
	})
	return err
}

// awsStr is a helper to get a pointer to a string literal.
func awsStr(s string) *string { return &s }

// NowISO returns the current time in ISO8601 format.
func NowISO() string { return time.Now().UTC().Format(time.RFC3339) }

// MakeKeys constructs the partition key (PK) and sort key (SK) for a claim record.
func MakeKeys(sub, claimID string) (pk, sk string) {
	return fmt.Sprintf("USER#%s", sub), fmt.Sprintf("CLAIM#%s", claimID)
}
