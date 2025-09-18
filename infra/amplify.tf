# ============================
# Amplify Hosting (frontend)
# ============================

resource "aws_amplify_app" "frontend" {
  name     = "${local.name}-frontend"
  platform = "WEB"
  tags     = local.tags
}

# --- Public URL (no dependency on branch resource) ---
# Use the requested branch name + app default domain.
locals {
  amplify_origin = "https://${var.amplify_branch_name}.${aws_amplify_app.frontend.default_domain}"
}

# --- Build-time env vars for Vite ---
# These are set on the Amplify branch so builds have everything they need.
locals {
  amplify_env_base = {
    VITE_AWS_REGION          = var.region
    VITE_USER_POOL_ID        = aws_cognito_user_pool.this.id
    VITE_USER_POOL_CLIENT_ID = aws_cognito_user_pool_client.this.id
    VITE_API_BASE            = aws_api_gateway_stage.prod.invoke_url
    VITE_REDIRECT_URI        = "${local.amplify_origin}/callback"
  }

  # Optionally include Cognito domain if present
  amplify_env = (
    length(trimspace(aws_cognito_user_pool_domain.this.domain)) > 0
    ? merge(local.amplify_env_base, { VITE_COGNITO_DOMAIN = aws_cognito_user_pool_domain.this.domain })
    : local.amplify_env_base
  )
}

resource "aws_amplify_branch" "prod" {
  app_id            = aws_amplify_app.frontend.id
  branch_name       = var.amplify_branch_name           # e.g., "prod"
  stage             = "PRODUCTION"
  enable_auto_build = false                             # using zip upload via Makefile
  framework         = "React"
  tags              = local.tags

  # Keep env vars in TF (no CLI drift) — safe because amplify_origin doesn't
  # depend on this branch resource (it uses var.amplify_branch_name).
  environment_variables = local.amplify_env
}
