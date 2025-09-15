// Package main verifies the upload after the browser PUT.
package main

import (
	"context"
	"fmt"
	"log"
	"net/url"
	"path/filepath"
	"strings"

	"github.com/kylejryan/insurance-claim-upload-portal/internal/awsutil"
	"github.com/kylejryan/insurance-claim-upload-portal/internal/config"
	"github.com/kylejryan/insurance-claim-upload-portal/internal/ddb"
	"github.com/kylejryan/insurance-claim-upload-portal/internal/models"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

// App holds the application state, including configuration and AWS clients.
type App struct {
	env     config.Env
	s3c     *s3.Client
	ddbRepo *ddb.Repo
}

// handler processes the S3 event to finalize the claim upload.
func (a *App) handler(ctx context.Context, ev events.S3Event) (any, error) {
	for _, record := range ev.Records {
		a.processS3Record(ctx, record)
	}
	return nil, nil
}

// processS3Record processes a single S3 event record.
func (a *App) processS3Record(ctx context.Context, record events.S3EventRecord) {
	bucket := record.S3.Bucket.Name
	keyEsc := record.S3.Object.Key
	key, _ := url.QueryUnescape(keyEsc)

	userID, claimID, err := a.parseS3Key(key)
	if err != nil {
		log.Printf("skip invalid key %s: %v", key, err)
		return
	}

	metadata, err := a.getObjectMetadata(ctx, bucket, key)
	if err != nil {
		log.Printf("failed to get metadata for %s: %v", key, err)
		return
	}

	if err := a.finalizeClaimUpload(ctx, userID, claimID, metadata); err != nil {
		log.Printf("failed to finalize claim %s/%s: %v", userID, claimID, err)
		return
	}

	log.Printf("finalized %s/%s status=%s", userID, claimID, models.StatusComplete)
}

// parseS3Key extracts user ID and claim ID from S3 key path.
func (a *App) parseS3Key(key string) (userID, claimID string, err error) {
	if strings.ToLower(filepath.Ext(key)) != ".txt" {
		return "", "", fmt.Errorf("non-txt file")
	}

	parts := strings.Split(key, "/")
	if len(parts) != 3 || parts[0] != "user" {
		return "", "", fmt.Errorf("unexpected key shape")
	}

	userID = parts[1]
	filename := parts[2]
	claimID = strings.TrimSuffix(filename, ".txt")

	return userID, claimID, nil
}

// objectMetadata contains the relevant S3 object metadata.
type objectMetadata struct {
	Size        int64
	ETag        string
	ContentType string
}

// getObjectMetadata retrieves and validates S3 object metadata.
func (a *App) getObjectMetadata(ctx context.Context, bucket, key string) (*objectMetadata, error) {
	ho, err := a.s3c.HeadObject(ctx, &s3.HeadObjectInput{
		Bucket: &bucket,
		Key:    &key,
	})
	if err != nil {
		return nil, fmt.Errorf("HeadObject failed: %w", err)
	}

	metadata := &objectMetadata{}

	if ho.ContentLength != nil {
		metadata.Size = *ho.ContentLength
	}

	if ho.ETag != nil {
		metadata.ETag = strings.Trim(*ho.ETag, "\"")
	}

	if ho.ContentType != nil {
		metadata.ContentType = strings.ToLower(*ho.ContentType)
		if metadata.ContentType != "text/plain" {
			return nil, fmt.Errorf("invalid content-type: %s", metadata.ContentType)
		}
	}

	return metadata, nil
}

// finalizeClaimUpload completes the claim processing in the database.
func (a *App) finalizeClaimUpload(ctx context.Context, userID, claimID string, metadata *objectMetadata) error {
	return a.ddbRepo.UpsertComplete(ctx, userID, claimID, metadata.Size, metadata.ETag, ddb.NowISO())
}

// main initializes the application and starts the Lambda handler.
func main() {
	env := config.MustLoad()
	cfg, endpoint, err := awsutil.Load(context.Background(), env.Region)
	if err != nil {
		log.Fatal(err)
	}

	s3c := s3.NewFromConfig(cfg, func(o *s3.Options) {
		if endpoint != "" {
			o.UsePathStyle = true
		}
	})

	app := &App{
		env:     env,
		s3c:     s3c,
		ddbRepo: &ddb.Repo{DB: dynamodb.NewFromConfig(cfg), Table: env.Table},
	}
	lambda.Start(app.handler)
}
