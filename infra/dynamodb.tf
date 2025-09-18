################################################################################
# AWS DynamoDB Table
#
# This section defines the `claims` DynamoDB table, configured for on-demand
# billing, strong consistency, and enhanced security features like
# Point-in-Time Recovery and KMS encryption.
################################################################################

#
# Creates the `claims` DynamoDB table.
#
# Configured with `PAY_PER_REQUEST` billing for on-demand scaling. It uses a
# composite primary key of `user_id` (partition key) and `claim_id` (sort key)
# for efficient data access patterns.
#
resource "aws_dynamodb_table" "claims" {
  name         = local.table_claims
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"
  range_key    = "claim_id"
  tags         = local.tags

  # Defines the attributes for the primary key.
  attribute {
    name = "user_id"
    type = "S" # String
  }

  attribute {
    name = "claim_id"
    type = "S" # String
  }

  #
  # Point-in-Time Recovery (PITR).
  #
  # Enables continuous backups of the table, allowing for restoration to any
  # point in time within the last 35 days.
  #
  point_in_time_recovery {
    enabled = true
  }

  #
  # Server-Side Encryption (SSE) with KMS.
  #
  # Encrypts data at rest using a customer-managed KMS key, providing enhanced
  # security and control over the encryption process.
  #
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.ddb.arn
  }
}