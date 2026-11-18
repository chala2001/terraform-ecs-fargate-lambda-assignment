variable "aws_profile" {
  type        = string
  description = "AWS CLI profile name used for authentication"
  default     = "tf-assignment"
}

variable "aws_region" {
  type        = string
  description = "Where the resources need to be deployed"
  default     = "ap-south-1"
}


variable "project_name" {
  type        = string
  description = "Just project name "
  default     = "ecs-fargate-lambda"

}

variable "environment" {
  type        = string
  description = "Deployment environment"
  default     = "dev"

}


variable "owner" {
  type        = string
  description = "Owner of the resources ,used for tagging "
  default     = "Chalaka"
}


variable "app_port" {
  type        = number
  description = "Port the API listens on"
  default     = 8080
}


variable "allowed_cidr" {
  type        = string
  description = "CIDR allowed to reach the API port"
  default     = "0.0.0.0/0"
}



