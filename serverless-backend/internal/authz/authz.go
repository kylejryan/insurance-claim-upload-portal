// Package authz provides authorization utilities.
package authz

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"strings"

	"github.com/aws/aws-lambda-go/events"
)

// ErrUnauthorized is returned when a user is not authorized to access a resource.
var ErrUnauthorized = errors.New("unauthorized")

const devBypassHeader = "x-user-sub"

// --- small utils ---

// headerLookup returns the value of a header key from a map.
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

// stringIf returns the string value of an interface{} if it is a non-empty string.
func stringIf(v any) string {
	if s, ok := v.(string); ok && s != "" {
		return s
	}
	return ""
}

// subFromClaims extracts the "sub" claim from a JWT claims map.
func subFromClaims(raw any) string {
	switch c := raw.(type) {
	case map[string]any:
		return stringIf(c["sub"])
	case map[string]string:
		return c["sub"]
	case string:
		var m map[string]any
		if json.Unmarshal([]byte(c), &m) == nil {
			return stringIf(m["sub"])
		}
	}
	return ""
}

// subFromAuthHeader extracts the "sub" claim from the Authorization header.
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
	return stringIf(m["sub"])
}

// FromAPIGWv1 extracts the Cognito user sub from a REST (v1) request.
func FromAPIGWv1(req events.APIGatewayProxyRequest, devBypass bool) (string, error) {
	// Try each extraction method in order of preference
	extractors := []func() string{
		func() string { return tryDevBypass(req.Headers, devBypass) },
		func() string { return tryAuthorizerContext(req.RequestContext.Authorizer) },
		func() string { return subFromAuthHeader(req.Headers) },
	}

	for _, extract := range extractors {
		if sub := extract(); sub != "" {
			return sub, nil
		}
	}

	return "", ErrUnauthorized
}

// tryDevBypass checks for dev bypass header if enabled.
func tryDevBypass(headers map[string]string, devBypass bool) string {
	if !devBypass {
		return ""
	}
	return strings.TrimSpace(headerLookup(headers, devBypassHeader))
}

// tryAuthorizerContext extracts sub from Cognito authorizer context.
func tryAuthorizerContext(authorizer map[string]interface{}) string {
	if authorizer == nil {
		return ""
	}

	// Try each potential source in the authorizer context
	sources := []func() string{
		func() string { return subFromClaims(authorizer["claims"]) },
		func() string { return stringIf(authorizer["sub"]) },
		func() string { return stringIf(authorizer["principalId"]) },
	}

	for _, source := range sources {
		if sub := source(); sub != "" {
			return sub
		}
	}

	return ""
}
