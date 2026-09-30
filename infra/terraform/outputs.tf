# Shows the key resource IDs and connection details after deployment.

output "vpc_id" {
  description = "ID of the VPC used by EKS"
  value       = module.vpc.vpc_id
}

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = module.eks.cluster_endpoint
}

output "node_group_name" {
  description = "Name of the managed worker node group"
  value       = module.eks.node_group_name
}

# Connection details for configuring BoundaryPass in Kubernetes.
output "database_endpoint" {
  description = "Private PostgreSQL endpoint and port"
  value       = module.rds.endpoint
}

output "database_master_secret_arn" {
  description = "Secrets Manager ARN for the RDS master credentials"
  value       = module.rds.master_user_secret_arn
}