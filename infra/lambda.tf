################################################################################
# AWS Lambda Functions
#
# This section defines the backend Lambda functions for the application.
# Each function is configured with a specific container image, IAM role,
# network settings (VPC), environment variables, and event triggers.
################################################################################

#
# Local values to compose ECR image URIs.
#
# This logic prioritizes using an immutable image digest for reliability and
# consistent deployments. If the digest is not provided, it falls back to
# the image tag. This is a robust pattern for managing container images.
#
locals {
  presign_image_uri = var.presign_image_digest != "" ? "${aws_ecr_repository.api_presign.repository_url}@${var.presign_image_digest}" : "${aws_ecr_repository.api_presign.repository_url}:${var.image_tag_api_presign}"
  list_image_uri    = var.list_image_digest != "" ? "${aws_ecr_repository.api_list.repository_url}@${var.list_image_digest}" : "${aws_ecr_repository.api_list.repository_url}:${var.image_tag_api_list}"
  indexer_image_uri = var.indexer_image_digest != "" ? "${aws_ecr_repository.indexer.repository_url}@${var.indexer_image_digest}" : "${aws_ecr_repository.indexer.repository_url}:${var.image_tag_indexer}"
}

##################################
# Lambda Function Definitions
##################################

#
# Lambda function for the `presign` API endpoint.
#
# This function handles the creation of presigned URLs for S3 uploads. It runs
# from a container image, has a dedicated IAM role, is placed within a VPC
# for private network access, and is configured with environment variables
# to connect to the correct DynamoDB table and S3 bucket.
#
resource "aws_lambda_function" "api_presign" {
  function_name = "${local.name}-api-presign"
  package_type  = "Image"
  image_uri     = local.presign_image_uri
  role          = aws_iam_role.lambda_presign.arn
  timeout       = 10
  memory_size   = 256
  tags          = local.tags

  tracing_config {
    mode = var.enable_xray ? "Active" : "PassThrough"
  }

  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.lambda_presign.id]
  }

  environment {
    variables = {
      DDB_TABLE       = aws_dynamodb_table.claims.name
      S3_BUCKET       = aws_s3_bucket.claims.bucket
      KMS_KEY         = aws_kms_key.s3.arn
      FRONTEND_ORIGIN = local.amplify_origin
    }
  }
}

#
# Lambda function for the `list` API endpoint.
#
# This function queries the DynamoDB table to retrieve a list of claims. It is
# also container-based, operates within the VPC, and is configured to access
# the DynamoDB table.
#
resource "aws_lambda_function" "api_list" {
  function_name = "${local.name}-api-list"
  package_type  = "Image"
  image_uri     = local.list_image_uri
  role          = aws_iam_role.lambda_list.arn
  timeout       = 10
  memory_size   = 256
  tags          = local.tags

  tracing_config {
    mode = var.enable_xray ? "Active" : "PassThrough"
  }

  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.lambda_list.id]
  }

  environment {
    variables = {
      DDB_TABLE       = aws_dynamodb_table.claims.name
      S3_BUCKET       = aws_s3_bucket.claims.bucket
      KMS_KEY         = aws_kms_key.ddb.arn
      FRONTEND_ORIGIN = local.amplify_origin
    }
  }
}

#
# Lambda function for the `indexer` service.
#
# This function is triggered by S3 object creation events. It processes the
# uploaded file and indexes its contents in DynamoDB.
#
resource "aws_lambda_function" "indexer" {
  function_name = "${local.name}-indexer"
  package_type  = "Image"
  image_uri     = local.indexer_image_uri
  role          = aws_iam_role.lambda_indexer.arn
  timeout       = 20
  memory_size   = 256
  tags          = local.tags

  tracing_config {
    mode = var.enable_xray ? "Active" : "PassThrough"
  }

  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.lambda_indexer.id]
  }

  environment {
    variables = {
      DDB_TABLE = aws_dynamodb_table.claims.name
      S3_BUCKET = aws_s3_bucket.claims.bucket
    }
  }
}

##################################
# CloudWatch Log Groups
##################################

#
# CloudWatch Log Groups with explicit retention policies.
#
# These log groups are created to manage the logs for each Lambda function,
# ensuring a consistent retention period for monitoring and debugging.
#
resource "aws_cloudwatch_log_group" "lg_presign" {
  name              = "/aws/lambda/${aws_lambda_function.api_presign.function_name}"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "lg_list" {
  name              = "/aws/lambda/${aws_lambda_function.api_list.function_name}"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "lg_indexer" {
  name              = "/aws/lambda/${aws_lambda_function.indexer.function_name}"
  retention_in_days = 30
}

##################################
# S3 Event Trigger for Indexer
##################################

#
# Lambda permission for S3 to invoke the indexer function.
#
# This permission is a critical security step, allowing the S3 bucket to
# trigger the `indexer` Lambda function when a new object is created.
#
resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.indexer.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.claims.arn
}

#
# S3 bucket notification configuration.
#
# This resource configures the S3 bucket to send an event to the `indexer`
# Lambda function whenever an object is created in the `user/` prefix with
# a `.txt` suffix.
#
resource "aws_s3_bucket_notification" "claims" {
  bucket = aws_s3_bucket.claims.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.indexer.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "user/"
    filter_suffix       = ".txt"
  }

  # Explicit dependency to ensure the permission is in place before the
  # notification is configured.
  depends_on = [aws_lambda_permission.allow_s3_invoke]
}