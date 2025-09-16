// Package ddb provides a simple repository for interacting with DynamoDB for claim records.
package ddb

import (
	"context"
	"fmt"
	"strconv"
	"time"

	"github.com/kylejryan/insurance-claim-upload-portal/internal/models"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
)

// Repo wraps a DynamoDB client and table name for claim operations.
type Repo struct {
	DB    *dynamodb.Client
	Table string
}

// awsStr is a helper to get a pointer to a string literal.
func awsStr(s string) *string { return &s }

// NowISO returns the current time in ISO8601 format.
func NowISO() string { return time.Now().UTC().Format(time.RFC3339) }

// MakeKeys constructs the partition key (PK) and sort key (SK) for a claim record.
func MakeKeys(sub, claimID string) (pk, sk string) {
	return fmt.Sprintf("USER#%s", sub), fmt.Sprintf("CLAIM#%s", claimID)
}

// PutPending writes a new record with (user_id, claim_id). The condition only guards claim_id,
// so you can have multiple claims per user.
func (r *Repo) PutPending(ctx context.Context, c models.Claim) error {
	// Store with explicit attribute names that match the table schema.
	itemMap := map[string]any{
		"user_id":     c.UserID,
		"claim_id":    c.ClaimID,
		"filename":    c.Filename,
		"s3_key":      c.S3Key,
		"tags":        c.Tags,
		"client":      c.Client,
		"status":      c.Status,
		"uploaded_at": time.Now().UTC().Format(time.RFC3339Nano), // optional
	}
	item, err := attributevalue.MarshalMap(itemMap)
	if err != nil {
		return err
	}

	_, err = r.DB.PutItem(ctx, &dynamodb.PutItemInput{
		TableName: aws.String(r.Table),
		Item:      item,

		ConditionExpression: aws.String("attribute_not_exists(claim_id)"),
	})
	return err
}

// UpsertComplete updates an existing claim record to status COMPLETE with upload details.
func (r *Repo) UpsertComplete(ctx context.Context, userID, claimID string, size int64, etag, uploadedAt string) error {
	pk, sk := MakeKeys(userID, claimID)
	_, err := r.DB.UpdateItem(ctx, &dynamodb.UpdateItemInput{
		TableName: &r.Table,
		Key: map[string]types.AttributeValue{
			"PK": &types.AttributeValueMemberS{Value: pk},
			"SK": &types.AttributeValueMemberS{Value: sk},
		},
		UpdateExpression:         awsStr("SET #s=:s, uploaded_at=:u, size_bytes=:b, etag=:e"),
		ExpressionAttributeNames: map[string]string{"#s": "status"},
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":s": &types.AttributeValueMemberS{Value: string(models.StatusComplete)},
			":u": &types.AttributeValueMemberS{Value: uploadedAt},
			":b": &types.AttributeValueMemberN{Value: strconv.FormatInt(size, 10)},
			":e": &types.AttributeValueMemberS{Value: etag},
		},
		ConditionExpression: awsStr("attribute_exists(PK) AND attribute_exists(SK)"),
	})
	return err
}

// ListByUser queries the table by user_id (PK) and returns newest-first by ULID claim_id.
func (r *Repo) ListByUser(ctx context.Context, userID string, limit int32) ([]models.Claim, error) {
	if limit <= 0 {
		limit = 100
	}

	pe := "user_id, claim_id, filename, tags, client, #s, uploaded_at, size_bytes, etag, s3_key"

	out, err := r.DB.Query(ctx, &dynamodb.QueryInput{
		TableName:              aws.String(r.Table),
		KeyConditionExpression: aws.String("#uid = :u"),
		ExpressionAttributeNames: map[string]string{
			"#uid": "user_id",
			"#s":   "status",
		},
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":u": &types.AttributeValueMemberS{Value: userID},
		},
		ProjectionExpression: aws.String(pe),
		ScanIndexForward:     aws.Bool(false), // ULID sorts by time → newest first
		Limit:                aws.Int32(limit),
	})
	if err != nil {
		return nil, err
	}

	var items []models.Claim
	if err := attributevalue.UnmarshalListOfMaps(out.Items, &items); err != nil {
		return nil, err
	}
	return items, nil
}
