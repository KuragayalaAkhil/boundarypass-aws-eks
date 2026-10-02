# Public IP range allowed to reach the EKS Kubernetes API.
variable "eks_api_access_cidr" {
  description = "Your current public IPv4 address with a /32 suffix"
  type        = string
}

variable "rds_snapshot_identifier" {
  description = "Manual RDS snapshot to restore for this session"
  type        = string
  nullable    = false
}
