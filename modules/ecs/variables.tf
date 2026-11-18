# Inputs for the ECS module

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names"
}

variable "aws_region" {
  type        = string
  description = "Region, used by the container log driver"
}

variable "vpc_id" {
  type        = string
  description = "VPC for the task security group"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnets where tasks run (no public IP)"
}

variable "alb_security_group_id" {
  type        = string
  description = "Only this SG (the ALB) may reach the tasks"
}

variable "target_group_arn" {
  type        = string
  description = "ALB target group where the service registers tasks"
}

variable "app_port" {
  type        = number
  description = "Port the container listens on"
}

variable "container_image" {
  type        = string
  description = "Container image to run"
}

variable "app_code" {
  type        = string
  description = "Python app source code (V1: injected into the public image)"
}

variable "cpu" {
  type        = number
  description = "Task CPU units (256 = 0.25 vCPU, the smallest)"
  default     = 256
}

variable "memory" {
  type        = number
  description = "Task memory in MiB (512 is the smallest for 256 CPU)"
  default     = 512
}

variable "desired_count" {
  type        = number
  description = "How many tasks to keep running"
  default     = 1
}

variable "log_retention_days" {
  type        = number
  description = "How long to keep container logs"
  default     = 3
}