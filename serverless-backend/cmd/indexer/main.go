// Package main finalizes an upload after S3 PUT by marking the claim COMPLETE.
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

// main initializes the app and starts the Lambda handler.
func main() {
	env := config.MustLoad()
	cfg, endpoint, err := awsutil.Load(context.Background(), env.Region)
	if err != nil {
		log.Fatal(err)
	}

	s3c := s3.NewFromConfig(cfg, func(o *s3.Options) {
		if endpoint != "" {
			o.UsePathStyle = true // localstack/dev friendliness
		}
	})

	app := &App{
		env:     env,
		s3c:     s3c,
		ddbRepo: &ddb.Repo{DB: dynamodb.NewFromConfig(cfg), Table: env.Table},
	}
	lambda.Start(app.handler)
}

// ---- Handler ----

// handler processes S3 event records to finalize claim uploads.
func (a *App) handler(ctx context.Context, ev events.S3Event) (any, error) {
	for _, rec := range ev.Records {
		if err := a.processS3Record(ctx, rec); err != nil {
			log.Printf("indexer: process error: %v", err)
		}
	}
	return nil, nil
}

// processS3Record handles a single S3 event record.
func (a *App) processS3Record(ctx context.Context, record events.S3EventRecord) error {
	bucket := record.S3.Bucket.Name
	keyEsc := record.S3.Object.Key
	key, _ := url.QueryUnescape(keyEsc)

	meta, err := a.getObjectMetadata(ctx, bucket, key)
	if err != nil {
		return fmt.Errorf("head %s: %w", key, err)
	}

	// Prefer metadata-sourced IDs; fall back to path parsing.
	userID := strings.TrimSpace(meta.Meta["user_id"])
	claimID := strings.TrimSpace(meta.Meta["claim_id"])
	if userID == "" || claimID == "" {
		u2, c2, perr := a.parseS3Key(key)
		if perr != nil {
			return fmt.Errorf("bad key %q: %w", key, perr)
		}
		if userID == "" {
			userID = u2
		}
		if claimID == "" {
			claimID = c2
		}
	}

	// Complete the record (writes size, etag, uploaded_at, s3_key, status)
	if err := a.finalizeClaimUpload(ctx, userID, claimID, key, meta); err != nil {
		return fmt.Errorf("finalize %s/%s: %w", userID, claimID, err)
	}

	log.Printf("finalized %s/%s status=%s size=%d etag=%s",
		userID, claimID, models.StatusComplete, meta.Size, meta.ETag)
	return nil
}

// ---- Helpers ----

// parseS3Key extracts userID and claimID from the S3 key path.
func (a *App) parseS3Key(key string) (userID, claimID string, err error) {
	if strings.ToLower(filepath.Ext(key)) != ".txt" {
		return "", "", fmt.Errorf("non-txt file")
	}
	parts := strings.Split(key, "/")
	if len(parts) != 3 || parts[0] != "user" {
		return "", "", fmt.Errorf("unexpected key shape")
	}
	userID = parts[1]
	claimID = strings.TrimSuffix(parts[2], ".txt")
	return userID, claimID, nil
}

// objectMetadata holds S3 object metadata and user-defined metadata.
type objectMetadata struct {
	Size        int64
	ETag        string
	ContentType string
	Meta        map[string]string // lowercased user metadata
}

// getObjectMetadata fetches S3 object metadata including user-defined metadata.
func (a *App) getObjectMetadata(ctx context.Context, bucket, key string) (*objectMetadata, error) {
	ho, err := a.s3c.HeadObject(ctx, &s3.HeadObjectInput{
		Bucket: &bucket,
		Key:    &key,
	})
	if err != nil {
		return nil, err
	}

	m := &objectMetadata{
		Meta: make(map[string]string, len(ho.Metadata)),
	}
	if ho.ContentLength != nil {
		m.Size = *ho.ContentLength
	}
	if ho.ETag != nil {
		m.ETag = strings.Trim(*ho.ETag, "\"")
	}
	if ho.ContentType != nil {
		m.ContentType = strings.ToLower(*ho.ContentType)
		// Be tolerant: log if unexpected but don't fail the pipeline
		if m.ContentType != "" && m.ContentType != "text/plain" {
			log.Printf("indexer: warning content-type=%s for %s", m.ContentType, key)
		}
	}
	// Normalize user metadata keys to lowercase
	for k, v := range ho.Metadata {
		m.Meta[strings.ToLower(k)] = v
	}

	return m, nil
}

func (a *App) finalizeClaimUpload(ctx context.Context, userID, claimID, s3Key string, md *objectMetadata) error {
	// UpsertComplete should set: status=COMPLETE, uploaded_at, size_bytes, etag, s3_key
	return a.ddbRepo.UpsertComplete(ctx, userID, claimID, s3Key, md.Size, md.ETag, ddb.NowISO())
}
