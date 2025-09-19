// Package main provides functionality to generate presigned URLs for uploading files to S3.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/kylejryan/insurance-claim-upload-portal/internal/authz"
	"github.com/kylejryan/insurance-claim-upload-portal/internal/awsutil"
	"github.com/kylejryan/insurance-claim-upload-portal/internal/config"
	"github.com/kylejryan/insurance-claim-upload-portal/internal/ddb"
	"github.com/kylejryan/insurance-claim-upload-portal/internal/httpx"
	"github.com/kylejryan/insurance-claim-upload-portal/internal/models"
	"github.com/kylejryan/insurance-claim-upload-portal/internal/s3io"
	"github.com/kylejryan/insurance-claim-upload-portal/internal/validate"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/oklog/ulid/v2"
)

// --------- request/response payloads ---------

type presignRequest struct {
	Filename    string   `json:"filename"`
	Tags        []string `json:"tags"`
	Client      string   `json:"client"`
	ContentType string   `json:"content_type"` // e.g. "text/plain"
}

type presignResponse struct {
	ClaimID       string            `json:"claim_id"`
	S3Key         string            `json:"s3_key"`
	PresignedURL  string            `json:"presigned_url"`
	ExpiresIn     int               `json:"expires_in"`
	ContentType   string            `json:"content_type"`
	UploadHeaders map[string]string `json:"upload_headers"`
}

// --------- app ---------

type App struct {
	env     config.Env
	s3p     *s3.PresignClient
	ddbRepo *ddb.Repo
}

// main initializes the app and starts the Lambda handler.
func main() {
	env := config.MustLoad()
	if err := env.Validate(); err != nil { //
		log.Fatal(err)
	}
	cfg, endpoint, err := awsutil.Load(context.Background(), env.Region)
	if err != nil {
		log.Fatal(err)
	}

	// S3 client: use path-style when hitting LocalStack
	s3c := s3.NewFromConfig(cfg, func(o *s3.Options) {
		if endpoint != "" {
			o.UsePathStyle = true
		}
	})

	app := &App{
		env:     env,
		s3p:     s3.NewPresignClient(s3c),
		ddbRepo: &ddb.Repo{DB: dynamodb.NewFromConfig(cfg), Table: env.Table},
	}
	lambda.Start(app.handler)
}

// --------- handler ---------

// handler processes the POST /claims/presign request to generate a presigned S3 upload URL.
func (a *App) handler(ctx context.Context, req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	sub, err := authz.FromAPIGWv1(req, a.env.DevBypassAuth)
	if err != nil {
		return httpx.ErrorV1(http.StatusUnauthorized, "missing or invalid user")
	}

	body, err := a.parseAndValidateRequest(req.Body)
	if err != nil {
		return httpx.ErrorV1(http.StatusBadRequest, err.Error())
	}

	cid := ulid.Make().String()
	key := s3io.BuildKey(sub, cid) // <- centralized S3 key builder

	if err := a.createPendingRecord(ctx, sub, cid, key, body); err != nil {
		log.Printf("ddb PutPending err: %v", err)
		return httpx.ErrorV1(http.StatusInternalServerError, "db error")
	}

	url, ttl, err := a.generatePresignedURL(ctx, sub, cid, key, body)
	if err != nil {
		log.Printf("presign err: %v", err)
		return httpx.ErrorV1(http.StatusInternalServerError, "presign error")
	}

	// build the exact headers the client must send on the PUT
	up := s3io.UploadHeaders(
		sub,
		cid,
		body.ContentType,
		strings.Join(body.Tags, ","),
		body.Client,
	)

	return httpx.JSONV1(http.StatusOK, presignResponse{
		ClaimID:       cid,
		S3Key:         key,
		PresignedURL:  url,
		ExpiresIn:     int(ttl.Seconds()),
		ContentType:   body.ContentType,
		UploadHeaders: up,
	})
}

// --------- validation / business logic ---------

// parseAndValidateRequest unmarshals and validates the incoming JSON request body.
func (a *App) parseAndValidateRequest(body string) (presignRequest, error) {
	var req presignRequest
	if err := json.Unmarshal([]byte(body), &req); err != nil {
		return req, errors.New("invalid json")
	}
	if req.ContentType == "" {
		req.ContentType = s3io.ContentTypeText // <- single source of truth
	}
	// Validators
	if err := validate.FilenameTxt(req.Filename); err != nil {
		return req, err
	}
	if err := validate.ContentTypeTextPlain(req.ContentType); err != nil {
		return req, err
	}
	if err := validate.TagsOK(req.Tags); err != nil {
		return req, err
	}
	if err := validate.ClientOK(req.Client); err != nil {
		return req, err
	}
	return req, nil
}

// headerLookup performs a case-insensitive lookup of an HTTP header key.
func (a *App) createPendingRecord(ctx context.Context, userID, claimID, s3Key string, req presignRequest) error {
	pk, sk := ddb.MakeKeys(userID, claimID)
	claim := models.Claim{
		PK: pk, SK: sk,
		ClaimID:  claimID,
		UserID:   userID,
		Filename: sanitizeName(req.Filename),
		S3Key:    s3Key,
		Tags:     req.Tags,
		Client:   req.Client,
		Status:   models.StatusUploading,
	}
	return a.ddbRepo.PutPending(ctx, claim)
}

// generatePresignedURL creates a presigned PUT URL with metadata.
func (a *App) generatePresignedURL(ctx context.Context, userID, claimID, s3Key string, req presignRequest) (string, time.Duration, error) {
	meta := map[string]string{
		"claim_id": claimID,
		"user_id":  userID,
		"tags":     strings.Join(req.Tags, ","),
		"client":   req.Client,
	}
	return s3io.PresignPut(ctx, a.s3p, a.env.Bucket, s3Key, req.ContentType, meta, a.env.PresignTTL)
}

// sanitizeName ensures the filename is non-empty and trimmed; else generates a random name.
func sanitizeName(s string) string {
	s = strings.TrimSpace(s)
	if s == "" {
		return ulid.Make().String() + ".txt"
	}
	return s
}
