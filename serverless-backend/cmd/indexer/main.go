// Package main finalizes an upload after S3 PUT by marking the claim COMPLETE.
package main

import (
	"context"
	"fmt"
	"log"
	"net/url"
	"strings"

	"github.com/kylejryan/insurance-claim-upload-portal/internal/awsutil"
	"github.com/kylejryan/insurance-claim-upload-portal/internal/config"
	"github.com/kylejryan/insurance-claim-upload-portal/internal/ddb"
	"github.com/kylejryan/insurance-claim-upload-portal/internal/models"
	"github.com/kylejryan/insurance-claim-upload-portal/internal/s3io"

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
	if err := env.Validate(); err != nil { // <- ensure env present
		log.Fatal(err)
	}
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

	userID, claimID, err := a.extractIDs(key, meta)
	if err != nil {
		return err
	}

	if err := a.finalizeRecord(ctx, userID, claimID, key, meta); err != nil {
		return err
	}

	log.Printf("finalized %s/%s status=%s size=%d etag=%s",
		userID, claimID, models.StatusComplete, meta.Size, meta.ETag)
	return nil
}

// ---- Helpers ----

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

	return a.buildObjectMetadata(ho, key), nil
}

// buildObjectMetadata constructs objectMetadata from S3 HeadObjectOutput.
func (a *App) buildObjectMetadata(ho *s3.HeadObjectOutput, key string) *objectMetadata {
	m := &objectMetadata{
		Meta: make(map[string]string, len(ho.Metadata)),
	}

	a.setBasicFields(m, ho)
	a.setContentType(m, ho, key)
	a.setUserMetadata(m, ho)

	return m
}

// setBasicFields sets size and etag from HeadObjectOutput.
func (a *App) setBasicFields(m *objectMetadata, ho *s3.HeadObjectOutput) {
	if ho.ContentLength != nil {
		m.Size = *ho.ContentLength
	}
	if ho.ETag != nil {
		m.ETag = strings.Trim(*ho.ETag, "\"")
	}
}

// setContentType sets and validates content type.
func (a *App) setContentType(m *objectMetadata, ho *s3.HeadObjectOutput, key string) {
	if ho.ContentType == nil {
		return
	}

	m.ContentType = strings.ToLower(*ho.ContentType)

	// Be tolerant: log if unexpected but don't fail the pipeline
	if m.ContentType != "" && m.ContentType != s3io.ContentTypeText {
		log.Printf("indexer: warning content-type=%s for %s", m.ContentType, key)
	}
}

// setUserMetadata normalizes and copies user metadata keys to lowercase.
func (a *App) setUserMetadata(m *objectMetadata, ho *s3.HeadObjectOutput) {
	for k, v := range ho.Metadata {
		m.Meta[strings.ToLower(k)] = v
	}
}

// extractIDs gets user and claim IDs from metadata or S3 key path.
func (a *App) extractIDs(key string, meta *objectMetadata) (userID, claimID string, err error) {
	userID = strings.TrimSpace(meta.Meta["user_id"])
	claimID = strings.TrimSpace(meta.Meta["claim_id"])

	if userID != "" && claimID != "" {
		return userID, claimID, nil
	}

	return a.extractIDsFromPath(key, userID, claimID)
}

// extractIDsFromPath parses IDs from S3 key path as fallback.
func (a *App) extractIDsFromPath(key, userID, claimID string) (string, string, error) {
	u2, c2, ok := s3io.ParseKey(key)
	if !ok {
		return "", "", fmt.Errorf("bad key %q", key)
	}

	if userID == "" {
		userID = u2
	}
	if claimID == "" {
		claimID = c2
	}

	return userID, claimID, nil
}

// finalizeRecord completes the record in DynamoDB.
func (a *App) finalizeRecord(ctx context.Context, userID, claimID, key string, meta *objectMetadata) error {
	err := a.ddbRepo.UpsertComplete(ctx, userID, claimID, key, meta.Size, meta.ETag, ddb.NowISO())
	if err != nil {
		return fmt.Errorf("finalize %s/%s: %w", userID, claimID, err)
	}
	return nil
}
