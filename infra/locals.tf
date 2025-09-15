locals {
  name          = "${var.project}-${var.env}"
  bucket_claims = "${var.project}-artifacts-${var.env}"
  table_claims  = "claims_${var.env}"

  tags = {
    Project = var.project
    Env     = var.env
    Owner   = "infra"
  }
}
