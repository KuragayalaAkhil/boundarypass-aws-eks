# Create a regional Web ACL attached to the public ALB through the Ingress.
resource "aws_wafv2_web_acl" "boundarypass" {
  name        = "boundarypass-waf"
  description = "BoundaryPass application traffic inspection"
  scope       = "REGIONAL"

  # Allow requests that do not match a blocking rule.
  default_action {
    allow {}
  }

  # Enforce the AWS managed common rules using their default actions.
  rule {
    name     = "AWSCommonRules"
    priority = 10

    override_action {
      none {}
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

  # Enforce the AWS managed SQL injection rules using their default actions.
  rule {
    name     = "AWSSQLInjectionRules"
    priority = 20

    override_action {
      none {}
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

  # Block known malicious inputs, including Log4j exploit patterns.
  rule {
    name     = "AWSKnownBadInputsRules"
    priority = 25

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "boundarypass-known-bad-inputs"
      sampled_requests_enabled   = false
    }
  }

  # Block IPs exceeding approximately 2,000 requests in five minutes.
  rule {
    name     = "PerIPRateLimit"
    priority = 30

    action {
      block {}
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

# Expose the Web ACL ARN used by the ALB Ingress annotation.
output "waf_web_acl_arn" {
  description = "Regional WAF Web ACL ARN for the BoundaryPass ALB"
  value       = aws_wafv2_web_acl.boundarypass.arn
}