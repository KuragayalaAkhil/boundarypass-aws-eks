# Create the VPC and subnet layout used by the application infrastructure.
module "vpc" {
  source = "../modules/vpc"

  project_name = "boundarypass"
  vpc_cidr     = "10.20.0.0/16"

  public_subnets = {
    a = { cidr = "10.20.1.0/24", az = "ap-south-1a" }
    b = { cidr = "10.20.2.0/24", az = "ap-south-1b" }
  }

  private_subnets = {
    a = { cidr = "10.20.11.0/24", az = "ap-south-1a" }
    b = { cidr = "10.20.12.0/24", az = "ap-south-1b" }
  }
}

# Creates the EKS cluster and worker nodes in the VPC's private subnets.
# Referencing the VPC output makes Terraform create the network first.
module "eks" {
  source = "../modules/eks"

  cluster_name       = "boundarypass-eks"
  private_subnet_ids = module.vpc.private_subnet_ids
  api_access_cidr    = var.eks_api_access_cidr
}

# Place the Multi-AZ PostgreSQL database in the VPC's private subnets.
# Allow connections from the EKS managed nodes.
module "rds" {
  source = "../modules/rds"

  vpc_id                        = module.vpc.vpc_id
  private_subnet_ids            = module.vpc.private_subnet_ids
  eks_cluster_security_group_id = module.eks.cluster_security_group_id
}