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

resource "aws_ecr_repository" "docker_repositories" {
  for_each = var.docker_repositories
  name     = each.value
}

resource "aws_ecr_repository_policy" "docker_repository_policy" {
  for_each = var.docker_repositories
  repository = aws_ecr_repository.docker_repositories[each.key].name
  policy = data.aws_iam_policy_document.health_omics_ecr_policy.json
}