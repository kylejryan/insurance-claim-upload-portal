// Package httpx provides helper functions for creating HTTP responses.
package httpx

import (
	"encoding/json"

	"github.com/aws/aws-lambda-go/events"
)

//
// -------- REST API Gateway v1 (APIGatewayProxyResponse) --------
//

// JSONV1 constructs a JSON response with the given status code and value.
func JSONV1(status int, v any) (events.APIGatewayProxyResponse, error) {
	b, _ := json.Marshal(v)
	return events.APIGatewayProxyResponse{
		StatusCode: status,
		Headers: map[string]string{
			"Content-Type": "application/json",
		},
		Body: string(b),
	}, nil
}

// ErrorV1 constructs a JSON error response with the given status code and message.
func ErrorV1(status int, msg string) (events.APIGatewayProxyResponse, error) {
	return JSONV1(status, map[string]string{"message": msg})
}
