resource "aws_kms_key" "s3" {
  description             = "KMS key for ${local.name} S3 bucket"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = local.tags
}

resource "aws_kms_alias" "s3" {
  name          = "alias/${local.name}-s3"
  target_key_id = aws_kms_key.s3.id
}

resource "aws_kms_key" "ddb" {
  description             = "KMS key for ${local.name} DynamoDB"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = local.tags
}

resource "aws_kms_alias" "ddb" {
  name          = "alias/${local.name}-ddb"
  target_key_id = aws_kms_key.ddb.id
}