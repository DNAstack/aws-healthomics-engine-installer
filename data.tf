data "aws_caller_identity" "current" {}

data "aws_region" "current" {
  
}

locals {
  genome_references_bucket_default = lookup({
    "us-east-1"      = "aws-us-east-1-genome-references/dataset"
    "us-west-2"      = "aws-us-west-2-genome-references/dataset"
    "ap-southeast-1" = "aws-ap-southeast-1-genome-references/dataset"
    "eu-central-1"   = "aws-eu-central-1-genome-references/dataset"
    "eu-west-1"      = "aws-eu-west-1-genome-references/dataset"
    "eu-west-2"      = "aws-eu-west-2-genome-references/dataset"
    "il-central-1"   = "aws-il-central-1-genome-references/dataset"
  }, var.region, null)

  additional_buckets = var.additional_buckets != null ? var.additional_buckets : []
  genome_references_bucket = var.genome_references_bucket != null ? [var.genome_references_bucket] : [local.genome_references_bucket_default]
  buckets = [for bucket in concat([aws_s3_bucket.output_bucket.bucket], local.additional_buckets, local.genome_references_bucket): "arn:aws:s3:::${bucket}"]
  ecr_resources = concat(["arn:aws:ecr:${var.region}:${data.aws_caller_identity.current.account_id}:*"], [for account in var.external_ecr_accounts: "arn:aws:ecr:${var.region}:${account}:*"]) 
}


data "aws_iam_policy_document" "health_omics_user_policy" {
  statement {
    sid = "AllowPassRole"
    actions = [
      "iam:PassRole"
    ]

    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["omics.amazonaws.com"]
    }
  }

  statement {
    sid = "AllowOmicsActions"
    actions = [
      "omics:*"
    ]
    resources = ["*"]
  }

  statement {
    sid = "AllowS3ListBucket"
    actions = [
      "s3:ListBucket"
    ]

    resources = [for bucket in local.buckets: bucket]
  }

  statement {
    sid = "AllowS3GetObject"
    actions = [
      "s3:GetObject"
    ]

    resources = [for bucket in local.buckets: "${bucket}/*"]
  }

  statement {
    sid = "AllowReadLogs"
    actions = [
      "logs:DescribeLogStreams",
      "logs:GetLogEvents",
    ]

    resources = [
      "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/omics/*"
    ]
  }
}

data "aws_iam_policy_document" "health_omics_trust_policy" {
  statement {
    sid = "AllowHealthOmicsService"
    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type        = "Service"
      identifiers = ["omics.amazonaws.com"]
    }
  }
}


data "aws_iam_policy_document" "health_omics_service_policy" {
  statement {
    sid = "AllowS3ListBucket"
    actions = [
      "s3:ListBucket"
    ]

    resources = [for bucket in local.buckets: bucket]
  }

  statement {
    sid = "AllowS3GetObject"
    actions = [
      "s3:GetObject"
    ]

    resources = [for bucket in local.buckets: "${bucket}/*"]
  }

  statement {
    sid = "UploadFilesToS3"
    actions = [
      "s3:PutObject",
    ]

    resources = [
      aws_s3_bucket.output_bucket.arn,
      "${aws_s3_bucket.output_bucket.arn}/*"
    ]
  }

  statement {
    sid = "AllowECRActions"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer"
    ]
    resources = local.ecr_resources
      
  }

  statement {
    sid = "AllowLogs"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:CreateLogGroup",
      "logs:DescribeLogStreams",
    ]

    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/omics/*"
    ]
  }
}

data "aws_iam_policy_document" "health_omics_ecr_policy" {
  statement {
    sid       = "OmicsWorkflow Access"
    effect    = "Allow"
    
    principals {
      type        = "Service"
      identifiers = ["omics.amazonaws.com"]
    }

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer"
    ]
  }
}
