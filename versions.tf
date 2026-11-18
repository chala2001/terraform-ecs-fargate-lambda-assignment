# Settings for Terraform itself
terraform {
  required_version = ">= 1.17"

  # ONE required_providers block that lists ALL providers
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    # Creates the Lambda zip file from our Python code
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}