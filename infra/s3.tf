resource "aws_s3_bucket" "claims" {
  bucket        = local.bucket_claims
  force_destroy = true
  tags          = local.tags
}

resource "aws_s3_bucket_ownership_controls" "claims" {
  bucket = aws_s3_bucket.claims.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "claims" {
  bucket                  = aws_s3_bucket.claims.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

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
}