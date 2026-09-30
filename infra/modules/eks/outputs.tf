# Exposes cluster details to the root configuration after creation.

output "cluster_name" {
  description = "Name used to connect kubectl to the EKS cluster"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint for the EKS cluster"
  value       = aws_eks_cluster.this.endpoint
}

output "node_group_name" {
  description = "Name of the managed EC2 worker node group"
  value       = aws_eks_node_group.this.node_group_name
}

# Managed worker nodes use this EKS cluster security group.
output "cluster_security_group_id" {
  description = "Security group used by the EKS managed nodes"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}