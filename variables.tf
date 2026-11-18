
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

variable "enable_nat_instance" {
  description = "Create a low-cost EC2 NAT instance in the first public subnet"
  type        = bool
  default     = false
}

variable "nat_instance_type" {
  description = "EC2 instance type for the NAT instance"
  type        = string
  default     = "t3.micro"
}

variable "route_private_traffic_through_nat_instance" {
  description = "Switch private subnet default routes to the NAT instance after it has been deployed and verified"
  type        = bool
  default     = false

  validation {
    condition     = (!var.route_private_traffic_through_nat_instance || var.enable_nat_instance) && (var.route_private_traffic_through_nat_instance || !var.enable_nat_instance || var.enable_nat_gateway)
    error_message = "Enable the NAT instance before routing through it, and keep the NAT Gateway enabled until the route is switched to the NAT instance."
  }
}


variable "use_ecs_mysql" {
  description = "Switch the backend database connection to ECS-hosted MySQL only after data import and verification"
  type        = bool
  default     = false
}

variable "mysql_host_instance_type" {
  description = "Dedicated ECS EC2 instance type for the MySQL service"
  type        = string
  default     = "t3.small"
}

variable "mysql_data_volume_size" {
  description = "Size in GiB of the separately managed persistent MySQL EBS data volume"
  type        = number
  default     = 30

  validation {
    condition     = var.mysql_data_volume_size >= 20
    error_message = "The MySQL data volume must be at least 20 GiB."
  }
}

variable "mysql_database_name" {
  description = "Application database name created by the MySQL container"
  type        = string
  default     = "HospitalDBMS"
}
