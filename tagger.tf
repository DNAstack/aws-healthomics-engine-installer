# This archive regenerates only on create/replace; archive_file never notices
# output_path missing on disk, so the zip is normally absent from the apply
# container. Safe because the Lambda below only reads filename on create,
# replace, or a code change (which replaces this archive too). Exception: a
# ForceNew Lambda replacement with tagger.py unchanged (in practice, changing
# output_bucket_name or project_name) fails on the missing zip. Recover with:
# terraform apply -replace=archive_file.output_bucket_tagger
resource "archive_file" "output_bucket_tagger" {
  type        = "zip"
  output_path = "${path.module}/function_source/tagger.zip"

  source {
    content  = file("${path.module}/function_source/tagger.py")
    filename = "index.py"
  }
}

resource "aws_iam_role" "output_bucket_tagger" {
  name               = "${local.output_bucket_name}-tagger"
  assume_role_policy = data.aws_iam_policy_document.output_bucket_tagger_trust.json

  tags = {
    created_by = "terraform"
  }
}

resource "aws_iam_role_policy" "output_bucket_tagger" {
  name   = "tag-transient-outputs"
  role   = aws_iam_role.output_bucket_tagger.id
  policy = data.aws_iam_policy_document.output_bucket_tagger.json
}

resource "aws_cloudwatch_log_group" "output_bucket_tagger" {
  name              = "/aws/lambda/${local.output_bucket_name}-tagger"
  retention_in_days = 30

  tags = {
    created_by = "terraform"
  }
}

resource "aws_lambda_function" "output_bucket_tagger" {
  function_name = "${local.output_bucket_name}-tagger"
  description   = "Tags non-log, non-manifest objects so the bucket lifecycle rules expire them"
  role          = aws_iam_role.output_bucket_tagger.arn
  runtime       = "python3.13"
  handler       = "index.handler"
  timeout       = 30

  filename = "${path.module}/function_source/tagger.zip"

  # Hashes the committed source rather than the generated zip. Referencing the
  # archive resource's own output would make this unknown-at-plan on every run,
  # republishing the function and putting churn into every plan.
  source_code_hash = filebase64sha256("${path.module}/function_source/tagger.py")

  environment {
    variables = {
      RETENTION_TAG_KEY   = local.transient_tag_key
      RETENTION_TAG_VALUE = local.transient_tag_value
    }
  }

  depends_on = [
    archive_file.output_bucket_tagger,
    aws_cloudwatch_log_group.output_bucket_tagger,
  ]

  tags = {
    created_by = "terraform"
  }
}

resource "aws_lambda_permission" "output_bucket_tagger" {
  statement_id   = "AllowExecutionFromOutputBucket"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.output_bucket_tagger.function_name
  principal      = "s3.amazonaws.com"
  source_arn     = aws_s3_bucket.output_bucket.arn
  source_account = data.aws_caller_identity.current.account_id
}

resource "aws_s3_bucket_notification" "output_bucket" {
  bucket = aws_s3_bucket.output_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.output_bucket_tagger.arn

    # Must stay a wildcard. Every .bam averages ~21 GB and therefore arrives as
    # CompleteMultipartUpload, not Put; narrowing this would silently miss
    # 99.17% of the bucket with no error and no visible symptom.
    events = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.output_bucket_tagger]
}
