variable "project" {
  type    = string
  default = "claims"
}

variable "env" {
  type    = string
  default = "dev"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "cidr_vpc" {
  type    = string
  default = "10.42.0.0/16"
}

variable "cidr_private_a" {
  type    = string
  default = "10.42.1.0/24"
}

variable "cidr_private_b" {
  type    = string
  default = "10.42.2.0/24"
}

variable "cognito_callback_urls" {
  type    = list(string)
  default = ["http://localhost:5173/callback"]
}

variable "cognito_logout_urls" {
  type    = list(string)
  default = ["http://localhost:5173"]
}

variable "frontend_origin" {
  type    = string
  default = "http://localhost:5173"
}


variable "image_tag_api_presign" {
  type    = string
  default = "dev"
}

variable "image_tag_api_list" {
  type    = string
  default = "dev"
}

variable "image_tag_indexer" {
  type    = string
  default = "dev"
}

variable "enable_xray" {
  type    = bool
  default = true
}

variable "presign_image_digest" {
  type    = string
  default = ""
}

variable "list_image_digest" {
  type    = string
  default = ""
}

variable "indexer_image_digest" {
  type    = string
  default = ""
}

variable "allow_localhost_in_cors" {
  type    = bool
  default = false # prod-safe default
}

variable "amplify_branch_name" {
  type    = string
  default = "prod"
}
