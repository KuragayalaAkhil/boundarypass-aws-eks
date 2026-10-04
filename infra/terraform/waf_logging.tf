# Identify the account and region for the WAF logging encryption policy.
data "aws_caller_identity" "waf_logging" {}

data "aws_region" "waf_logging" {}

# Encrypt WAF request logs using a dedicated customer-managed KMS key.
resource "aws_kms_key" "waf_logs" {
  description             = "Encrypt BoundaryPass WAF logs"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableAccountKeyAdministration"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.waf_logging.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchLogsEncryption"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.waf_logging.region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
        Condition = {
          ArnEquals = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${data.aws_region.waf_logging.region}:${data.aws_caller_identity.waf_logging.account_id}:log-group:aws-waf-logs-boundarypass"
          }
        }
      }
    ]
  })

  tags = {
    Project = "boundarypass"
  }
}

# Store WAF logs in an encrypted CloudWatch log group.
resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-boundarypass"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.waf_logs.arn

  tags = {
    Project = "boundarypass"
  }
}

# Record blocked requests and redact query strings and sensitive headers.
resource "aws_wafv2_web_acl_logging_configuration" "boundarypass" {
  resource_arn            = aws_wafv2_web_acl.boundarypass.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  depends_on              = [aws_cloudwatch_log_resource_policy.waf]

  redacted_fields {
    query_string {}
  }

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    single_header {
      name = "cookie"
    }
  }

  logging_filter {
    default_behavior = "DROP"

    filter {
      behavior    = "KEEP"
      requirement = "MEETS_ANY"

      condition {
        action_condition {
          action = "BLOCK"
        }
      }
    }
  }
}

# Permit AWS log delivery to write only to the BoundaryPass WAF log group.
resource "aws_cloudwatch_log_resource_policy" "waf" {
  policy_name = "boundarypass-waf-log-delivery"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowWAFLogDelivery"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.waf.arn}:*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.waf_logging.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:logs:${data.aws_region.waf_logging.region}:${data.aws_caller_identity.waf_logging.account_id}:*"
          }
        }
      }
    ]
  })
}