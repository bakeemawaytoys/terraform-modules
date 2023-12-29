terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.67"
    }
  }
  required_version = ">= 1.4"
}

locals {
  # S3 uses the strings to indicate the status of various features.
  # Define constants to use instead of repeating the same strings.
  disabled  = "Disabled"
  enabled   = "Enabled"
  suspended = "Suspended"
}

data "aws_caller_identity" "current" {}

# Changes to a bucket resource's bucket and bucket_prefix attributes don't seem to trigger
# resource recreation.  The resource is used to force recreation if either of them change.
resource "terraform_data" "bucket_name" {
  triggers_replace = {
    name        = var.name
    name_prefix = var.name_prefix
  }
}

resource "aws_s3_bucket" "this" {
  bucket              = var.name
  bucket_prefix       = var.name_prefix
  force_destroy       = var.prepare_for_deletion
  object_lock_enabled = var.object_lock.enabled
  tags                = var.tags

  lifecycle {
    precondition {
      condition     = !var.object_lock.enabled || (var.object_lock.enabled && var.versioning.enabled && !var.versioning.suspended)
      error_message = "If object lock is enabled, then versioning must be enabled but not suspended."
    }

    replace_triggered_by = [
      terraform_data.bucket_name
    ]
  }
}

resource "aws_s3_bucket_object_lock_configuration" "this" {
  count = var.object_lock.enabled ? 1 : 0

  bucket                = aws_s3_bucket.this.bucket
  expected_bucket_owner = data.aws_caller_identity.current.account_id

  dynamic "rule" {
    for_each = var.object_lock.default_retention == null ? [] : [var.object_lock.default_retention]
    content {
      default_retention {
        days  = rule.value.days
        mode  = rule.value.mode
        years = rule.value.years
      }
    }
  }
}

#################
# Permissions
#################

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.bucket
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Disable ACLs
resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.bucket

  rule {
    object_ownership = "BucketOwnerEnforced"
  }

  depends_on = [
    aws_s3_bucket_public_access_block.this,
  ]
}

