# Create a regional Web ACL that we will attach to the public ALB.
resource "aws_wafv2_web_acl" "boundarypass" {
  name        = "boundarypass-waf"
  description = "BoundaryPass application traffic inspection"
  scope       = "REGIONAL"

  # Allow traffic while rules are tested in Count mode.
  default_action {
    allow {}
  }

  # Detect common web attack patterns without blocking yet.
  rule {
    name     = "AWSCommonRules"
    priority = 10

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "boundarypass-common-rules"
      sampled_requests_enabled   = false
    }
  }

  # Detect SQL injection patterns without blocking yet.
  rule {
    name     = "AWSSQLInjectionRules"
    priority = 20

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "boundarypass-sqli-rules"
      sampled_requests_enabled   = false
    }
  }

  # Count requests from IPs exceeding approximately 2,000 requests
  # in five minutes. Blocking will be enabled after testing.
  rule {
    name     = "PerIPRateLimit"
    priority = 30

    action {
      count {}
    }

    statement {
      rate_based_statement {
        limit                 = 2000
        aggregate_key_type    = "IP"
        evaluation_window_sec = 300
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "boundarypass-rate-limit"
      sampled_requests_enabled   = false
    }
  }

  # Enable CloudWatch metrics without storing sampled request contents.
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "boundarypass-waf"
    sampled_requests_enabled   = false
  }

  tags = {
    Project = "boundarypass"
  }
}

# Show the Web ACL ARN so we can connect it to the ALB Ingress later.
output "waf_web_acl_arn" {
  description = "Regional WAF Web ACL ARN for the BoundaryPass ALB"
  value       = aws_wafv2_web_acl.boundarypass.arn
}