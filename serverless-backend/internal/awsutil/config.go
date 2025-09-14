// Package awsutil provides utilities for loading AWS configuration.
package awsutil

import (
	"context"
	"os"

	"github.com/aws/aws-sdk-go-v2/aws"
	awsCfg "github.com/aws/aws-sdk-go-v2/config"
)

// Load loads the AWS configuration, using a custom endpoint if AWS_ENDPOINT_URL is set.
func Load(ctx context.Context, region string) (aws.Config, string, error) {
	endpoint := os.Getenv("AWS_ENDPOINT_URL") // e.g., http://localstack:4566
	if endpoint == "" {
		cfg, err := awsCfg.LoadDefaultConfig(ctx, awsCfg.WithRegion(region))
		return cfg, "", err
	}
	resolver := aws.EndpointResolverWithOptionsFunc(func(service, r string, _ ...any) (aws.Endpoint, error) {
		return aws.Endpoint{
			URL:               endpoint,
			HostnameImmutable: true,
			PartitionID:       "aws",
		}, nil
	})
	cfg, err := awsCfg.LoadDefaultConfig(ctx, awsCfg.WithRegion(region), awsCfg.WithEndpointResolverWithOptions(resolver))
	return cfg, endpoint, err
}
