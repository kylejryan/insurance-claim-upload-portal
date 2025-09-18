################################################################################
# Local Values
#
# This file centralizes all local variables and computed values, providing a
# single source of truth for names, tags, and dynamic configurations.
################################################################################

#
# Core Naming and Tagging.
#
# These variables define consistent naming conventions and a standardized set
# of tags applied to all resources for easier management and cost tracking.
#
locals {
  # A standardized name prefix for all resources, based on the project and environment.
  name = "${var.project}-${var.env}"

  # Resource-specific names, following the naming convention.
  bucket_claims = "${var.project}-artifacts-${var.env}"
  table_claims  = "claims_${var.env}"

  # Standard tags applied to all resources.
  tags = {
    Project = var.project
    Env     = var.env
    Owner   = "infra"
  }
}

#
# Frontend and CORS Configuration.
#
# These variables dynamically determine the frontend's origin URL and the
# list of allowed CORS origins, supporting both hosted and local development
# environments.
#
locals {
  # Automatically computes the frontend origin URL from the Amplify app details.
  # This provides a default value that works out-of-the-box.
  frontend_origin_auto = "https://${var.amplify_branch_name}.${aws_amplify_app.frontend.default_domain}"

  # The definitive frontend origin. If a value is provided via the `frontend_origin`
  # variable, it's used; otherwise, the auto-computed URL is used.
  frontend_origin = length(trimspace(var.frontend_origin)) > 0 ? var.frontend_origin : local.frontend_origin_auto

  # A list of allowed origins for CORS policies. It conditionally includes
  # the local development URL to enable local testing without requiring
  # manual changes.
  allowed_frontend_origins = var.allow_localhost_in_cors ? ["http://localhost:5173", local.frontend_origin] : [local.frontend_origin]
}