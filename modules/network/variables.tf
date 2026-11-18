# Inputs for the network module

variable "name_prefix" {
  type        = string
  description = "Prefix for resource Name tags"
}

variable "vpc_cidr" {
  type        = string
  description = "IP range for the VPC"
}

variable "azs" {
  type        = list(string)
  description = "Availability zones to use (at least 2 for the ALB)"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "One public subnet CIDR per AZ (for ALB and NAT)"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "One private subnet CIDR per AZ (for ECS tasks and Lambda)"
}

#those above variables hasnt default values , cause those values assign through root main