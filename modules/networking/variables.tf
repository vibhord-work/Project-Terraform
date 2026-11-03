
variable "project_name" {
  description = "Project name used for networking resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "availability_zones" {
  description = "Availability Zones for subnet deployment"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Whether to create NAT Gateways"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use one NAT Gateway instead of one per Availability Zone"
  type        = bool
  default     = true
}