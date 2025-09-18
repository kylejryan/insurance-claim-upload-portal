################################################################################
# AWS Elastic Container Registry (ECR) Repositories
#
# This section defines the ECR repositories used to store Docker images for
# various services. Each repository is configured with essential security
# features, including image scanning and KMS encryption.
################################################################################

#
# ECR Repository for the `api-presign` service.
#
# This repository stores the container image for the Lambda function that
# generates S3 presigned URLs. It's configured to automatically scan images
# for vulnerabilities upon push and encrypts images at rest using KMS.
#
resource "aws_ecr_repository" "api_presign" {
  name         = "${local.name}-api-presign"
  force_delete = true # NOTE: This allows the repository to be deleted even if it contains images.

  tags = local.tags

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }
}

#
# ECR Repository for the `api-list` service.
#
# This repository stores the container image for the Lambda function that
# lists claims from DynamoDB. It's configured with the same security policies
# as the other repositories for consistency.
#
resource "aws_ecr_repository" "api_list" {
  name         = "${local.name}-api-list"
  force_delete = true # NOTE: This allows the repository to be deleted even if it contains images.

  tags = local.tags

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }
}

#
# ECR Repository for the `indexer` service.
#
# This repository stores the container image for the Lambda function that
# processes incoming data. It follows the standard security configuration
# applied to all service repositories.
#
resource "aws_ecr_repository" "indexer" {
  name         = "${local.name}-indexer"
  force_delete = true # NOTE: This allows the repository to be deleted even if it contains images.

  tags = local.tags

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }
}