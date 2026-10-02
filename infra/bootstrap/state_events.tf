data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  state_events_log_group = "/aws/events/boundarypass-terraform-state"
}

resource "aws_kms_key" "state_events" {
  description             = "Encrypt BoundaryPass Terraform state event logs"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableAccountKeyAdministration"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchLogsForStateEvents"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.region}.amazonaws.com"
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
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:${local.state_events_log_group}"
          }
        }
      }
    ]
  })

  tags = {
    Project = "boundarypass"
  }
}

resource "aws_cloudwatch_log_group" "state_events" {
  name              = local.state_events_log_group
  retention_in_days = 365
  kms_key_id        = aws_kms_key.state_events.arn

  tags = {
    Project = "boundarypass"
  }
}

resource "aws_cloudwatch_event_rule" "state_objects" {
  name        = "boundarypass-terraform-state-objects"
  description = "Record creation and deletion of Terraform state objects"

  event_pattern = jsonencode({
    source        = ["aws.s3"]
    "detail-type" = ["Object Created", "Object Deleted"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.terraform_state.id]
      }
    }
  })

  tags = {
    Project = "boundarypass"
  }
}

resource "aws_cloudwatch_log_resource_policy" "state_events" {
  policy_name = "boundarypass-terraform-state-events"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgeDelivery"
        Effect = "Allow"
        Principal = {
          Service = ["events.amazonaws.com", "delivery.logs.amazonaws.com"]
        }
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.state_events.arn}:*"
      }
    ]
  })
}

resource "aws_cloudwatch_event_target" "state_events" {
  rule      = aws_cloudwatch_event_rule.state_objects.name
  target_id = "StateObjectEvents"
  arn       = aws_cloudwatch_log_group.state_events.arn

  depends_on = [aws_cloudwatch_log_resource_policy.state_events]
}
