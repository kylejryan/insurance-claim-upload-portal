resource "aws_ecr_repository" "api_presign" {
  name                 = "${local.name}-api-presign"
  force_delete         = true # allows deletion even if images are present
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "KMS" }
  tags = local.tags
}

resource "aws_ecr_repository" "api_list" {
  name                 = "${local.name}-api-list"
  force_delete         = true # allows deletion even if images are present
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "KMS" }
  tags = local.tags
}

resource "aws_ecr_repository" "indexer" {
  name                 = "${local.name}-indexer"
  force_delete         = true # allows deletion even if images are present
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "KMS" }
  tags = local.tags
}
