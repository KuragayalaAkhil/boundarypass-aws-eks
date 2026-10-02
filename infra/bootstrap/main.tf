# Creates the S3 bucket that will store the EKS Terraform state.
# This bootstrap configuration keeps its own state locally.

terraform {
  required_version = ">= 1.15.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

resource "aws_s3_bucket" "terraform_state" {
  #checkov:skip=CKV_AWS_18:Separate access-log bucket is outside this short-lived lab
  #checkov:skip=CKV_AWS_144:Single-region lab retains state object versions instead of cross-region replication
  bucket = "boundarypass-terraform-state-697858907754"

  tags = {
    Name    = "boundarypass-terraform-state"
    Project = "boundarypass"
  }

  # Prevent an accidental Terraform destroy from deleting the state bucket.
  lifecycle {
    prevent_destroy = true
  }
}

# Keeps previous state versions so an earlier version can be recovered.
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypts state objects stored in the bucket.
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.terraform_state.arn
      sse_algorithm     = "aws:kms"
    }

    bucket_key_enabled = true
  }
}

# Blocks public access to the bucket and its objects.
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Keep the current Terraform state and retain older versions for 90 days.
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }

  depends_on = [aws_s3_bucket_versioning.terraform_state]
}