resource "aws_apigatewayv2_api" "http" {
  name          = "${local.name}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins     = var.cognito_callback_urls
    allow_methods     = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers     = ["*"]
    expose_headers    = ["*"]
    max_age           = 3600
    allow_credentials = true
  }

  tags = local.tags
}

# JWT Authorizer (Cognito)
resource "aws_apigatewayv2_authorizer" "jwt" {
  api_id           = aws_apigatewayv2_api.http.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "${local.name}-jwt"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.this.id]
    issuer   = "https://cognito-idp.${var.region}.amazonaws.com/${aws_cognito_user_pool.this.id}"
  }
}

# Integrations (Lambda proxy)
resource "aws_apigatewayv2_integration" "presign" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_presign.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "list" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_list.invoke_arn
  payload_format_version = "2.0"
}

# Routes
resource "aws_apigatewayv2_route" "post_presign" {
  api_id             = aws_apigatewayv2_api.http.id
  route_key          = "POST /claims/presign"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
  target             = "integrations/${aws_apigatewayv2_integration.presign.id}"
}

resource "aws_apigatewayv2_route" "get_claims" {
  api_id             = aws_apigatewayv2_api.http.id
  route_key          = "GET /claims"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
  target             = "integrations/${aws_apigatewayv2_integration.list.id}"
}

# Stage with access logs
resource "aws_cloudwatch_log_group" "api_access" {
  name              = "/aws/apigw/${local.name}"
  retention_in_days = 30
}

resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "prod"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_access.arn
    format = jsonencode({
      requestId  = "$context.requestId",
      httpMethod = "$context.httpMethod",
      routeKey   = "$context.routeKey",
      status     = "$context.status",
      caller     = "$context.identity.caller",
      user       = "$context.identity.user"
    })
  }
}

# Allow API Gateway to invoke Lambdas
resource "aws_lambda_permission" "api_presign" {
  statement_id  = "AllowAPIGwInvokePresign"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_presign.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_list" {
  statement_id  = "AllowAPIGwInvokeList"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_list.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}