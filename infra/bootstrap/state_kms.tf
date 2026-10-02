# Keep the state encryption key for as long as any state version needs recovery.
resource "aws_kms_key" "terraform_state" {
  description             = "Encrypt BoundaryPass Terraform state objects"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "EnableAccountKeyAdministration"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      }
      Action   = "kms:*"
      Resource = "*"
    }]
  })

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Project = "boundarypass"
  }
}
