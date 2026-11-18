# Inputs for the ALB module

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names (ALB and target group names max 32 chars)"
}

variable "vpc_id" {
  type        = string
  description = "VPC for the security group and target group"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR; the ALB may only send traffic inside the VPC"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnets for the ALB (at least 2 AZs)"
}

variable "app_port" {
  type        = number
  description = "Port the containers listen on"
}

variable "allowed_cidr" {
  type        = string
  description = "Who can reach the ALB on port 80"
}

variable "health_check_path" {
  type        = string
  description = "Path the ALB calls to check if a task is healthy"
  default     = "/health"
}