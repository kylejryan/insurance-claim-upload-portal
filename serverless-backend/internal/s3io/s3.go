// Package s3io provides utilities for working with S3, including presigning URLs.
package s3io

import (
	"context"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	v4 "github.com/aws/aws-sdk-go-v2/aws/signer/v4"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"
)

// Presigner defines the interface for presigning S3 requests.
type Presigner interface {
	PresignPutObject(ctx context.Context, params *s3.PutObjectInput, optFns ...func(*s3.PresignOptions)) (*v4.PresignedHTTPRequest, error)
}

// PresignPut generates a presigned URL for uploading an object to S3 with the specified parameters.
func PresignPut(ctx context.Context, p Presigner, bucket, key, contentType string, meta map[string]string, ttl time.Duration) (string, time.Duration, error) {
	input := &s3.PutObjectInput{
		Bucket:               aws.String(bucket),
		Key:                  aws.String(key),
		ContentType:          aws.String(contentType),
		Metadata:             meta,
		ServerSideEncryption: types.ServerSideEncryptionAwsKms,

		// If you ever want to force a specific CMK instead of bucket default, also set:
		// SSEKMSKeyId: aws.String(os.Getenv("KMS_KEY_ID")), // Only needed for FedRAMP, HIPAA, etc.
	}

	req, err := p.PresignPutObject(ctx, input, func(o *s3.PresignOptions) { o.Expires = ttl })
	if err != nil {
		return "", 0, err
	}
	return req.URL, ttl, nil
}
