################################################################################
# AWS IAM Policies and Roles
#
# This section defines the IAM roles and policies for various services,
# ensuring each component has the minimum required permissions to function.
# It is organized by service for clarity.
################################################################################

#
# Data source to define a common assume role policy for Lambda functions.
#
# This policy allows the Lambda service to assume the role, which is a
# prerequisite for any Lambda execution role.
#
data "aws_iam_policy_document" "assume_lambda" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

##################################
# Lambda Execution Roles
##################################

#
# IAM Role for the `presign` Lambda function.
#
# This role grants the function the necessary permissions to assume a role and
# execute its code.
#
resource "aws_iam_role" "lambda_presign" {
  name               = "${local.name}-lambda-presign"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
  tags               = local.tags
}

#
# IAM Role for the `list` Lambda function.
#
# This role is for the function that queries DynamoDB.
#
resource "aws_iam_role" "lambda_list" {
  name               = "${local.name}-lambda-list"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
  tags               = local.tags
}

#
# IAM Role for the `indexer` Lambda function.
#
# This role is for the function that processes incoming data.
#
resource "aws_iam_role" "lambda_indexer" {
  name               = "${local.name}-lambda-indexer"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
  tags               = local.tags
}

##################################
# Managed Policy Attachments
##################################

#
# Attachments for AWS managed policies.
#
# These policies grant permissions for common services like VPC access and X-Ray
# tracing, simplifying permission management.
#
resource "aws_iam_role_policy_attachment" "vpc_presign" {
  role       = aws_iam_role.lambda_presign.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "vpc_list" {
  role       = aws_iam_role.lambda_list.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "vpc_indexer" {
  role       = aws_iam_role.lambda_indexer.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "xray_presign" {
  count      = var.enable_xray ? 1 : 0
  role       = aws_iam_role.lambda_presign.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_iam_role_policy_attachment" "xray_list" {
  count      = var.enable_xray ? 1 : 0
  role       = aws_iam_role.lambda_list.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_iam_role_policy_attachment" "xray_indexer" {
  count      = var.enable_xray ? 1 : 0
  role       = aws_iam_role.lambda_indexer.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

##################################
# Fine-Grained Inline Policies
##################################

#
# Data source for the `presign` Lambda's policy document.
#
# This policy grants permissions to write to DynamoDB, upload objects to a
# specific S3 path, and use KMS keys for encryption.
#
data "aws_iam_policy_document" "presign" {
  statement {
    sid       = "DDBWrite"
    actions   = ["dynamodb:PutItem", "dynamodb:UpdateItem"]
    resources = [aws_dynamodb_table.claims.arn]
  }

  statement {
    sid       = "S3PutForPresign"
    actions   = ["s3:PutObject", "s3:PutObjectTagging"]
    resources = ["${aws_s3_bucket.claims.arn}/user/*/*"]
  }

  statement {
    sid       = "KmsEncrypt"
    actions   = ["kms:Encrypt", "kms:GenerateDataKey", "kms:Decrypt"]
    resources = [aws_kms_key.s3.arn, aws_kms_key.ddb.arn]
  }
}

#
# Attaches the `presign` policy to its IAM role.
#
resource "aws_iam_role_policy" "presign" {
  role   = aws_iam_role.lambda_presign.id
  name   = "${local.name}-presign-inline"
  policy = data.aws_iam_policy_document.presign.json
}

#
# Data source for the `list` Lambda's policy document.
#
# This policy grants read-only permissions to the DynamoDB table and its
# indexes, along with decryption permissions for the KMS key.
#
data "aws_iam_policy_document" "list" {
  statement {
    sid       = "DDBRead"
    actions   = ["dynamodb:Query", "dynamodb:GetItem", "dynamodb:Scan"]
    resources = [aws_dynamodb_table.claims.arn, "${aws_dynamodb_table.claims.arn}/index/*"]
  }

  statement {
    sid       = "KmsDecrypt"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.ddb.arn]
  }
}

#
# Attaches the `list` policy to its IAM role.
#
resource "aws_iam_role_policy" "list" {
  role   = aws_iam_role.lambda_list.id
  name   = "${local.name}-list-inline"
  policy = data.aws_iam_policy_document.list.json
}

#
# Data source for the `indexer` Lambda's policy document.
#
# This policy grants permissions to read from S3, write to DynamoDB, and use
# the necessary KMS keys.
#
data "aws_iam_policy_document" "indexer" {
  statement {
    sid       = "DDBWrite"
    actions   = ["dynamodb:UpdateItem", "dynamodb:PutItem"]
    resources = [aws_dynamodb_table.claims.arn]
  }

  statement {
    sid       = "S3Read"
    actions   = ["s3:GetObject", "s3:HeadObject", "s3:GetObjectTagging"]
    resources = ["${aws_s3_bucket.claims.arn}/user/*/*"]
  }

  statement {
    sid       = "KmsOperations"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [aws_kms_key.s3.arn, aws_kms_key.ddb.arn]
  }
}

#
# Attaches the `indexer` policy to its IAM role.
#
resource "aws_iam_role_policy" "indexer" {
  role   = aws_iam_role.lambda_indexer.id
  name   = "${local.name}-indexer-inline"
  policy = data.aws_iam_policy_document.indexer.json
}

##################################
# API Gateway CloudWatch Logs Role
##################################

#
# IAM role for API Gateway to write to CloudWatch Logs.
#
# This role is a service-level role required for API Gateway to publish
# execution logs to CloudWatch.
#
resource "aws_iam_role" "api_gateway_cloudwatch" {
  name = "${local.name}-api-gateway-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
    }]
  })

  tags = local.tags
}

#
# Attaches the managed policy for CloudWatch Logs to the API Gateway role.
#
resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  role       = aws_iam_role.api_gateway_cloudwatch.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

#
# Configures the API Gateway account to use the CloudWatch logs role.
#
# This is a one-time configuration per AWS account and is a dependency
# for API Gateway stages that use access logging.
#
resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn

  depends_on = [
    aws_iam_role_policy_attachment.api_gateway_cloudwatch
  ]
}