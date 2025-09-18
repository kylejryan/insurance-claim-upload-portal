################################################################################
# Terraform Variables
#
# This file centralizes all input variables for the Terraform configuration.
# Variables make the code reusable and adaptable for different environments
# (e.g., dev, staging, prod) without requiring changes to the core code.
################################################################################

#
# Project and Environment Configuration.
#
# These variables define the foundational naming and deployment settings.
# `project` and `env` are used to create unique resource names and tags.
#
variable "project" {
  description = "The name of the project. Used for resource naming and tagging."
  type        = string
  default     = "claims"
}

variable "env" {
  description = "The deployment environment (e.g., dev, prod)."
  type        = string
  default     = "dev"
}

variable "region" {
  description = "The AWS region where resources will be deployed."
  type        = string
  default     = "us-east-1"
}

#
# Network Configuration (VPC).
#
# These variables define the CIDR blocks for the VPC and its subnets.
# They are essential for a secure and well-structured network.
#
variable "cidr_vpc" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.42.0.0/16"
}

variable "cidr_private_a" {
  description = "The CIDR block for the first private subnet."
  type        = string
  default     = "10.42.1.0/24"
}

variable "cidr_private_b" {
  description = "The CIDR block for the second private subnet."
  type        = string
  default     = "10.42.2.0/24"
}

#
# Frontend and CORS Variables.
#
# These variables control frontend-related settings, such as the origin URL
# and allowed CORS domains. They provide flexibility for different deployment
# scenarios.
#
variable "frontend_origin" {
  description = "Optional override for the frontend origin URL. Leave empty to auto-compute from Amplify."
  type        = string
  default     = ""
}

variable "allow_localhost_in_cors" {
  description = "Set to true to include localhost in allowed CORS origins for development. Defaults to false for production safety."
  type        = bool
  default     = false
}

variable "amplify_branch_name" {
  description = "The name of the Amplify branch that hosts the frontend."
  type        = string
  default     = "prod"
}

#
# Docker Image Configuration.
#
# These variables define the container images used for the Lambda functions.
# They support both image tags and immutable digests for reliable deployments.
#
variable "image_tag_api_presign" {
  description = "The ECR image tag for the API presign Lambda."
  type        = string
  default     = "dev"
}

variable "image_tag_api_list" {
  description = "The ECR image tag for the API list Lambda."
  type        = string
  default     = "dev"
}

variable "image_tag_indexer" {
  description = "The ECR image tag for the indexer Lambda."
  type        = string
  default     = "dev"
}

variable "presign_image_digest" {
  description = "Optional immutable digest for the API presign Lambda image. Overrides image_tag if provided."
  type        = string
  default     = ""
}

variable "list_image_digest" {
  description = "Optional immutable digest for the API list Lambda image. Overrides image_tag if provided."
  type        = string
  default     = ""
}

variable "indexer_image_digest" {
  description = "Optional immutable digest for the indexer Lambda image. Overrides image_tag if provided."
  type        = string
  default     = ""
}

#
# Feature Flags.
#
# These variables act as feature flags to enable or disable specific
# functionalities, such as X-Ray tracing.
#
variable "enable_xray" {
  description = "Set to true to enable X-Ray tracing for supported resources."
  type        = bool
  default     = true
}