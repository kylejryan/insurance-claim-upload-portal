// Package models defines the data models used in the application.
package models

// ClaimStatus represents the status of an insurance claim.
type ClaimStatus string

// Possible values for ClaimStatus
const (
	StatusUploading ClaimStatus = "UPLOADING"
	StatusComplete  ClaimStatus = "COMPLETE"
	StatusFailed    ClaimStatus = "FAILED"
)

// Claim represents an insurance claim uploaded by a user.
type Claim struct {
	// DynamoDB keys
	PK string `dynamodbav:"PK"` // USER#<sub>
	SK string `dynamodbav:"SK"` // CLAIM#<claimID> (ULID)

	ClaimID    string      `dynamodbav:"claim_id"`
	UserID     string      `dynamodbav:"user_id"`
	Filename   string      `dynamodbav:"filename"`
	S3Key      string      `dynamodbav:"s3_key"`
	Tags       []string    `dynamodbav:"tags"`
	Client     string      `dynamodbav:"client"`
	Status     ClaimStatus `dynamodbav:"status"`
	UploadedAt string      `dynamodbav:"uploaded_at"` // ISO8601; set by indexer on finalize
	SizeBytes  int64       `dynamodbav:"size_bytes"`
	ETag       string      `dynamodbav:"etag"`
}

// UserClaims represents the JWT claims extracted from the user's authentication token.
type UserClaims struct {
	Sub   string
	Email string
}
