################################################################################
# AWS Cognito User Pool
#
# This section defines the Cognito User Pool, its clients, and the custom
# domain for hosting the sign-in and sign-up UI.
################################################################################

#
# Creates the Cognito User Pool.
#
# This user pool is the core directory for managing user identities. It's
# configured to use email as the primary username attribute and automatically
# verifies new users' emails. The password policy is set to enforce strong
# security, and account recovery is enabled via a verified email.
#
resource "aws_cognito_user_pool" "this" {
  name                     = "${local.name}-users"
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]
  tags                     = local.tags

  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  password_policy {
    minimum_length    = 12
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }
}

#
# Creates the Cognito User Pool Client.
#
# This client is an app that can interact with the user pool. It's configured
# for a frontend application, allowing standard OAuth 2.0 flows (Authorization
# Code Grant). It prevents user existence errors and supports allowed callback
# and logout URLs.
#
resource "aws_cognito_user_pool_client" "this" {
  name                                 = "${local.name}-client"
  user_pool_id                         = aws_cognito_user_pool.this.id
  generate_secret                      = false
  prevent_user_existence_errors        = "ENABLED"
  explicit_auth_flows                  = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH", "ALLOW_USER_SRP_AUTH"]
  supported_identity_providers         = ["COGNITO"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  callback_urls                        = local.cognito_callback_urls
  logout_urls                          = local.cognito_logout_urls
}

#
# Creates the custom domain for the Cognito UI.
#
# A custom domain provides a branded URL for the hosted sign-in and sign-up
# pages. A `random_string` resource is used to ensure the domain name is
# globally unique as required by Cognito.
#
resource "aws_cognito_user_pool_domain" "this" {
  domain       = "${local.name}-${random_string.cog.id}"
  user_pool_id = aws_cognito_user_pool.this.id
}

#
# Generates a random string to ensure a unique Cognito domain name.
#
resource "random_string" "cog" {
  length  = 6
  special = false
  upper   = false
}

#
# Local values for Cognito URLs.
#
# This section dynamically generates the list of callback and logout URLs.
# It conditionally includes `localhost` for local development based on the
# `var.allow_localhost_in_cors` flag.
#
locals {
  cognito_callback_urls = var.allow_localhost_in_cors ? [
    "http://localhost:5173/callback",
    "${local.frontend_origin}/callback",
  ] : [
    "${local.frontend_origin}/callback",
  ]

  cognito_logout_urls = var.allow_localhost_in_cors ? [
    "http://localhost:5173",
    local.frontend_origin,
  ] : [
    local.frontend_origin,
  ]
}