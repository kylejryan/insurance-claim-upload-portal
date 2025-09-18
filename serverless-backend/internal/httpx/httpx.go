// Package httpx provides helper functions for creating HTTP responses.
package httpx

import (
	"encoding/json"
	"os"
	"strings"

	"github.com/aws/aws-lambda-go/events"
)

//
// -------- REST API Gateway v1 (APIGatewayProxyResponse) --------
//

// Read allowed origin strictly from env var FRONTEND_ORIGIN.
var allowOriginV1 = strings.TrimSpace(os.Getenv("FRONTEND_ORIGIN"))

// JSONV1 creates an API Gateway v1 (REST) JSON response with CORS headers.
func JSONV1(status int, v any) (events.APIGatewayProxyResponse, error) {
	b, _ := json.Marshal(v)
	return events.APIGatewayProxyResponse{
		StatusCode: status,
		Headers: map[string]string{
			"Content-Type":                     "application/json",
			"Access-Control-Allow-Origin":      allowOriginV1,
			"Access-Control-Allow-Credentials": "true",
			"Vary":                             "Origin",
		},
		Body: string(b),
	}, nil
}

// ErrorV1 creates an API Gateway v1 (REST) JSON error response with CORS headers.
func ErrorV1(status int, msg string) (events.APIGatewayProxyResponse, error) {
	return JSONV1(status, map[string]string{"message": msg})
}
