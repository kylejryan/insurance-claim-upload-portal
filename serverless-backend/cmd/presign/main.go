// Package main provides functionality to generate presigned URLs for uploading files to S3.
package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/kylejryan/insurance-claim-upload-portal/internal/awsutil"
	"github.com/kylejryan/insurance-claim-upload-portal/internal/config"
	"github.com/kylejryan/insurance-claim-upload-portal/internal/ddb"
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
		s3p:     s3.NewPresignClient(s3c),
		ddbRepo: &ddb.Repo{DB: dynamodb.NewFromConfig(cfg), Table: env.Table},
	}
	lambda.Start(app.handler)
}

// --------- helpers: API Gateway v1 responses ---------

func jsonOK(v any) (events.APIGatewayProxyResponse, error) {
	b, _ := json.Marshal(v)
	return events.APIGatewayProxyResponse{
		StatusCode: http.StatusOK,
		Headers:    map[string]string{"Content-Type": "application/json"},
		Body:       string(b),
	}, nil
}

func jsonError(code int, msg string) (events.APIGatewayProxyResponse, error) {
	b, _ := json.Marshal(map[string]string{"message": msg})
	return events.APIGatewayProxyResponse{
		StatusCode: code,
		Headers:    map[string]string{"Content-Type": "application/json"},
		Body:       string(b),
	}, nil
}

// --------- handler ---------

func (a *App) handler(ctx context.Context, req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	sub, err := a.extractUserID(req)
	if err != nil {
		return jsonError(http.StatusUnauthorized, "missing or invalid user")
	}

	body, err := a.parseAndValidateRequest(req.Body)
	if err != nil {
		return jsonError(http.StatusBadRequest, err.Error())
	}

	cid := ulid.Make().String()
	key := "user/" + sub + "/" + cid + ".txt"

	if err := a.createPendingRecord(ctx, sub, cid, key, body); err != nil {
		log.Printf("ddb PutPending err: %v", err)
		return jsonError(http.StatusInternalServerError, "db error")
	}

	url, ttl, err := a.generatePresignedURL(ctx, sub, cid, key, body)
	if err != nil {
		log.Printf("presign err: %v", err)
		return jsonError(http.StatusInternalServerError, "presign error")
	}

	// build the exact headers the client must send on the PUT
	up := map[string]string{
		"Content-Type":                 body.ContentType,
		"x-amz-server-side-encryption": "aws:kms",
		"x-amz-meta-claim_id":          cid,
		"x-amz-meta-tags":              strings.Join(body.Tags, ","),
		"x-amz-meta-client":            body.Client,
		"x-amz-meta-user_id":           sub,
	}

	return jsonOK(presignResponse{
		ClaimID:       cid,
		S3Key:         key,
		PresignedURL:  url,
		ExpiresIn:     int(ttl.Seconds()),
		ContentType:   body.ContentType,
		UploadHeaders: up,
	})
}

// --------- auth extraction (Cognito User Pool authorizer on REST API) ---------

// headerLookup returns a header value case-insensitively.
func headerLookup(h map[string]string, key string) string {
	if len(h) == 0 {
		return ""
	}
	lk := strings.ToLower(key)
	for k, v := range h {
		if strings.ToLower(k) == lk {
			return v
		}
	}
	return ""
}

// extractUserID supports: dev bypass, REST authorizer claims, and a safe JWT fallback.
func (a *App) extractUserID(req events.APIGatewayProxyRequest) (string, error) {
	// 0) Dev bypass
	if a.env.DevBypassAuth {
		if sub := a.extractDevBypass(req.Headers); sub != "" {
			return sub, nil
		}
	}

	// 1) REST authorizer
	if sub := a.extractFromAuthorizer(req.RequestContext.Authorizer); sub != "" {
		return sub, nil
	}

	// 2) Fallback: Authorization header
	if sub := subFromAuthHeader(req.Headers); sub != "" {
		return sub, nil
	}

	return "", fmt.Errorf("unauthorized")
}

// --- helpers ---

// extractDevBypass extracts the user sub from a dev bypass header.
func (a *App) extractDevBypass(headers map[string]string) string {
	return strings.TrimSpace(headerLookup(headers, "x-user-sub"))
}

// extractFromAuthorizer extracts the user sub from the authorizer map.
func (a *App) extractFromAuthorizer(auth map[string]any) string {
	if auth == nil {
		return ""
	}

	// 1) Claims block
	if sub := a.subFromClaims(auth["claims"]); sub != "" {
		return sub
	}

	// 2) Top-level fields
	if sub := stringIfNonEmpty(auth["sub"]); sub != "" {
		return sub
	}
	if sub := stringIfNonEmpty(auth["principalId"]); sub != "" {
		return sub
	}

	return ""
}

// subFromClaims extracts the "sub" field from various possible claims formats.
func (a *App) subFromClaims(raw any) string {
	switch c := raw.(type) {
	case map[string]any:
		return stringIfNonEmpty(c["sub"])
	case map[string]string:
		return c["sub"]
	case string:
		var m map[string]any
		if json.Unmarshal([]byte(c), &m) == nil {
			return stringIfNonEmpty(m["sub"])
		}
	}
	return ""
}

// stringIfNonEmpty returns the string if non-empty, else "".
func stringIfNonEmpty(v any) string {
	if s, ok := v.(string); ok && s != "" {
		return s
	}
	return ""
}

// subFromAuthHeader extracts the "sub" claim from a JWT in the Authorization header.
func subFromAuthHeader(headers map[string]string) string {
	auth := headerLookup(headers, "Authorization")
	if auth == "" {
		return ""
	}
	if strings.HasPrefix(strings.ToLower(auth), "bearer ") {
		auth = strings.TrimSpace(auth[len("bearer "):])
	}
	parts := strings.Split(auth, ".")
	if len(parts) != 3 {
		return ""
	}
	payload, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return ""
	}
	var m map[string]any
	if err := json.Unmarshal(payload, &m); err != nil {
		return ""
	}
	if v, ok := m["sub"].(string); ok && v != "" {
		return v
	}
	return ""
}

// --------- validation / business logic ---------

func (a *App) parseAndValidateRequest(body string) (presignRequest, error) {
	var req presignRequest
	if err := json.Unmarshal([]byte(body), &req); err != nil {
		return req, errors.New("invalid json")
	}
	if req.ContentType == "" {
		req.ContentType = "text/plain"
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

func (a *App) generatePresignedURL(ctx context.Context, userID, claimID, s3Key string, req presignRequest) (string, time.Duration, error) {
	meta := map[string]string{
		"claim_id": claimID,
		"user_id":  userID,
		"tags":     strings.Join(req.Tags, ","),
		"client":   req.Client,
	}
	return s3io.PresignPut(ctx, a.s3p, a.env.Bucket, s3Key, req.ContentType, meta, a.env.PresignTTL)
}

func sanitizeName(s string) string {
	s = strings.TrimSpace(s)
	if s == "" {
		return ulid.Make().String() + ".txt"
	}
	return s
}
