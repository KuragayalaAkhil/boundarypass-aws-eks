# Inputs needed to place PostgreSQL in private subnets and limit database access.
variable "vpc_id" {
  description = "VPC containing EKS and the database"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs in at least two Availability Zones"
  type        = list(string)
}

variable "eks_cluster_security_group_id" {
  description = "Security group attached to EKS managed worker nodes"
  type        = string
}