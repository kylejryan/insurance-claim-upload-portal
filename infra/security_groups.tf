################################################################################
# AWS Security Groups
#
# This section defines the security groups for the Lambda functions and the
# VPC interface endpoints. Security groups act as a virtual firewall to
# control inbound and outbound traffic.
################################################################################

#
# Security Group for the `presign` Lambda function.
#
# This security group controls network traffic for the Lambda function.
# It has no inbound rules because Lambda functions are typically invoked
# internally or by other services (like API Gateway) and do not accept
# direct public connections. The single outbound rule allows the function
# to make HTTPS requests to AWS services via VPC endpoints.
#
resource "aws_security_group" "lambda_presign" {
  name        = "${local.name}-lambda-presign-sg"
  description = "Security group for presign Lambda."
  vpc_id      = aws_vpc.this.id

  # Defines outbound traffic rules.
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allows outbound HTTPS traffic to AWS services via VPC endpoints."
  }

  tags = merge(local.tags, { Name = "${local.name}-lambda-presign-sg" })
}

#
# Security Group for the `list` Lambda function.
#
# This security group follows the same pattern as the `presign` Lambda,
# providing controlled outbound access for the function that queries DynamoDB.
#
resource "aws_security_group" "lambda_list" {
  name        = "${local.name}-lambda-list-sg"
  description = "Security group for list Lambda."
  vpc_id      = aws_vpc.this.id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allows outbound HTTPS traffic to AWS services via VPC endpoints."
  }

  tags = merge(local.tags, { Name = "${local.name}-lambda-list-sg" })
}

#
# Security Group for the `indexer` Lambda function.
#
# This security group is for the Lambda that processes S3 events. It also
# only requires outbound access to communicate with other AWS services
# like DynamoDB.
#
resource "aws_security_group" "lambda_indexer" {
  name        = "${local.name}-lambda-indexer-sg"
  description = "Security group for indexer Lambda."
  vpc_id      = aws_vpc.this.id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allows outbound HTTPS traffic to AWS services via VPC endpoints."
  }

  tags = merge(local.tags, { Name = "${local.name}-lambda-indexer-sg" })
}

#
# Security Group for VPC Interface Endpoints.
#
# This security group is attached to the VPC endpoints themselves. It's
# configured to allow inbound HTTPS traffic *only* from the specific Lambda
# security groups, enforcing a principle of least privilege.
#
resource "aws_security_group" "vpc_endpoints" {
  name        = "${local.name}-vpc-endpoints-sg"
  description = "Security group for VPC endpoints."
  vpc_id      = aws_vpc.this.id

  # Inbound rule to allow HTTPS from the Lambda security groups.
  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    # References the other security groups, creating a secure trust relationship.
    security_groups = [
      aws_security_group.lambda_presign.id,
      aws_security_group.lambda_list.id,
      aws_security_group.lambda_indexer.id
    ]
    description = "Allows inbound HTTPS traffic from Lambda functions."
  }

  # Outbound rule for the endpoints. This is generally permissive since
  # the endpoints act as a passthrough to AWS services.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allows all outbound traffic."
  }

  tags = merge(local.tags, { Name = "${local.name}-vpc-endpoints-sg" })
}