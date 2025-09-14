# Lambda Security Groups
resource "aws_security_group" "lambda_presign" {
  name        = "${local.name}-lambda-presign-sg"
  description = "Security group for presign Lambda"
  vpc_id      = aws_vpc.this.id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS to AWS services via VPC endpoints"
  }

  tags = merge(local.tags, { Name = "${local.name}-lambda-presign-sg" })
}

resource "aws_security_group" "lambda_list" {
  name        = "${local.name}-lambda-list-sg"
  description = "Security group for list Lambda"
  vpc_id      = aws_vpc.this.id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS to AWS services via VPC endpoints"
  }

  tags = merge(local.tags, { Name = "${local.name}-lambda-list-sg" })
}

resource "aws_security_group" "lambda_indexer" {
  name        = "${local.name}-lambda-indexer-sg"
  description = "Security group for indexer Lambda"
  vpc_id      = aws_vpc.this.id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS to AWS services via VPC endpoints"
  }

  tags = merge(local.tags, { Name = "${local.name}-lambda-indexer-sg" })
}

# Security group for VPC Interface Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name        = "${local.name}-vpc-endpoints-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    security_groups = [
      aws_security_group.lambda_presign.id,
      aws_security_group.lambda_list.id,
      aws_security_group.lambda_indexer.id
    ]
    description = "HTTPS from Lambda functions"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(local.tags, { Name = "${local.name}-vpc-endpoints-sg" })
}