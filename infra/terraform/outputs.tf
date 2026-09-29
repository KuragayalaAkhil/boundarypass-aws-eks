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