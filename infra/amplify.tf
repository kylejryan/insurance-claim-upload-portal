################################################################################
# AWS Amplify Hosting (Frontend)
################################################################################

#
# Creates the Amplify application for the frontend.
#
# This resource represents the container for all branches and settings.
# It is tagged for cost allocation and management.
#
resource "aws_amplify_app" "frontend" {
  name     = "${local.name}-frontend"
  platform = "WEB"
  tags     = local.tags
}

#
# Defines the production branch for the Amplify application.
#
# This branch is configured for manual builds triggered by a separate process
# (e.g., a CI/CD pipeline or a Makefile) and sets the necessary environment
# variables for the frontend to connect to backend services.
#
resource "aws_amplify_branch" "prod" {
  app_id                = aws_amplify_app.frontend.id
  branch_name           = var.amplify_branch_name # e.g., "prod"
  stage                 = "PRODUCTION"
  enable_auto_build     = false                   # Builds are triggered externally
  framework             = "React"
  tags                  = local.tags
  environment_variables = local.amplify_env
}

#
# Local values for the Amplify application.
#
# These locals provide a clean way to define shared values, such as the
# frontend's public URL and build-time environment variables.
#
locals {
  # Public URL for the frontend, constructed from the branch name and app domain.
  # This is used for redirects and is independent of the `aws_amplify_branch`
  # resource to prevent circular dependencies.
  amplify_origin = "https://${var.amplify_branch_name}.${aws_amplify_app.frontend.default_domain}"

  # Base environment variables required for the Vite build process.
  amplify_env_base = {
    VITE_AWS_REGION          = var.region
    VITE_USER_POOL_ID        = aws_cognito_user_pool.this.id
    VITE_USER_POOL_CLIENT_ID = aws_cognito_user_pool_client.this.id
    VITE_API_BASE            = aws_api_gateway_stage.prod.invoke_url
    VITE_REDIRECT_URI        = "${local.amplify_origin}/callback"
  }

  # Merges the base environment variables with the Cognito domain if it exists.
  amplify_env = (
    length(trimspace(aws_cognito_user_pool_domain.this.domain)) > 0
    ? merge(local.amplify_env_base, { VITE_COGNITO_DOMAIN = aws_cognito_user_pool_domain.this.domain })
    : local.amplify_env_base
  )
}