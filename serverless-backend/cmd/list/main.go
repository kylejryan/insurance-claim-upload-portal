// Package main powers GET /claims for the current user (REST API Gateway v1).
package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"strings"

	"github.com/kylejryan/insurance-claim-upload-portal/internal/awsutil"
	"github.com/kylejryan/insurance-claim-upload-portal/internal/config"
	"github.com/kylejryan/insurance-claim-upload-portal/internal/ddb"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
)

// App holds the application state, including configuration and AWS clients.
type App struct {
	env     config.Env
	ddbRepo *ddb.Repo
}

// main initializes the app and starts the Lambda handler.
func main() {
	env := config.MustLoad() // your config expects REGION, DDB_TABLE, S3_BUCKET
	cfg, _, err := awsutil.Load(context.Background(), env.Region)
	if err != nil {
		log.Fatal(err)
	}
	app := &App{
		env:     env,
		ddbRepo: &ddb.Repo{DB: dynamodb.NewFromConfig(cfg), Table: env.Table},
	}
	lambda.Start(app.handler)
}

// --- REST (v1) response helpers ---

// jsonOK constructs a 200 OK JSON response.
func jsonOK(v any) (events.APIGatewayProxyResponse, error) {
	b, _ := json.Marshal(v)
	return events.APIGatewayProxyResponse{
		StatusCode: http.StatusOK,
		Headers:    map[string]string{"Content-Type": "application/json"},
		Body:       string(b),
	}, nil
}

// jsonError constructs a JSON error response with the given status code and message.
func jsonError(code int, msg string) (events.APIGatewayProxyResponse, error) {
	b, _ := json.Marshal(map[string]string{"message": msg})
	return events.APIGatewayProxyResponse{
		StatusCode: code,
		Headers:    map[string]string{"Content-Type": "application/json"},
		Body:       string(b),
	}, nil
}

// --- handler ---

// handler processes the GET /claims request for the authenticated user.
func (a *App) handler(ctx context.Context, req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	sub, err := a.extractUserID(req)
	if err != nil {
		return jsonError(http.StatusUnauthorized, "missing or invalid user")
	}

	items, err := a.ddbRepo.ListByUser(ctx, sub, 100)
	if err != nil {
		log.Printf("list ddb error: %v", err)
		return jsonError(http.StatusInternalServerError, "db error")
	}
	return jsonOK(map[string]any{
		"user_id": sub,
		"items":   items,
	})
}

// --- auth extraction for REST (v1) ---

// extractUserID extracts the user ID ("sub") from the request, supporting dev bypass and various authorizer formats.
func (a *App) extractUserID(req events.APIGatewayProxyRequest) (string, error) {
	// dev bypass
	if a.env.DevBypassAuth {
		if sub := strings.TrimSpace(headerLookup(req.Headers, "x-user-sub")); sub != "" {
			return sub, nil
		}
	}
	// REST authorizer map
	if sub := extractFromAuthorizer(req.RequestContext.Authorizer); sub != "" {
		return sub, nil
	}
	// Fallback: parse JWT's payload from Authorization header
	if sub := subFromAuthHeader(req.Headers); sub != "" {
		return sub, nil
	}
	return "", errors.New("unauthorized")
}

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

// extractFromAuthorizer extracts the user sub from the authorizer map.
func extractFromAuthorizer(auth map[string]any) string {
	if auth == nil {
		return ""
	}
	// claims may be embedded or stringified
	if c, ok := auth["claims"]; ok {
		if sub := subFromClaims(c); sub != "" {
			return sub
		}
	}
	if sub := stringIfNonEmpty(auth["sub"]); sub != "" {
		return sub
	}
	if sub := stringIfNonEmpty(auth["principalId"]); sub != "" {
		return sub
	}
	return ""
}

// subFromClaims extracts the "sub" field from various possible claims formats.
func subFromClaims(raw any) string {
	switch m := raw.(type) {
	case map[string]any:
		return stringIfNonEmpty(m["sub"])
	case map[string]string:
		return m["sub"]
	case string:
		var mm map[string]any
		if json.Unmarshal([]byte(m), &mm) == nil {
			return stringIfNonEmpty(mm["sub"])
		}
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
	if json.Unmarshal(payload, &m) != nil {
		return ""
	}
	return stringIfNonEmpty(m["sub"])
}

// stringIfNonEmpty returns the string if non-empty, else "".
func stringIfNonEmpty(v any) string {
	if s, ok := v.(string); ok && s != "" {
		return s
	}
	return ""
}
