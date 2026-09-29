# Public IP range allowed to reach the EKS Kubernetes API.
variable "eks_api_access_cidr" {
  description = "Your current public IPv4 address with a /32 suffix"
  type        = string
}