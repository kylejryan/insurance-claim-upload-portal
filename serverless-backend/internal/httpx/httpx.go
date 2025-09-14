// Package httpx provides helper functions for creating HTTP responses.
package httpx

import (
	"encoding/json"

	"github.com/aws/aws-lambda-go/events"
)

// JSON creates a JSON HTTP response with the given status code and value.
func JSON(status int, v any) (events.APIGatewayV2HTTPResponse, error) {
	b, _ := json.Marshal(v)
	return events.APIGatewayV2HTTPResponse{
		StatusCode: status,
		Headers: map[string]string{
			"Content-Type": "application/json",
		},
		Body: string(b),
	}, nil
}

// Error creates a JSON HTTP error response with the given status code and message.
func Error(status int, msg string) (events.APIGatewayV2HTTPResponse, error) {
	return JSON(status, map[string]string{"error": msg})
}
