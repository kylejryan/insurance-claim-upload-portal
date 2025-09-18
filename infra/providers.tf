################################################################################
# Terraform Configuration
#
# This file defines the core settings for the Terraform project, including
# the required versions, providers, and data sources. It is the entry point
# for the entire configuration.
################################################################################

#
# Terraform Engine and Provider Requirements.
#
# This block specifies the minimum required version for Terraform itself and
# declares the external providers needed to manage resources. Pinning versions
# with a tilde (`~>`) ensures compatible updates while preventing breaking changes.
#
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

#
# AWS Provider Configuration.
#
# Configures the AWS provider with the specific region where resources will
# be deployed. This centralizes the region setting, ensuring all resources
# are created in the correct location.
#
provider "aws" {
  region = var.region
}

#
# AWS Data Sources.
#
# These data sources retrieve information from the AWS account and partition,
# which is useful for constructing ARNs and other resource identifiers without
# hardcoding account-specific details.
#
data "aws_caller_identity" "me" {}

data "aws_partition" "current" {}