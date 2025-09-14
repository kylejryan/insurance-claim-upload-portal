output "api_base_url"     { value = aws_apigatewayv2_stage.prod.invoke_url }
output "cognito_pool_id"  { value = aws_cognito_user_pool.this.id }
output "cognito_client_id"{ value = aws_cognito_user_pool_client.this.id }
output "cognito_domain"   { value = aws_cognito_user_pool_domain.this.domain }
output "s3_bucket"        { value = aws_s3_bucket.claims.bucket }
output "ddb_table"        { value = aws_dynamodb_table.claims.name }
