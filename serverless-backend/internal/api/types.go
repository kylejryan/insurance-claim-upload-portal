// Package api contains types for the API requests and responses.
package api

// PresignRequest represents the request payload for generating a presigned S3 upload URL.
type PresignRequest struct {
	Filename    string   `json:"filename"`
	Tags        []string `json:"tags"`
	Client      string   `json:"client"`
	ContentType string   `json:"content_type"`
}

// PresignResponse represents the response payload containing the presigned S3 upload URL and related info.
type PresignResponse struct {
	ClaimID       string            `json:"claim_id"`
	S3Key         string            `json:"s3_key"`
	PresignedURL  string            `json:"presigned_url"`
	ExpiresIn     int               `json:"expires_in"`
	ContentType   string            `json:"content_type"`
	UploadHeaders map[string]string `json:"upload_headers"`
}
