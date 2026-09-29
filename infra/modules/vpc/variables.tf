# Network settings passed from the root Terraform configuration.
variable "project_name" {
  description = "Name used to tag the network resources"
  type        = string
}

variable "vpc_cidr" {
  description = "IP address range for the VPC"
  type        = string
}

variable "public_subnets" {
  description = "Public subnet CIDR and availability zone for each subnet"
  type = map(object({
    cidr = string
    az   = string
  }))
}

variable "private_subnets" {
  description = "Private subnet CIDR and availability zone for each subnet"
  type = map(object({
    cidr = string
    az   = string
  }))
}
