resource "aws_s3_bucket_lifecycle_configuration" "output_bucket" {
  bucket = aws_s3_bucket.output_bucket.id

  # Everything the tagger marked: all workflow outputs except run logs and manifests.
  rule {
    id     = "expire-tagged-outputs"
    status = "Enabled"

    filter {
      tag {
        key   = local.expire_tag_key
        value = local.expire_tag_value
      }
    }

    expiration {
      days = var.output_bucket_expiration_days
    }
  }

  # Backstop. Objects the tagger never reached carry no tag and would otherwise
  # live forever; this bounds that to a known window. On a healthy bucket the only
  # objects it deletes are the run logs and manifests, so it doubles as their
  # retention policy. A whole-bucket rule cannot exclude them: that would need them
  # tagged, and then a tagger failure means no tag and no expiry — the original bug.
  rule {
    id     = "expire-all"
    status = "Enabled"

    filter {}

    expiration {
      days = var.output_bucket_max_retention_days
    }
  }

  # Parts of interrupted multipart uploads are billed indefinitely but appear in
  # neither object listings nor CloudWatch BucketSizeBytes. Age is the only way to
  # tell an abandoned upload from an in-flight one.
  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = var.output_bucket_abort_multipart_days
    }
  }

  lifecycle {
    precondition {
      condition     = var.output_bucket_expiration_days < var.output_bucket_max_retention_days
      error_message = "output_bucket_expiration_days must be less than output_bucket_max_retention_days, otherwise the catch-all rule would expire tagged objects first and the tag would have no effect."
    }
  }
}
