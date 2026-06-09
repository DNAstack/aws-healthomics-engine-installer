variable "aws_region" {
  description = "AWS region in which the resources will be created"
  type        = string
  nullable    = false
  validation {
    condition = contains([
      "us-east-1", "us-west-2", "ap-southeast-1", "ap-northeast-2", "eu-central-1", "eu-west-1", "eu-west-2", "il-central-1"
    ], var.aws_region)
    error_message = "Region is not supported by AWS HealthOmics"
  }
}

variable "aws_profile" {
  description = "AWS CLI profile name"
  type        = string
}

variable "project_name" {
  description = "Name of project used to prefix deployed assets"
  type        = string
}

variable "output_bucket_name" {
  description = "Name of the S3 bucket to store HealthOmics output data in. Defaults to <project_name>-raw-output."
  type        = string
  default     = null
  nullable    = true
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

variable "additional_buckets" {
  description = "Additional buckets to add to the policy"
  type        = list(string)
  default     = []
  nullable    = true
}

variable "genome_references_bucket" {
  description = "The name of the genome references bucket. Overrides the per-region default from genome_references_bucket_region_map when set."
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
  description = "The set of ECR repository names to create"
  type        = set(string)
  default     = []
  nullable    = true
}

variable "external_ecr_accounts" {
  description = "The list of external ECR accounts to allow access to the repositories"
  type        = list(string)
  default     = []
  nullable    = true
}

variable "genome_references_bucket_region_map" {
  description = "Per-region map of managed genome references buckets"
  type        = map(string)
  default = {
    "us-east-1"      = "aws-us-east-1-genome-references/dataset"
    "us-west-2"      = "aws-us-west-2-genome-references/dataset"
    "ap-southeast-1" = "aws-ap-southeast-1-genome-references/dataset"
    "ap-northeast-2" = "aws-ap-northeast-2-genome-references/dataset"
    "eu-central-1"   = "aws-eu-central-1-genome-references/dataset"
    "eu-west-1"      = "aws-eu-west-1-genome-references/dataset"
    "eu-west-2"      = "aws-eu-west-2-genome-references/dataset"
    "il-central-1"   = "aws-il-central-1-genome-references/dataset"
  }
  nullable = true
}

variable "external_raw_data_bucket_name" {
  description = "Name of an external raw-data bucket to grant the service-policy read access to"
  type        = string
  default     = null
  nullable    = true
}

variable "max_runs_with_static_storage_quota" {
  description = "Service quota for maximum concurrent runs with static storage"
  type        = number
  default     = 50
  nullable    = false
}

variable "max_runs_with_dynamic_storage_quota" {
  description = "Service quota for maximum concurrent runs with dynamic storage"
  type        = number
  default     = 200
  nullable    = false
}

variable "maximum_concurrent_tasks" {
  description = "Service quota for maximum concurrent tasks"
  type        = number
  default     = 100
  nullable    = false
}

variable "submit_run_quota" {
  description = "Service quota for submit-run TPS"
  type        = number
  default     = 5
}

variable "outbound_identity_token_audiences" {
  description = "List of allowed audiences for outbound identity federation tokens (e.g., Client IDs)"
  type        = list(string)
  default     = ["explorer.gcp-managed-deployments.dnastack.com-public"]
}

variable "enable_vpc_networking" {
  description = "Enable VPC-connected HealthOmics (GA): VPC endpoints, the omics egress SG, and the awscc_omics_configuration resource."
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "VPC ID hosting the HealthOmics run ENIs. Required when enable_vpc_networking is true."
  type        = string
  default     = null
  nullable    = true
}

variable "private_subnet_ids" {
  description = "Private subnet IDs (HealthOmics-supported AZs) for the run ENIs and interface endpoints."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "private_route_table_ids" {
  description = "Private route table IDs for the S3 gateway endpoint."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "omics_egress_cidrs" {
  description = "CIDRs the workflow ENIs may reach on 443 via NAT (e.g. Passport)."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "additional_interface_endpoints" {
  description = "Extra interface VPC endpoint short service names to create (e.g. \"dynamodb\", \"secretsmanager\")."
  type        = set(string)
  default     = []
  nullable    = false
}

variable "configuration_name" {
  description = "Name of the HealthOmics Configuration resource. Defaults to <project_name>-vpc."
  type        = string
  default     = null
  nullable    = true
}
