################################################################################
# AWS Virtual Private Cloud (VPC) and Networking
#
# This file defines the core network infrastructure, including the VPC,
# subnets, route tables, and VPC endpoints. This setup creates a secure,
# private network for the application's backend services.
################################################################################

#
# Creates the VPC.
#
# The VPC is the logical isolation layer for all network resources. DNS hostnames
# are enabled to allow public DNS names to resolve to private IP addresses,
# which is important for communication within the VPC.
#
resource "aws_vpc" "this" {
  cidr_block           = var.cidr_vpc
  enable_dns_hostnames = true
  tags                 = merge(local.tags, { Name = "${local.name}-vpc" })
}

#
# Creates two private subnets.
#
# These subnets are designed to host private resources like Lambda functions.
# They are not associated with an Internet Gateway, and `map_public_ip_on_launch`
# is set to false to prevent accidental public access. They are spread across
# different Availability Zones for high availability.
#
resource "aws_subnet" "private_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.cidr_private_a
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = false
  tags                    = merge(local.tags, { Name = "${local.name}-private-a", Tier = "private" })
}

resource "aws_subnet" "private_b" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.cidr_private_b
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = false
  tags                    = merge(local.tags, { Name = "${local.name}-private-b", Tier = "private" })
}

#
# Defines route tables for the private subnets.
#
# Route tables control the traffic flow for subnets. These tables are configured
# to route traffic destined for AWS services through VPC endpoints, ensuring
# that all internal communication remains on the AWS private network,
# which is more secure and performant.
#
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

#
# VPC Endpoints.
#
# VPC Endpoints enable private connectivity to AWS services without requiring
# an Internet Gateway, NAT Gateway, or public IPs. This significantly enhances
# the security of the application. There are two types of endpoints:
#
# 1. **Gateway Endpoints:** Used for S3 and DynamoDB. They act as a target
#    in a route table, allowing traffic to be routed directly to the service.
# 2. **Interface Endpoints:** Used for KMS, Lambda, and CloudWatch Logs. They
#    are powered by AWS PrivateLink and appear as elastic network interfaces (ENIs)
#    in the subnets, with private DNS names resolving to private IPs.
#
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private_a.id, aws_route_table.private_b.id]
  tags              = merge(local.tags, { Name = "${local.name}-vpce-s3" })
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private_a.id, aws_route_table.private_b.id]
  tags              = merge(local.tags, { Name = "${local.name}-vpce-dynamodb" })
}

resource "aws_vpc_endpoint" "kms" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.kms"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  tags                = merge(local.tags, { Name = "${local.name}-vpce-kms" })
}

resource "aws_vpc_endpoint" "lambda" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.lambda"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  tags                = merge(local.tags, { Name = "${local.name}-vpce-lambda" })
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  tags                = merge(local.tags, { Name = "${local.name}-vpce-logs" })
}