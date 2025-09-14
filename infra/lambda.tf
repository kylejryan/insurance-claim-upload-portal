# Compose ECR image URIs
locals {
  ecr_api_presign_uri = "${aws_ecr_repository.api_presign.repository_url}:${var.image_tag_api_presign}"
  ecr_api_list_uri    = "${aws_ecr_repository.api_list.repository_url}:${var.image_tag_api_list}"
  ecr_indexer_uri     = "${aws_ecr_repository.indexer.repository_url}:${var.image_tag_indexer}"
}

# Presign endpoint Lambda
resource "aws_lambda_function" "api_presign" {
  function_name = "${local.name}-api-presign"
  package_type  = "Image"
  image_uri     = local.ecr_api_presign_uri
  role          = aws_iam_role.lambda_presign.arn
  timeout       = 10
  memory_size   = 256
  
  tracing_config {
    mode = var.enable_xray ? "Active" : "PassThrough"
  }
  
  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.lambda_presign.id]
  }
  
  environment {
    variables = {
      DDB_TABLE = aws_dynamodb_table.claims.name
      S3_BUCKET = aws_s3_bucket.claims.bucket
      KMS_KEY   = aws_kms_key.s3.arn
    }
  }
  
  tags = local.tags
}

# List endpoint Lambda
resource "aws_lambda_function" "api_list" {
  function_name = "${local.name}-api-list"
  package_type  = "Image"
  image_uri     = local.ecr_api_list_uri
  role          = aws_iam_role.lambda_list.arn
  timeout       = 10
  memory_size   = 256
  
  tracing_config {
    mode = var.enable_xray ? "Active" : "PassThrough"
  }
  
  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.lambda_list.id]
  }
  
  environment {
    variables = {
      DDB_TABLE = aws_dynamodb_table.claims.name
    }
  }
  
  tags = local.tags
}

# Indexer (S3 event) Lambda
resource "aws_lambda_function" "indexer" {
  function_name = "${local.name}-indexer"
  package_type  = "Image"
  image_uri     = local.ecr_indexer_uri
  role          = aws_iam_role.lambda_indexer.arn
  timeout       = 20
  memory_size   = 256
  
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
  
  tags = local.tags
}

# CloudWatch log groups (explicit retention)
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

# S3 -> Indexer trigger
resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.indexer.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.claims.arn
}

resource "aws_s3_bucket_notification" "claims" {
  bucket = aws_s3_bucket.claims.id
  
  lambda_function {
    lambda_function_arn = aws_lambda_function.indexer.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "user/"
    filter_suffix       = ".txt"
  }
  
  depends_on = [aws_lambda_permission.allow_s3_invoke]
}
