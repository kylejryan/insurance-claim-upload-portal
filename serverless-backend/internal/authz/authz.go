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
	// 0) Dev bypass header
	if devBypass {
		if sub := strings.TrimSpace(headerLookup(req.Headers, devBypassHeader)); sub != "" {
			return sub, nil
		}
	}

	// 1) Cognito authorizer map (can contain "claims" or top-level fields)
	if m := req.RequestContext.Authorizer; m != nil {
		if sub := subFromClaims(m["claims"]); sub != "" {
			return sub, nil
		}
		if sub := stringIf(m["sub"]); sub != "" {
			return sub, nil
		}
		if sub := stringIf(m["principalId"]); sub != "" {
			return sub, nil
		}
	}

	// 2) Fallback: parse JWT from Authorization header (unverified)
	if sub := subFromAuthHeader(req.Headers); sub != "" {
		return sub, nil
	}

	return "", ErrUnauthorized
}
