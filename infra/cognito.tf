resource "aws_cognito_user_pool" "this" {
  name = "${local.name}-users"
  
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
  
  tags = local.tags
}

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
  callback_urls                        = var.cognito_callback_urls
  logout_urls                          = var.cognito_logout_urls
}

resource "aws_cognito_user_pool_domain" "this" {
  domain       = "${local.name}-${random_string.cog.id}"
  user_pool_id = aws_cognito_user_pool.this.id
}

resource "random_string" "cog" {
  length  = 6
  special = false
  upper   = false
}