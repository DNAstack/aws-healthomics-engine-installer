variable "output_bucket_name" {
  description = "The name of the output bucket"
  type        = string
  nullable    = false
}

variable "workbench_service_account_name" {
  description = "The name of the workbench service account"
  type        = string
  default     = "workbench-health-omics"
  nullable    = false
}

variable "force_destroy" {
  description = "Applying the module with this value true allows you to run terraform destroy"
  type        = bool
  default     = false
}

variable "health_omics_role_name" {
  description = "The name of the health omics role"
  type        = string
  default     = "HealthOmicsRole"
  nullable    = false
}

variable "region" {
  description = "The region in which the resources will be created"
  type        = string
  default     = "us-east-1"
  nullable    = false
  validation {
    condition = contains([
      "us-east-1", "us-west-2", "ap-southeast-1", "eu-central-1", "eu-west-1", "eu-west-2", "il-central-1"
    ], var.region)
    error_message = "Invalid region"
  }
}

variable "additional_buckets" {
  description = "Additional buckets to add to the policy"
  type = list(string)
  default = []
  nullable    = true
}

variable "genome_references_bucket" {
  description = "The name of the genome references bucket"
  type        = string
  default     = null
  nullable    = true
}

variable "health_omics_service_policy_name" {
  description = "The name of the health omics service policy"
  type        = string
  default     = "HealthOmicsServicePolicy"
  nullable    = false
}

variable "health_omics_user_policy_name" {
  description = "The name of the health omics user policy"
  type        = string
  default     = "HealthOmicsUserPolicy"
  nullable    = false
}


variable "ecr_repositories" {
  description = "The ecr of docker images to create"
  type = set(string)
  default = []
  nullable    = true
}

variable "external_ecr_accounts" {
  description = "The list of external ECR accounts to allow access to the repositories"
  type = list(string)
  default = []
  nullable    = true
}

variable "genome_references_bucket_region_map" {
  description = "The name of the genomics references bucket"
  type = map(string)
  default = {
    "us-east-1" = "aws-us-east-1-genome-references/dataset"
    "us-west-2" = "aws-us-west-2-genome-references/dataset"
    "ap-southeast-1" = "aws-ap-southeast-1-genome-references/dataset"
    "eu-central-1" = "aws-eu-central-1-genome-references/dataset"
    "eu-west-1" = "aws-eu-west-1-genome-references/dataset"
    "eu-west-2" = "aws-eu-west-2-genome-references/dataset"
    "il-central-1" = "aws-il-central-1-genome-references/dataset"
  }
  nullable = true
}

variable "managed_ecr_resources_region_map" {
  description = "The ARN of the managed ECR resource"
  type = map(string)
  default = {
    "us-east-1" = "arn:aws:ecr:us-east-1:937525261261:*"
    "us-west-2" = "arn:aws:ecr:us-west-2:937525261261:*"
    "ap-southeast-1" = "arn:aws:ecr:ap-southeast-1:937525261261:*"
    "eu-central-1" = "arn:aws:ecr:eu-central-1:937525261261:*"
    "eu-west-1" = "arn:aws:ecr:eu-west-1:937525261261:*"
    "eu-west-2" = "arn:aws:ecr:eu-west-2:937525261261:*"
    "il-central-1" = "arn:aws:ecr:il-central-1:937525261261:*"
  }
  nullable = true
}

variable "external_raw_data_bucket_name" {
    description = "The name of the external raw data bucket"
    type        = string
    default     = null
    nullable    = true
}