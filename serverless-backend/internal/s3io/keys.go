package s3io

import (
	"fmt"
	"path/filepath"
	"strings"
)

// Common S3 key patterns and helper functions.
const (
	ContentTypeText = "text/plain"
)

// BuildKey constructs the S3 key for a given userID and claimID.
func BuildKey(userID, claimID string) string {
	return fmt.Sprintf("user/%s/%s.txt", userID, claimID)
}

// ParseKey extracts userID and claimID from the S3 key path.
func ParseKey(key string) (userID, claimID string, ok bool) {
	if strings.ToLower(filepath.Ext(key)) != ".txt" {
		return "", "", false
	}
	parts := strings.Split(key, "/")
	if len(parts) != 3 || parts[0] != "user" {
		return "", "", false
	}
	return parts[1], strings.TrimSuffix(parts[2], ".txt"), true
}

// UploadHeaders builds the required headers for uploading to S3.
// Headers the client must send on PUT (matches your bucket/WAF rules).
func UploadHeaders(userID, claimID, contentType string, tagsCSV, client string) map[string]string {
	if contentType == "" {
		contentType = ContentTypeText
	}
	return map[string]string{
		"Content-Type":                 contentType,
		"x-amz-server-side-encryption": "aws:kms",
		"x-amz-meta-claim_id":          claimID,
		"x-amz-meta-user_id":           userID,
		"x-amz-meta-tags":              tagsCSV,
		"x-amz-meta-client":            client,
	}
}
