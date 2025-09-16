// Package main powers GET /claims for the current user (REST API Gateway v1).
package main

import (
	"context"
	"log"
	"net/http"

	"github.com/kylejryan/insurance-claim-upload-portal/internal/authz"
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

// main initializes the app and starts the Lambda handler.
func main() {
	env := config.MustLoad()               // your config expects REGION, DDB_TABLE, S3_BUCKET
	if err := env.Validate(); err != nil { // <- ensure env present
		log.Fatal(err)
	}
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

// --- handler ---

// handler processes the GET /claims request for the authenticated user.
func (a *App) handler(ctx context.Context, req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	sub, err := authz.FromAPIGWv1(req, a.env.DevBypassAuth)
	if err != nil {
		return httpx.ErrorV1(http.StatusUnauthorized, "missing or invalid user")
	}

	items, err := a.ddbRepo.ListByUser(ctx, sub, 100)
	if err != nil {
		log.Printf("list ddb error: %v", err)
		return httpx.ErrorV1(http.StatusInternalServerError, "db error")
	}
	return httpx.JSONV1(http.StatusOK, map[string]any{
		"user_id": sub,
		"items":   items,
	})
}
