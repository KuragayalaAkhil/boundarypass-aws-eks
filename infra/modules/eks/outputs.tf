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