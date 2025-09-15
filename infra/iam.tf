data "aws_iam_policy_document" "assume_lambda" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# --- Roles (one per function) ---
resource "aws_iam_role" "lambda_presign" {
  name               = "${local.name}-lambda-presign"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
  tags               = local.tags
}

resource "aws_iam_role" "lambda_list" {
  name               = "${local.name}-lambda-list"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
  tags               = local.tags
}

resource "aws_iam_role" "lambda_indexer" {
  name               = "${local.name}-lambda-indexer"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
  tags               = local.tags
}

# VPC Lambda Execution Role (required for VPC access)
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

# Optional X-Ray tracing
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

# Fine-grained inline policies for each Lambda function
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

resource "aws_iam_role_policy" "presign" {
  role   = aws_iam_role.lambda_presign.id
  name   = "${local.name}-presign-inline"
  policy = data.aws_iam_policy_document.presign.json
}

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

resource "aws_iam_role_policy" "list" {
  role   = aws_iam_role.lambda_list.id
  name   = "${local.name}-list-inline"
  policy = data.aws_iam_policy_document.list.json
}

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

resource "aws_iam_role_policy" "indexer" {
  role   = aws_iam_role.lambda_indexer.id
  name   = "${local.name}-indexer-inline"
  policy = data.aws_iam_policy_document.indexer.json
}

# IAM role for API Gateway to write to CloudWatch Logs
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

# Attach the AWS managed policy for CloudWatch Logs
resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  role       = aws_iam_role.api_gateway_cloudwatch.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# Configure API Gateway account settings with the CloudWatch role
# This is a one-time account-level configuration
resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn

  depends_on = [
    aws_iam_role_policy_attachment.api_gateway_cloudwatch
  ]
}