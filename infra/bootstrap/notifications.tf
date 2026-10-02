# Send state bucket events to EventBridge for monitoring.
resource "aws_s3_bucket_notification" "terraform_state" {
  bucket      = aws_s3_bucket.terraform_state.id
  eventbridge = true
}
