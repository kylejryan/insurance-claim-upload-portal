resource "aws_ecr_repository" "api_presign" {
  name = "${local.name}-api-presign"
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "KMS" }
  tags = local.tags
}

resource "aws_ecr_repository" "api_list" {
  name = "${local.name}-api-list"
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "KMS" }
  tags = local.tags
}

resource "aws_ecr_repository" "indexer" {
  name = "${local.name}-indexer"
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "KMS" }
  tags = local.tags
}
