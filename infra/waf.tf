################################################################################
# AWS WAFv2 Web ACL
#
# This section defines a regional Web Application Firewall (WAF) to protect
# the API Gateway. The WAF includes managed rules for common threats and
# a rate-limiting rule to protect against high-volume attacks.
################################################################################

#
# Creates the WAFv2 Web ACL.
#
# This is the primary WAF resource. It is scoped to "REGIONAL" to be
# associated with a regional API Gateway endpoint. The default action is
# `allow`, which means traffic is permitted unless it matches a specific rule.
#
resource "aws_wafv2_web_acl" "this" {
  name  = "${local.name}-waf"
  scope = "REGIONAL"
  tags  = local.tags

  default_action {
    allow {}
  }

  #
  # Rule: AWS Managed Common Rule Set.
  #
  # This rule leverages a pre-configured set of rules provided by AWS to
  # protect against common web exploits like SQL injection and cross-site
  # scripting (XSS).
  #
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1 # Lower number means higher priority.

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    # `override_action { none {} }` is used to specify that this rule should
    # not block traffic on its own. The behavior is determined by the
    # managed rule group's default action.
    override_action {
      none {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name}-common"
      sampled_requests_enabled   = true
    }
  }

  #
  # Rule: IP-based Rate Limiting.
  #
  # This rule blocks requests from an IP address if the request rate exceeds
  # the defined limit. It's an effective way to mitigate DDoS attacks or
  # brute-force login attempts.
  #
  rule {
    name     = "RateLimit"
    priority = 10

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP" # Aggregates requests based on the client IP address.
      }
    }

    action {
      block {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name}-rate"
      sampled_requests_enabled   = true
    }
  }

  #
  # Global Visibility Configuration.
  #
  # This configuration applies to the entire Web ACL, providing aggregated
  # metrics for all rules and requests.
  #
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name}-waf"
    sampled_requests_enabled   = true
  }
}

#
# Associates the WAF with the API Gateway Stage.
#
# This resource links the WAF to the API Gateway's production stage,
# ensuring all incoming traffic is inspected by the firewall before being
# forwarded to the API.
#
resource "aws_wafv2_web_acl_association" "api" {
  resource_arn = aws_api_gateway_stage.prod.arn
  web_acl_arn  = aws_wafv2_web_acl.this.arn

  # Explicit dependency to ensure the API Gateway stage is fully created
  # before the WAF association is attempted.
  depends_on = [
    aws_api_gateway_stage.prod
  ]
}