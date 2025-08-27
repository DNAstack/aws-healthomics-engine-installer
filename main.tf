provider "aws" {
  region = var.region
}

resource "aws_s3_bucket" "output_bucket" {
  bucket = var.output_bucket_name
  tags = {
    created_by = "terraform"
  }
}

resource "aws_iam_user" "workbench_service_account" {
  name = var.workbench_service_account_name
  tags = {
    created_by = "terraform"
  }
}

resource "aws_iam_user_policy_attachment" "workbench_service_account_policy" {
  user       = aws_iam_user.workbench_service_account.name
  policy_arn = aws_iam_policy.health_omics_user_policy.arn
}

resource "aws_iam_access_key" "workbench_service_account_secret_key" {
  user = aws_iam_user.workbench_service_account.name
}

resource "aws_iam_policy" "health_omics_user_policy" {
  name        = var.health_omics_user_policy_name
  description = "Policy for health omics service"
  policy      = data.aws_iam_policy_document.health_omics_user_policy.json
  tags = {
    created_by = "terraform"
  }
}

resource "aws_iam_policy" "health_omics_service_policy" {
  name        = var.health_omics_service_policy_name
  description = "Policy for health omics service"
  policy      = data.aws_iam_policy_document.health_omics_service_policy.json
  tags = {
    created_by = "terraform"
  }
}

resource "aws_iam_role" "health_omics_role" {
  name               = var.health_omics_role_name
  assume_role_policy = data.aws_iam_policy_document.health_omics_trust_policy.json
  managed_policy_arns = [
    aws_iam_policy.health_omics_service_policy.arn
  ]
  tags = {
    created_by = "terraform"
  }
}

resource "aws_ecr_repository" "ecr_repositories" {
  for_each = var.ecr_repositories
  name     = each.value
}

resource "aws_ecr_repository_policy" "docker_repository_policy" {
  for_each = var.ecr_repositories
  repository = aws_ecr_repository.ecr_repositories[each.key].name
  policy = data.aws_iam_policy_document.health_omics_ecr_policy.json
}


resource "aws_servicequotas_service_quota" "submit_run_quota" {
  quota_code   = "L-24A3B174"
  service_code = "omics"
  value        = var.submit_run_quota
}

resource "aws_servicequotas_service_quota" "maximum_concurrent_tasks" {
  quota_code = "L-25504C8C"
  service_code = "omics"
  value      = var.maximum_concurrent_tasks
}

resource "aws_servicequotas_service_quota" "maximum_concurrent_active_runs_with_dynamic_storage" {
  quota_code = "L-BE38079A"
  service_code = "omics"
  value      = var.max_runs_with_dynamic_storage_quota
}

resource "aws_servicequotas_service_quota" "maximum_concurrent_active_runs_with_static_storage" {
  quota_code = "L-A30FD31B"
  service_code = "omics"
  value      = var.max_runs_with_static_storage_quota
}