# Terraform AWS HealthOmics Engine Installer

Terraform module that provisions the AWS HealthOmics engine for a deployment:
the output S3 bucket, the Workbench service-account IAM user + access key, the
HealthOmics service/user IAM policies and role, ECR repositories, service quotas,
and (optionally) VPC-connected networking for GA workflow runs.

Consumed by `dnastack-deployment-templates/terraform/aws/healthomics-engine` (the
pipeline root module) via git source:

```hcl
module "healthomics_engine" {
  source       = "git@github.com:DNAstack/aws-healthomics-engine-installer.git//?ref=<commit-sha>"
  aws_region   = "us-east-1"
  aws_profile  = "default"
  project_name = "hfs-example"
  # ... see variables.tf
}
```

## VPC-connected (GA) networking

Set `enable_vpc_networking = true` and pass `vpc_id`, `private_subnet_ids`, and
`private_route_table_ids` to create the VPC endpoints, the omics-ENI egress
security group, and the `awscc_omics_configuration` resource. Workflow runs opt in
per-run via `StartRun --networking-mode VPC --configuration-name <name>`.
