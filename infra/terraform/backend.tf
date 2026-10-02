# Stores the EKS infrastructure state in the separate S3 bucket.
# The lock file prevents two Terraform runs from changing it at once.
terraform {
  backend "s3" {
    bucket       = "boundarypass-terraform-state-697858907754"
    key          = "boundarypass/eks/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    kms_key_id   = "arn:aws:kms:ap-south-1:697858907754:key/6b008eca-9b96-47cf-8762-96994231eb39"
    use_lockfile = true
  }
}