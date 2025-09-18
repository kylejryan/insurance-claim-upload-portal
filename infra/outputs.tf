################################################################################
# Terraform Outputs
#
# This file defines the outputs of the Terraform configuration. Outputs provide
# a clean interface to retrieve important information about the deployed
# infrastructure, such as URLs, IDs, and names, for use in other configurations
# or for manual inspection.
################################################################################

#
# API Gateway Outputs.
#
# These outputs provide the base URL and specific endpoint URLs for the
# REST API, which are essential for the frontend and other services to
# communicate with the backend.
#
output "api_base_url" {
  value       = aws_api_gateway_stage.prod.invoke_url
  description = "Base URL for the REST API."
}

output "api_endpoints" {
  value = {
    list_claims    = "${aws_api_gateway_stage.prod.invoke_url}/claims"
    presign_upload = "${aws_api_gateway_stage.prod.invoke_url}/claims/presign"
  }
  description = "The specific URLs for API endpoints."
}

#
# AWS Cognito Outputs.
#
# These outputs provide the necessary information for the frontend to
# integrate with the Cognito User Pool for user authentication.
#
output "cognito_pool_id" {
  value       = aws_cognito_user_pool.this.id
  description = "The ID of the Cognito User Pool."
}

output "cognito_client_id" {
  value       = aws_cognito_user_pool_client.this.id
  description = "The ID of the Cognito User Pool Client."
}

output "cognito_domain" {
  value       = aws_cognito_user_pool_domain.this.domain
  description = "The domain for the Cognito hosted UI."
}

#
# AWS Amplify Outputs.
#
# These outputs provide key details about the Amplify application, which are
# useful for configuring CI/CD pipelines and the frontend application itself.
#
output "amplify_app_id" {
  value       = aws_amplify_app.frontend.id
  description = "The ID of the Amplify application."
}

output "amplify_branch_name" {
  value       = aws_amplify_branch.prod.branch_name
  description = "The name of the deployed Amplify branch."
}

output "amplify_default_domain" {
  value       = aws_amplify_app.frontend.default_domain
  description = "The default domain provided by Amplify."
}

output "amplify_branch_url" {
  value       = local.amplify_origin
  description = "The full URL of the deployed Amplify branch."
}

#
# Data Storage Outputs.
#
# These outputs provide the names of the S3 bucket and DynamoDB table,
# which are useful for administrative tasks or for passing to other
# configurations.
#
output "s3_bucket" {
  value       = aws_s3_bucket.claims.bucket
  description = "The name of the S3 bucket for claim artifacts."
}

output "ddb_table" {
  value       = aws_dynamodb_table.claims.name
  description = "The name of the DynamoDB table."
}