# Pin Terraform and AWS provider versions to keep deployments predictable.
terraform {
  required_version = ">= 1.15.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Configure AWS API calls for the deployment region.
provider "aws" {
  region = "ap-south-1"
}
