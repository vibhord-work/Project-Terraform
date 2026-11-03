
variable "aws_region" {
  description = "AWS region for infrastructure deployment"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "project"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "poc"

  validation {
    condition     = contains(["poc", "dev", "stage", "prod"], var.environment)
    error_message = "Invalid environment."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)

  default = [
    "10.20.1.0/24",
    "10.20.2.0/24"
  ]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)

  default = [
    "10.20.11.0/24",
    "10.20.12.0/24"
  ]
}

variable "availability_zones" {
  description = "Availability Zones for subnet deployment"
  type        = list(string)

  default = [
    "us-east-1a",
    "us-east-1b"
  ]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnet outbound internet"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway to reduce POC costs"
  type        = bool
  default     = true
}