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

## Output bucket retention

The output bucket expires its contents through three lifecycle rules:

| Rule | Scope | Default |
|---|---|---|
| `expire-transient-outputs` | objects tagged `retention=transient` | 14 days |
| `expire-all` | every object | 90 days |
| `abort-incomplete-multipart` | incomplete multipart uploads | 7 days |

Tune with `output_bucket_expiration_days`, `output_bucket_max_retention_days` and
`output_bucket_abort_multipart_days`. There is no switch to disable expiration; an
environment with a retention obligation raises `output_bucket_max_retention_days`.

### Why objects are tagged

S3 lifecycle filters accept only prefix, tag and object-size conditions — no suffix
matching and no negation — and HealthOmics keys are `<run-id>/logs/…` and
`<run-id>/out/…`, so no literal prefix can reach the segment that distinguishes
them. "Everything except run logs and manifests" is therefore expressed by tagging:
the `<bucket>-tagger` Lambda runs on `s3:ObjectCreated:*` and applies
`retention=transient` to every object whose key does not end in `.log` or `.json`
(case-insensitive). New output types are covered automatically — there is no
extension list to maintain.

Objects the tagger misses carry no tag and are governed by `expire-all`, so a
tagging outage costs a bounded window rather than unbounded growth.

The `retention` key is reserved for this function; anything else that writes
it on this bucket will have its value overwritten. The tag key and value are
passed to the Lambda by Terraform (`RETENTION_TAG_KEY` / `RETENTION_TAG_VALUE`,
sourced from the same locals as the lifecycle rule's filter), so they cannot
drift from the lifecycle rule that depends on them.

Two constraints on changes here:

- The notification must stay `s3:ObjectCreated:*`. Outputs are large enough to be
  multipart uploads, which emit `CompleteMultipartUpload` rather than `Put`.
- S3 allows one notification configuration per bucket, so this module owns it.

Handler source is `function_source/tagger.py`; run its tests with
`pytest tests/` after `pip install pytest boto3`.
