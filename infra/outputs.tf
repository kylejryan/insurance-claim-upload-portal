output "api_base_url" {
  value       = aws_api_gateway_stage.prod.invoke_url
  description = "Base URL for the REST API"
}

output "cognito_pool_id" {
  value       = aws_cognito_user_pool.this.id
  description = "Cognito User Pool ID"
}

output "cognito_client_id" {
  value       = aws_cognito_user_pool_client.this.id
  description = "Cognito User Pool Client ID"
}

output "cognito_domain" {
  value       = aws_cognito_user_pool_domain.this.domain
  description = "Cognito hosted UI domain"
}

output "s3_bucket" {
  value       = aws_s3_bucket.claims.bucket
  description = "S3 bucket for claim artifacts"
}

output "ddb_table" {
  value       = aws_dynamodb_table.claims.name
  description = "DynamoDB table name"
}

output "api_endpoints" {
  value = {
    list_claims    = "${aws_api_gateway_stage.prod.invoke_url}/claims"
    presign_upload = "${aws_api_gateway_stage.prod.invoke_url}/claims/presign"
  }
  description = "API endpoint URLs"
}

output "amplify_app_id" { value = aws_amplify_app.frontend.id }
output "amplify_branch_name" { value = aws_amplify_branch.prod.branch_name }
output "amplify_default_domain" { value = aws_amplify_app.frontend.default_domain }
output "amplify_branch_url" { value = local.amplify_origin }
