terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.28.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 1.78.0"
    }
  }
  required_version = "~> 1.7"
}