data "aws_iam_policy_document" "this" {

  dynamic "statement" {
    # Prevent new object creation while the bucket emptys out
    for_each = var.prepare_for_deletion ? [1] : []
    content {
      sid    = "PrepareBucketForDeletion"
      effect = "Deny"
      principals {
        identifiers = ["*"]
        type        = "AWS"
      }
      actions = [
        "s3:PutObject"
      ]
      resources = [
        "${aws_s3_bucket.this.arn}/*"
      ]
    }
  }

  # Generate the statements for bucket actions
  dynamic "statement" {
    for_each = var.prepare_for_deletion ? [] : var.bucket_resource_policy_statements
    content {
      sid         = statement.value.sid
      effect      = statement.value.effect
      actions     = statement.value.actions
      not_actions = statement.value.not_actions
      resources   = [aws_s3_bucket.this.arn]

      dynamic "principals" {
        for_each = statement.value.principals
        content {
          identifiers = principals.value.identifiers
          type        = principals.value.type
        }
      }

      dynamic "condition" {
        for_each = statement.value.conditions
        content {
          test     = condition.value.test
          values   = condition.value.values
          variable = condition.value.variable
        }
      }
    }
  }

  # Generate the statements for object actions
  dynamic "statement" {
    for_each = var.prepare_for_deletion ? [] : var.object_resource_policy_statements
    content {
      sid           = statement.value.sid
      effect        = statement.value.effect
      actions       = statement.value.actions
      not_actions   = statement.value.not_actions
      resources     = formatlist("${aws_s3_bucket.this.arn}/%s", statement.value.prefixes)
      not_resources = formatlist("${aws_s3_bucket.this.arn}/%s", statement.value.not_prefixes)

      dynamic "principals" {
        for_each = statement.value.principals
        content {
          identifiers = principals.value.identifiers
          type        = principals.value.type
        }
      }

      dynamic "condition" {
        for_each = statement.value.conditions
        content {
          test     = condition.value.test
          values   = condition.value.values
          variable = condition.value.variable
        }
      }
    }
  }

  statement {
    sid    = "AllowSSLRequestsOnly"
    effect = "Deny"
    principals {
      identifiers = ["*"]
      type        = "AWS"
    }
    actions = [
      "s3:*"
    ]
    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*"
    ]
    condition {
      test     = "Bool"
      values   = ["false"]
      variable = "aws:SecureTransport"
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.bucket
  policy = data.aws_iam_policy_document.this.json

  depends_on = [
    # Ensure the access block is configured so that public policies are blocked
    aws_s3_bucket_public_access_block.this,
    # Ensure ownership controls are set before any access is granted by the policy
    aws_s3_bucket_ownership_controls.this,
    # Ensure versioning is set before any access is granted by the policy.
    # According to a note in the provider documentation, AWS recommends that you
    # wait for 15 minutes after enabling versioning before issuing write operations
    # (PUT or DELETE) on objects in the bucket.  While this explicit depends-on
    # won't block for the full 15 minutes, it does give the versioning a chance to
    # take effect.
    aws_s3_bucket_versioning.this,
  ]
}


#####################
# Object management
#####################

resource "aws_s3_bucket_intelligent_tiering_configuration" "this" {
  for_each = var.intelligent_tiering_archive_configurations

  bucket = aws_s3_bucket.this.bucket
  name   = each.key

  dynamic "filter" {
    for_each = each.value.filter == null ? [] : [each.value.filter]
    content {
      prefix = filter.value.prefix
      tags   = filter.value.tags
    }
  }

  status = each.value.enabled ? local.enabled : local.disabled

  dynamic "tiering" {
    for_each = { for k, v in each.value.tiering : k => v if v != null }
    content {
      access_tier = upper(tiering.key)
      days        = tiering.value
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  # lifecycle configs are not supported on mfa-enabled
  count = var.versioning.mfa_required ? 0 : 1

  bucket                = aws_s3_bucket.this.bucket
  expected_bucket_owner = data.aws_caller_identity.current.account_id

  rule {

    abort_incomplete_multipart_upload {
      days_after_initiation = var.prepare_for_deletion ? 1 : 7
    }
    filter {}

    # If this ID is modified, make sure to update the validation rule(s) on the object_lifecycle_rules variable.
    id     = "MultipartUploadCleanup"
    status = local.enabled
  }

  rule {

    expiration {
      expired_object_delete_marker = true
    }

    filter {}
    # If this ID is modified, make sure to update the validation rule(s) on the object_lifecycle_rules variable.
    id     = "DeleteMarkerCleanup"
    status = local.enabled
  }

  dynamic "rule" {
    # Add a rule to expire all objects to prepare the bucket for deletion
    for_each = var.prepare_for_deletion ? [1] : []
    content {
      expiration {
        days = 1
      }
      filter {}
      # If this ID is modified, make sure to update the validation rule(s) on the object_lifecycle_rules variable.
      id = "PrepareBucketForDeletion"
      noncurrent_version_expiration {
        noncurrent_days = 1
      }
      status = local.enabled
    }
  }

  dynamic "rule" {
    # Do not add any of the custom rules if the bucket is preparing for deletiong
    for_each = var.prepare_for_deletion ? {} : var.object_lifecycle_rules
    content {

      # Use a dynamic block for expiration to selecively add it or else there will be a perpetual drift if it is an empty block
      dynamic "expiration" {
        for_each = rule.value.expiration == null ? [] : [rule.value.expiration]
        content {
          date = expiration.value.date
          days = expiration.value.days
        }
      }

      # The filter block one of object_size_greater_than, object_size_less_than, prefix, tag, or the "and" block to be specified.  On top of that, the "and" block cannot be used if only one
      # of its attributes has a value. To abstract away these rules, the structure of the "filter" attribute is a flattened version of the "filter" block.  The logic to "unflatten" the attributes
      # is performed here. If more than one tag or more than one of the object_size_greater_than, object_size_less_than, or prefix attributes is specified in the variable (i.e. non-null),
      # then the "and" block is used.   The "and" block can be used if one tag is specified and must be used if more than one tag is specified. While the "tag" block on the filter
      # can be used when only on tag is specified, it is simpler to always use the "and" block if any tags are specified
      filter {
        object_size_greater_than = sum([for k, v in rule.value.filter : v == null ? 0 : 1 if k != "tags"]) < 2 && length(rule.value.filter.tags) == 0 ? rule.value.filter.object_size_greater_than : null
        object_size_less_than    = sum([for k, v in rule.value.filter : v == null ? 0 : 1 if k != "tags"]) < 2 && length(rule.value.filter.tags) == 0 ? rule.value.filter.object_size_less_than : null
        prefix                   = sum([for k, v in rule.value.filter : v == null ? 0 : 1 if k != "tags"]) < 2 && length(rule.value.filter.tags) == 0 ? rule.value.filter.prefix : null
        dynamic "and" {
          for_each = 1 < sum([for k, v in rule.value.filter : v == null ? 0 : 1 if k != "tags"]) || 0 < length(rule.value.filter.tags) ? [rule.value.filter] : []
          content {
            object_size_greater_than = and.value.object_size_greater_than
            object_size_less_than    = and.value.object_size_less_than
            prefix                   = and.value.prefix
            tags                     = and.value.tags
          }
        }
      }

      id = rule.key

      # Use a dynamic block for noncurrent_version_expiration to selecively add it or else there will be a perpetual drift if it is an empty block
      dynamic "noncurrent_version_expiration" {
        for_each = rule.value.noncurrent_version_expiration == null ? [] : [rule.value.noncurrent_version_expiration]
        content {
          newer_noncurrent_versions = noncurrent_version_expiration.value.newer_noncurrent_versions
          noncurrent_days           = noncurrent_version_expiration.value.noncurrent_days
        }
      }

      dynamic "noncurrent_version_transition" {
        for_each = rule.value.noncurrent_version_transition
        content {
          newer_noncurrent_versions = noncurrent_version_transition.value.newer_noncurrent_versions
          noncurrent_days           = noncurrent_version_transition.value.noncurrent_days
          storage_class             = noncurrent_version_transition.value.storage_class
        }
      }

      status = rule.value.enabled ? local.enabled : local.disabled

      dynamic "transition" {
        for_each = rule.value.transition
        content {
          date          = transition.value.date
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }
    }
  }

}

locals {
  versioning_status = var.versioning.enabled ? (var.versioning.suspended ? local.suspended : local.enabled) : local.disabled
}

resource "aws_s3_bucket_versioning" "this" {
  bucket                = aws_s3_bucket.this.bucket
  expected_bucket_owner = data.aws_caller_identity.current.account_id

  versioning_configuration {
    # If versioning is enabled and the bucket is preparing for deletion suspend versioning.  Otherwise use the standard logic
    status     = (var.versioning.enabled && var.prepare_for_deletion) ? local.suspended : local.versioning_status
    mfa_delete = var.versioning.mfa_required ? local.enabled : null
  }
}

########################
# Monitoring and Metrics
########################

resource "aws_s3_bucket_analytics_configuration" "this" {
  bucket = aws_s3_bucket.this.bucket
  name   = "Everything"
}

resource "aws_s3_bucket_logging" "this" {
  count = var.access_logging.enabled ? 1 : 0

  bucket = aws_s3_bucket.this.bucket

  # This resource supports the expected_bucket_owner argument but it is not set due to
  # a bug in the provider. https://github.com/hashicorp/terraform-provider-aws/issues/26627

  target_bucket = var.access_logging.bucket
  target_prefix = var.access_logging.prefix

}

resource "aws_s3_bucket_metric" "this" {
  bucket = aws_s3_bucket.this.bucket
  name   = "Everything"
}

########################
# Encryption
########################

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket                = aws_s3_bucket.this.bucket
  expected_bucket_owner = data.aws_caller_identity.current.account_id

  rule {
    bucket_key_enabled = true
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.bucket_encryption_key_arn == null ? "AES256" : "aws:kms"
      kms_master_key_id = var.bucket_encryption_key_arn
    }
  }
}

########################
# Disabled features
########################

# Even though acceleration isn't ever used, the resource is included to ensure it is
# managed by TF.  If the bucket name contains dots, do not create it at all.  S3 does
# not allow it to to be set even if the status is set to Suspended.
resource "aws_s3_bucket_accelerate_configuration" "this" {
  count                 = 0 < length(replace(aws_s3_bucket.this.bucket, "/[^.]/", "")) ? 0 : 1
  bucket                = aws_s3_bucket.this.bucket
  expected_bucket_owner = data.aws_caller_identity.current.account_id
  status                = local.suspended
}

resource "aws_s3_bucket_request_payment_configuration" "this" {
  bucket                = aws_s3_bucket.this.bucket
  expected_bucket_owner = data.aws_caller_identity.current.account_id
  payer                 = "BucketOwner"
}
