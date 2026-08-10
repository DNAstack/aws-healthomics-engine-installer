data "aws_caller_identity" "current" {}

locals {
  output_bucket_name = coalesce(var.output_bucket_name, "${var.project_name}-raw-output")

  workflow_file_outputs_bucket_name = "${var.project_name}-workflow-file-outputs"

  genome_references_bucket_default = lookup(coalesce(var.genome_references_bucket_region_map, {}), var.aws_region, null)

  additional_buckets = var.additional_buckets != null ? var.additional_buckets : []
  genome_references_bucket = var.genome_references_bucket != null ? [var.genome_references_bucket] : compact([
    local.genome_references_bucket_default
  ])
  buckets = [
    for bucket in concat([
      aws_s3_bucket.output_bucket.bucket
    ], local.additional_buckets, local.genome_references_bucket, [local.workflow_file_outputs_bucket_name]) : "arn:aws:s3:::${bucket}"
  ]

  service_policy_buckets = [
    for bucket in compact(concat([
      aws_s3_bucket.output_bucket.bucket,
      var.external_raw_data_bucket_name,
    ], local.additional_buckets, local.genome_references_bucket)) : "arn:aws:s3:::${bucket}"
  ]

  ecr_resources = concat(["arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"], [
    for account in var.external_ecr_accounts : "arn:aws:ecr:${var.aws_region}:${account}:*"
  ])

  expire_tag_key   = "expire"
  expire_tag_value = "true"
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

    resources = [for bucket in local.buckets : bucket]
  }

  statement {
    sid = "AllowS3GetObject"
    actions = [
      "s3:GetObject"
    ]

    resources = [for bucket in local.buckets : "${bucket}/*"]
  }

  statement {
    sid = "AllowReadLogs"
    actions = [
      "logs:DescribeLogStreams",
      "logs:GetLogEvents",
    ]

    resources = [
      "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/omics/*"
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

    resources = [for bucket in local.service_policy_buckets : bucket]
  }

  statement {
    sid = "AllowS3GetObject"
    actions = [
      "s3:GetObject"
    ]

    resources = [for bucket in local.service_policy_buckets : "${bucket}/*"]
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
      "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/omics/*"
    ]
  }

  dynamic "statement" {
    for_each = length(var.outbound_identity_token_audiences) > 0 ? [1] : []
    content {
      sid = "AllowGetWebIdentityToken"
      actions = [
        "sts:GetWebIdentityToken"
      ]
      resources = ["*"]

      condition {
        test     = "ForAnyValue:StringEquals"
        variable = "sts:IdentityTokenAudience"
        values   = var.outbound_identity_token_audiences
      }

      condition {
        test     = "NumericLessThanEquals"
        variable = "sts:DurationSeconds"
        values   = ["3600"]
      }
    }
  }
}

data "aws_iam_policy_document" "health_omics_ecr_policy" {
  statement {
    sid    = "OmicsWorkflow Access"
    effect = "Allow"

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

data "aws_iam_policy_document" "output_bucket_policy" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.output_bucket.arn,
      "${aws_s3_bucket.output_bucket.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

data "aws_iam_policy_document" "output_bucket_tagger_trust" {
  statement {
    sid     = "AllowLambdaService"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "output_bucket_tagger" {
  statement {
    sid = "TagOutputObjects"
    actions = [
      "s3:GetObjectTagging",
      "s3:PutObjectTagging",
    ]

    resources = ["${aws_s3_bucket.output_bucket.arn}/*"]
  }

  statement {
    sid = "WriteFunctionLogs"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["${aws_cloudwatch_log_group.output_bucket_tagger.arn}:*"]
  }
}
