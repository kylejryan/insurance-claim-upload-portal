resource "aws_vpc" "this" {
  cidr_block           = var.cidr_vpc
  enable_dns_hostnames = true
  tags = merge(local.tags, { Name = "${local.name}-vpc" })
}

resource "aws_subnet" "private_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.cidr_private_a
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = false
  tags = merge(local.tags, { Name = "${local.name}-private-a", Tier = "private" })
}

resource "aws_subnet" "private_b" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.cidr_private_b
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = false
  tags = merge(local.tags, { Name = "${local.name}-private-b", Tier = "private" })
}

resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${local.name}-rt-private-a" })
}
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_a.id
}

resource "aws_route_table" "private_b" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${local.name}-rt-private-b" })
}
resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_b.id
}

# Gateway VPC endpoints (no NAT; all AWS calls use VPCE)
resource "aws_vpc_endpoint" "s3" {
  vpc_id          = aws_vpc.this.id
  service_name    = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [aws_route_table.private_a.id, aws_route_table.private_b.id]
  tags = merge(local.tags, { Name = "${local.name}-vpce-s3" })
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id          = aws_vpc.this.id
  service_name    = "com.amazonaws.${var.region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [aws_route_table.private_a.id, aws_route_table.private_b.id]
  tags = merge(local.tags, { Name = "${local.name}-vpce-dynamodb" })
}

# KMS endpoint for encryption/decryption
resource "aws_vpc_endpoint" "kms" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.kms"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  tags = merge(local.tags, { Name = "${local.name}-vpce-kms" })
}

# Lambda endpoint for invoking functions
resource "aws_vpc_endpoint" "lambda" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.lambda"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  tags = merge(local.tags, { Name = "${local.name}-vpce-lambda" })
}

# CloudWatch Logs endpoint
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  tags = merge(local.tags, { Name = "${local.name}-vpce-logs" })
}