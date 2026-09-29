# Inputs supplied by the root configuration when creating the EKS cluster.
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the EKS cluster and nodes"
  type        = list(string)
}

# Public IP range permitted to connect to the Kubernetes API.
variable "api_access_cidr" {
  description = "Allowed public IPv4 CIDR for the EKS API"
  type        = string
}
