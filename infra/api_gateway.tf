################################################################################
# API Gateway REST API (v1)
#
# This section defines the core REST API, its resources, methods, and
# integrations with backend Lambda functions. It is structured to be
# easily readable and maintainable.
################################################################################

#
# Main REST API resource.
#
# This is the entry point for the API, configured with a regional endpoint
# and tagged for management and cost allocation.
#
resource "aws_api_gateway_rest_api" "main" {
  name        = "${local.name}-api"
  description = "REST API for ${local.name}"
  tags        = local.tags

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

#
# Cognito User Pool Authorizer.
#
# Secures API endpoints by integrating with an existing Cognito User Pool,
# authenticating requests based on the Authorization header.
#
resource "aws_api_gateway_authorizer" "cognito" {
  name            = "${local.name}-cognito-auth"
  rest_api_id     = aws_api_gateway_rest_api.main.id
  type            = "COGNITO_USER_POOLS"
  provider_arns   = [aws_cognito_user_pool.this.arn]
  identity_source = "method.request.header.Authorization"
}

#
# API Resources.
#
# Defines the URI paths for the API.
#
resource "aws_api_gateway_resource" "claims" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "claims"
}

resource "aws_api_gateway_resource" "presign" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.claims.id
  path_part   = "presign"
}

#
# API Methods.
#
# Defines the HTTP methods for each resource and their authorization.
#
resource "aws_api_gateway_method" "get_claims" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.claims.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_method" "post_presign" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.presign.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

#
# Lambda Integrations.
#
# Connects API methods to the appropriate Lambda functions using the AWS_PROXY
# integration type.
#
resource "aws_api_gateway_integration" "list" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.claims.id
  http_method             = aws_api_gateway_method.get_claims.http_method
  integration_http_method = "POST" # Lambda proxy always uses POST
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api_list.invoke_arn
}

resource "aws_api_gateway_integration" "presign" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.presign.id
  http_method             = aws_api_gateway_method.post_presign.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api_presign.invoke_arn
}

#
# CloudWatch Log Group for API Gateway access logs.
#
resource "aws_cloudwatch_log_group" "api_access" {
  name              = "/aws/apigateway/${local.name}"
  retention_in_days = 30
}

#
# API Gateway Stage and Deployment.
#
# This section manages the deployment of the API, including the `prod` stage
# configuration with logging, throttling, and X-Ray tracing.
#
resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  # The `triggers` block ensures a new deployment is created whenever
  # any of the defined API components (resources, methods, integrations, etc.) change.
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.claims.id,
      aws_api_gateway_resource.presign.id,
      aws_api_gateway_method.get_claims.id,
      aws_api_gateway_method.post_presign.id,
      aws_api_gateway_integration.list.id,
      aws_api_gateway_integration.presign.id,
      aws_api_gateway_method.claims_options.id,
      aws_api_gateway_method.presign_options.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  # Dependencies are explicitly defined to ensure resources are created
  # in the correct order before deployment.
  depends_on = [
    aws_api_gateway_method.get_claims,
    aws_api_gateway_method.post_presign,
    aws_api_gateway_integration.list,
    aws_api_gateway_integration.presign,
    aws_api_gateway_method.claims_options,
    aws_api_gateway_integration.claims_options,
    aws_api_gateway_method_response.claims_options,
    aws_api_gateway_integration_response.claims_options,
    aws_api_gateway_method.presign_options,
    aws_api_gateway_integration.presign_options,
    aws_api_gateway_method_response.presign_options,
    aws_api_gateway_integration_response.presign_options,
    aws_api_gateway_gateway_response.default_4xx,
    aws_api_gateway_gateway_response.default_5xx,
  ]
}

resource "aws_api_gateway_stage" "prod" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  deployment_id = aws_api_gateway_deployment.main.id
  stage_name    = "prod"
  tags          = local.tags

  # Ensure API Gateway has a CloudWatch logs role before stage creation.
  # This dependency is crucial for proper log setup.
  depends_on = [aws_api_gateway_account.main]

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_access.arn
    format          = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  xray_tracing_enabled = var.enable_xray
}

#
# Method settings for the 'prod' stage.
#
# Applies a blanket configuration for all methods (`*/*`) on the stage,
# enabling metrics, logging, and throttling.
#
resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.prod.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled        = true
    logging_level          = "INFO"
    throttling_rate_limit  = 2000
    throttling_burst_limit = 5000
  }
}

#
# CORS Configuration.
#
# These resources are grouped together for clarity. They handle the OPTIONS
# method for CORS preflight requests, ensuring the API is accessible from the
# frontend domain.
#
# CORS for `/claims`
resource "aws_api_gateway_method" "claims_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.claims.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "claims_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.claims.id
  http_method = aws_api_gateway_method.claims_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "claims_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.claims.id
  http_method = aws_api_gateway_method.claims_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers"     = true
    "method.response.header.Access-Control-Allow-Methods"     = true
    "method.response.header.Access-Control-Allow-Origin"      = true
    "method.response.header.Access-Control-Allow-Credentials" = true
  }
}

resource "aws_api_gateway_integration_response" "claims_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.claims.id
  http_method = aws_api_gateway_method.claims_options.http_method
  status_code = aws_api_gateway_method_response.claims_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers"     = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods"     = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"      = "'${local.amplify_origin}'"
    "method.response.header.Access-Control-Allow-Credentials" = "'true'"
  }
}

# CORS for `/claims/presign`
resource "aws_api_gateway_method" "presign_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.presign.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "presign_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.presign.id
  http_method = aws_api_gateway_method.presign_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "presign_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.presign.id
  http_method = aws_api_gateway_method.presign_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers"     = true
    "method.response.header.Access-Control-Allow-Methods"     = true
    "method.response.header.Access-Control-Allow-Origin"      = true
    "method.response.header.Access-Control-Allow-Credentials" = true
  }
}

resource "aws_api_gateway_integration_response" "presign_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.presign.id
  http_method = aws_api_gateway_method.presign_options.http_method
  status_code = aws_api_gateway_method_response.presign_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers"     = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods"     = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"      = "'${local.amplify_origin}'"
    "method.response.header.Access-Control-Allow-Credentials" = "'true'"
  }
}

#
# Default Gateway Responses.
#
# These resources set default CORS headers for 4xx and 5xx errors, ensuring
# the frontend can handle errors gracefully.
#
resource "aws_api_gateway_gateway_response" "default_4xx" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  response_type = "DEFAULT_4XX"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin"      = "'${local.amplify_origin}'"
    "gatewayresponse.header.Access-Control-Allow-Headers"     = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods"     = "'GET,POST,OPTIONS'"
    "gatewayresponse.header.Access-Control-Allow-Credentials" = "'true'"
  }
}

resource "aws_api_gateway_gateway_response" "default_5xx" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  response_type = "DEFAULT_5XX"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin"      = "'${local.amplify_origin}'"
    "gatewayresponse.header.Access-Control-Allow-Headers"     = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods"     = "'GET,POST,OPTIONS'"
    "gatewayresponse.header.Access-Control-Allow-Credentials" = "'true'"
  }
}

#
# Lambda Permissions.
#
# Grants API Gateway the necessary permissions to invoke the backend Lambda
# functions.
#
resource "aws_lambda_permission" "api_presign" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_presign.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_list" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_list.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}