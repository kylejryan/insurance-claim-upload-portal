resource "aws_dynamodb_table" "claims" {
  name         = local.table_claims
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"
  range_key    = "claim_id"

  attribute {
    name = "user_id"
    type = "S"
  }
  
  attribute {
    name = "claim_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.ddb.arn
  }

  tags = local.tags
}
