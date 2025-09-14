// Package presign provides functionality to generate presigned URLs for uploading files to S3.
package presign

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"strings"
	"time"

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

// presignRequest represents the expected JSON body for a presign request.
type presignRequest struct {
	Filename    string   `json:"filename"`
	Tags        []string `json:"tags"`
	Client      string   `json:"client"`
	ContentType string   `json:"content_type"` // expect "text/plain"
}

// presignResponse represents the JSON response containing the presigned URL and related info.
type presignResponse struct {
	ClaimID      string `json:"claim_id"`
	S3Key        string `json:"s3_key"`
	PresignedURL string `json:"presigned_url"`
	ExpiresIn    int    `json:"expires_in"`
	ContentType  string `json:"content_type"`
}

// App holds the application state, including configuration and AWS clients.
type App struct {
	env     config.Env
	s3p     *s3.PresignClient
	ddbRepo *ddb.Repo
}

func main() {
	env := config.MustLoad()
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
		s3p:     s3.NewPresignClient(s3c), // Use AWS SDK's presign client
		ddbRepo: &ddb.Repo{DB: dynamodb.NewFromConfig(cfg), Table: env.Table},
	}
	lambda.Start(app.handler)
}

// handler processes the incoming API Gateway request to generate a presigned S3 URL.
func (a *App) handler(ctx context.Context, req events.APIGatewayV2HTTPRequest) (events.APIGatewayV2HTTPResponse, error) {
	sub, err := a.extractUserID(req)
	if err != nil {
		return httpx.Error(http.StatusUnauthorized, "missing user")
	}

	body, err := a.parseAndValidateRequest(req.Body)
	if err != nil {
		return httpx.Error(http.StatusBadRequest, err.Error())
	}

	cid := ulid.Make().String()
	key := "user/" + sub + "/" + cid + ".txt"

	if err := a.createPendingRecord(ctx, sub, cid, key, body); err != nil {
		log.Printf("ddb PutPending err: %v", err)
		return httpx.Error(http.StatusInternalServerError, "db error")
	}

	url, ttl, err := a.generatePresignedURL(ctx, sub, cid, key, body)
	if err != nil {
		log.Printf("presign err: %v", err)
		return httpx.Error(http.StatusInternalServerError, "presign error")
	}

	return httpx.JSON(http.StatusOK, presignResponse{
		ClaimID: cid, S3Key: key, PresignedURL: url, ExpiresIn: int(ttl.Seconds()), ContentType: body.ContentType,
	})
}

// extractUserID extracts the user ID from the request, supporting dev bypass.
func (a *App) extractUserID(req events.APIGatewayV2HTTPRequest) (string, error) {
	if a.env.DevBypassAuth {
		if sub := req.Headers["x-user-sub"]; sub != "" {
			return sub, nil
		}
	}

	if req.RequestContext.Authorizer.JWT.Claims != nil {
		if sub, ok := req.RequestContext.Authorizer.JWT.Claims["sub"]; ok && sub != "" {
			return sub, nil
		}
	}

	return "", errors.New("missing user")
}

// parseAndValidateRequest parses the JSON body and validates all input fields.
func (a *App) parseAndValidateRequest(body string) (presignRequest, error) {
	var req presignRequest
	if err := json.Unmarshal([]byte(body), &req); err != nil {
		return req, errors.New("invalid json")
	}

	if req.ContentType == "" {
		req.ContentType = "text/plain"
	}

	if err := a.validateRequest(req); err != nil {
		return req, err
	}

	return req, nil
}

// validateRequest validates all fields in the presign request.
func (a *App) validateRequest(req presignRequest) error {
	validators := []func() error{
		func() error { return validate.FilenameTxt(req.Filename) },
		func() error { return validate.ContentTypeTextPlain(req.ContentType) },
		func() error { return validate.TagsOK(req.Tags) },
		func() error { return validate.ClientOK(req.Client) },
	}

	for _, validator := range validators {
		if err := validator(); err != nil {
			return err
		}
	}

	return nil
}

// createPendingRecord creates and stores a pending claim record in DynamoDB.
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

// generatePresignedURL creates a presigned URL for S3 upload with metadata.
func (a *App) generatePresignedURL(ctx context.Context, userID, claimID, s3Key string, req presignRequest) (string, time.Duration, error) {
	meta := map[string]string{
		"claim_id": claimID,
		"user_id":  userID,
		"tags":     strings.Join(req.Tags, ","),
		"client":   req.Client,
	}
	return s3io.PresignPut(ctx, a.s3p, a.env.Bucket, s3Key, req.ContentType, meta, a.env.PresignTTL)
}

// sanitizeName trims whitespace and defaults to "claim.txt" if empty.
func sanitizeName(s string) string {
	s = strings.TrimSpace(s)
	if s == "" {
		return "claim.txt"
	}
	return s
}
