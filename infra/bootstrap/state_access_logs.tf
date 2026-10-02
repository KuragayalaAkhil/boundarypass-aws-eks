# Deliver state bucket access records to the existing encrypted log group.
resource "aws_cloudwatch_log_delivery_source" "state_access" {
  name         = "boundarypass-state-access"
  log_type     = "S3_SERVER_ACCESS_LOGS"
  resource_arn = aws_s3_bucket.terraform_state.arn
}

resource "aws_cloudwatch_log_delivery_destination" "state_access" {
  name = "boundarypass-state-access"

  delivery_destination_configuration {
    destination_resource_arn = aws_cloudwatch_log_group.state_events.arn
  }
}

resource "aws_cloudwatch_log_delivery" "state_access" {
  delivery_source_name     = aws_cloudwatch_log_delivery_source.state_access.name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.state_access.arn
}
