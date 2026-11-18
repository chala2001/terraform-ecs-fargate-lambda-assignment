# Inputs for the Lambda module

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names"
}

variable "vpc_id" {
  type        = string
  description = "VPC for the Lambda security group"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnets the Lambda runs in"
}

variable "source_file" {
  type        = string
  description = "Path to the Lambda Python file"
}

variable "target_url" {
  type        = string
  description = "URL the health checker calls"
}

variable "schedule_expression" {
  type        = string
  description = "How often to run, e.g. rate(5 minutes)"
  default     = "rate(5 minutes)"
}

variable "log_retention_days" {
  type        = number
  description = "How long to keep Lambda logs"
  default     = 3
}