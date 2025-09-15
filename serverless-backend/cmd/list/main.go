// Package main powers the dashboard by listing all uploads for the current user.
package main

import (
	"context"
	"log"
	"net/http"
	"strings"

	"github.com/kylejryan/insurance-claim-upload-portal/internal/awsutil"
	"github.com/kylejryan/insurance-claim-upload-portal/internal/config"
	"github.com/kylejryan/insurance-claim-upload-portal/internal/ddb"
	"github.com/kylejryan/insurance-claim-upload-portal/internal/httpx"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
)

// App holds the application state, including configuration and AWS clients.
type App struct {
	env     config.Env
	ddbRepo *ddb.Repo
}

// header retrieves a header value in a case-insensitive manner.
func header(h map[string]string, key string) string {
	lk := strings.ToLower(key)
	for k, v := range h {
		if strings.ToLower(k) == lk {
			return v
		}
	}
	return ""
}

// userID extracts the user ID from the request headers, supporting a dev bypass.
func (a *App) userID(req events.APIGatewayV2HTTPRequest) (string, bool) {
	if a.env.DevBypassAuth {
		if sub := header(req.Headers, "x-user-sub"); strings.TrimSpace(sub) != "" {
			return sub, true
		}
	}
	// You can add JWT/authorizer extraction here later
	return "", false
}

// handler processes the incoming request to list claims for the authenticated user.
func (a *App) handler(ctx context.Context, req events.APIGatewayV2HTTPRequest) (events.APIGatewayV2HTTPResponse, error) {
	sub, ok := a.userID(req)
	if !ok {
		return httpx.Error(http.StatusUnauthorized, "missing user")
	}
	items, err := a.ddbRepo.ListByUser(ctx, sub, 100)
	if err != nil {
		log.Printf("list error: %v", err)
		return httpx.Error(http.StatusInternalServerError, "db error")
	}
	return httpx.JSON(http.StatusOK, items)
}

// main initializes the application and starts the Lambda handler.
func main() {
	env := config.MustLoad()
	cfg, _, err := awsutil.Load(context.Background(), env.Region)
	if err != nil {
		log.Fatal(err)
	}
	app := &App{env: env, ddbRepo: &ddb.Repo{DB: dynamodb.NewFromConfig(cfg), Table: env.Table}}
	lambda.Start(app.handler)
}
