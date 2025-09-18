################################################################################
# AWS Key Management Service (KMS) Keys
#
# This section defines the Customer Master Keys (CMKs) used for
# server-side encryption of data in S3 and DynamoDB. Each key is
# configured with a deletion policy and automatic key rotation for enhanced
# security.
################################################################################

#
# KMS key for S3 bucket encryption.
#
# This key is used to encrypt data stored in the S3 bucket, ensuring data
# at rest is protected. It has a 7-day deletion window to prevent accidental
# loss and key rotation enabled for ongoing security.
#
resource "aws_kms_key" "s3" {
  description             = "KMS key for ${local.name} S3 bucket"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = local.tags
}

#
# KMS alias for the S3 key.
#
# An alias provides a user-friendly name for the key, making it easier to
# reference in other resources and IAM policies.
#
resource "aws_kms_alias" "s3" {
  name          = "alias/${local.name}-s3"
  target_key_id = aws_kms_key.s3.id
}

#
# KMS key for DynamoDB table encryption.
#
# This key is used to encrypt data stored in the DynamoDB table, supporting
# the server-side encryption configuration. It follows the same security
# best practices as the S3 key.
#
resource "aws_kms_key" "ddb" {
  description             = "KMS key for ${local.name} DynamoDB"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = local.tags
}

#
# KMS alias for the DynamoDB key.
#
# Provides a clean and descriptive alias for the DynamoDB encryption key.
#
resource "aws_kms_alias" "ddb" {
  name          = "alias/${local.name}-ddb"
  target_key_id = aws_kms_key.ddb.id
}