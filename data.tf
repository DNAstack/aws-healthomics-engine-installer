data "aws_caller_identity" "current" {}

data "aws_region" "current" {
  
}

locals {
  health_omics_arn   = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.health_omics_role_name}"
  additional_buckets = var.additional_buckets != null ? var.additional_buckets : []
  buckets            = concat([aws_s3_bucket.output_bucket.arn, "${aws_s3_bucket.output_bucket.arn}/*"], local.additional_buckets)
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
    sid = "AllowS3ReadOnlyAccess"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]

    resources = local.buckets
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
    sid = "AllowS3ReadOnlyAccess"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]

    resources = local.buckets
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