################################################################################
# AWS S3 Bucket
#
# This section defines the S3 bucket used for storing claim artifacts. It is
# configured with a strong security posture, including server-side encryption,
# public access blocking, and a bucket policy that enforces secure transport
# and encryption at upload time.
################################################################################

#
# Creates the S3 bucket for claim artifacts.
#
# The `force_destroy = true` setting allows the bucket and its contents to be
# deleted when `terraform destroy` is run. This is useful for development
# environments but should be handled with care in production.
#
resource "aws_s3_bucket" "claims" {
  bucket        = local.bucket_claims
  force_destroy = true
  tags          = local.tags
}

#
# S3 Bucket Ownership Controls.
#
# This configuration enforces that all objects uploaded to the bucket are
# owned by the bucket owner, preventing issues with objects uploaded by
# different accounts or users. `BucketOwnerEnforced` simplifies permission
# management by disabling ACLs.
#
resource "aws_s3_bucket_ownership_controls" "claims" {
  bucket = aws_s3_bucket.claims.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

#
# S3 Bucket Public Access Block.
#
# This is a critical security control that blocks all forms of public access
# to the bucket and its contents, including public ACLs and policies.
# This ensures the bucket remains private and secure.
#
resource "aws_s3_bucket_public_access_block" "claims" {
  bucket                  = aws_s3_bucket.claims.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#
# S3 Bucket Server-Side Encryption (SSE) Configuration.
#
# This configuration enforces server-side encryption on all objects in the
# bucket by default, using a dedicated KMS key. `bucket_key_enabled = true`
# reduces encryption costs.
#
resource "aws_s3_bucket_server_side_encryption_configuration" "claims" {
  bucket = aws_s3_bucket.claims.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

#
# S3 Bucket CORS (Cross-Origin Resource Sharing) Configuration.
#
# This enables the bucket to accept requests from the specified frontend origin,
# which is necessary for the browser-based uploads (e.g., via presigned URLs).
# It defines allowed HTTP methods, origins, and headers.
#
resource "aws_s3_bucket_cors_configuration" "claims" {
  bucket = aws_s3_bucket.claims.id

  cors_rule {
    allowed_methods = ["PUT", "HEAD", "GET"]
    allowed_origins = [local.amplify_origin]
    allowed_headers = ["*"]
    expose_headers  = ["ETag", "x-amz-checksum-crc64nvme", "x-amz-server-side-encryption", "x-amz-version-id"]
    max_age_seconds = 3600
  }
}

#
# S3 Bucket Policy.
#
# This policy adds an additional layer of security by explicitly denying
# two common insecure scenarios:
# 1. **Deny Insecure Transport:** Prevents any access to the bucket over
#    non-HTTPS connections.
# 2. **Enforce KMS:** Denies `s3:PutObject` requests unless the `aws:kms`
#    server-side encryption header is present, enforcing client-side
#    encryption or an explicit decision to use the KMS key.
#
data "aws_iam_policy_document" "claims_bucket_policy" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.claims.arn, "${aws_s3_bucket.claims.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid       = "EnforceKms"
    effect    = "Deny"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.claims.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms"]
    }
  }
}

resource "aws_s3_bucket_policy" "claims" {
  bucket = aws_s3_bucket.claims.id
  policy = data.aws_iam_policy_document.claims_bucket_policy.json

  depends_on = [
    aws_s3_bucket.claims,
  ]
}