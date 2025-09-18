locals {
  name          = "${var.project}-${var.env}"
  bucket_claims = "${var.project}-artifacts-${var.env}"
  table_claims  = "claims_${var.env}"

  tags = {
    Project = var.project
    Env     = var.env
    Owner   = "infra"
  }
  # Auto-compute the hosted origin from Amplify unless explicitly provided
  frontend_origin_auto     = "https://${var.amplify_branch_name}.${aws_amplify_app.frontend.default_domain}"
  frontend_origin          = length(trimspace(var.frontend_origin)) > 0 ? var.frontend_origin : local.frontend_origin_auto
  allowed_frontend_origins = var.allow_localhost_in_cors ? ["http://localhost:5173", local.frontend_origin] : [local.frontend_origin]
}



