output "access_key_id" {
  description = "Access key ID for Workbench to use"
  value       = aws_iam_access_key.workbench_service_account_secret_key.id
}

output "secret_access_key" {
  description = "Secret access key for Workbench to use"
  sensitive   = true
  value       = aws_iam_access_key.workbench_service_account_secret_key.secret
}

output "role_arn" {
    description = "ARN of the role used by HealthOmics"
    value       = aws_iam_role.health_omics_role.arn
  
}

output "output_bucket" {
    description = "The name of the output bucket"
    value       = aws_s3_bucket.output_bucket.bucket
}

output "docker_repositories" {
    description = "The name of the docker repositories"
    value       = [for repo in aws_ecr_repository.ecr_repositories: repo.repository_url]

}