terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.50"
    }
  }
  required_version = ">= 1.3"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  oidc_variable_prefix = split("oidc-provider/", var.eks_cluster.service_account_oidc_provider_arn)[1]
  tags = merge(
    var.tags,
    {
      "kubernetes.io/cluster/${var.eks_cluster.cluster_name}" = "owned"
      "kubernetes.io/cluster"                                 = var.eks_cluster.cluster_name
    }
  )
}

data "aws_iam_policy_document" "trust_policy" {
  statement {
    principals {
      identifiers = [var.eks_cluster.service_account_oidc_provider_arn]
      type        = "Federated"
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      values   = ["sts.amazonaws.com"]
      variable = "${local.oidc_variable_prefix}:aud"
    }
    condition {
      test     = "StringLike"
      values   = ["system:serviceaccount:${var.service_account.namespace}:${var.service_account.name}"]
      variable = "${local.oidc_variable_prefix}:sub"
    }
  }
}

locals {

  # Normalize the writer bucket definitions
  writer_buckets = [for b in try(var.s3_access.writer_buckets, []) : {
    arn         = b.arn == null ? "arn:aws:s3:::${b.bucket}" : b.arn
    kms_key_arn = b.sse_kms_key_arn
    prefixes    = b.prefixes
  }]

  writer_bucket_arns = distinct(local.writer_buckets[*].arn)
  writer_object_arns = distinct(flatten([for b in local.writer_buckets : formatlist("${b.arn}/%s", b.prefixes)]))



  # Normalize the reader bucket definitions
  reader_buckets = [for b in try(var.s3_access.reader_buckets, []) : {
    arn         = b.arn == null ? "arn:aws:s3:::${b.bucket}" : b.arn
    kms_key_arn = b.sse_kms_key_arn
    prefixes    = b.prefixes
  }]

  reader_bucket_arns = distinct(local.reader_buckets[*].arn)
  reader_object_arns = distinct(flatten([for b in local.reader_buckets : formatlist("${b.arn}/%s", b.prefixes)]))


  # Merge together the bucket and object ARNs to minimize the number of statements required to implement the policy.
  all_buckets     = concat(local.writer_buckets, local.reader_buckets)
  all_bucket_arns = distinct(concat(local.writer_bucket_arns, local.reader_bucket_arns))
  all_object_arns = distinct(concat(local.writer_object_arns, local.reader_object_arns))


  # Create locals to consolidate the statements that allow the role to use any bucket keys that have been provided.
  encrypted_writer_buckets = [for b in local.writer_buckets : b if b.kms_key_arn != null]
  writer_key_arns          = distinct([for b in local.writer_buckets : b.kms_key_arn if b.kms_key_arn != null])

  encrypted_reader_buckets = [for b in local.reader_buckets : b if b.kms_key_arn != null]
  reader_key_arns          = distinct([for b in local.encrypted_reader_buckets : b.kms_key_arn if b.kms_key_arn != null])

  all_bucket_key_arns = distinct(concat(local.writer_key_arns, local.reader_key_arns))

  # Construct a map of key arns to the set of bucket arns of the buckets that are encrypted with that key
  # Each entry in the map will correspond to a statement in the policy for that key.  The bucket ARNs are used for the kms:EncryptionContext:aws:s3:arn condition key
  # This approach consolidates the statements to minimize the size of the policy.
  writer_bucket_keys = { for arn in local.writer_key_arns : arn => distinct([for b in local.encrypted_writer_buckets : b.arn if b.kms_key_arn == arn]) }
  # This map is used to construct the decryption statements.  It contains the keys from both reader and writer buckets because writers also have read access.
  all_bucket_keys = { for arn in local.all_bucket_key_arns : arn => distinct([for b in local.all_buckets : b.arn if b.kms_key_arn == arn]) }

}

# The actions lists are borrowed from the SAM policy templates with the following modifications.  https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-policy-template-list.html#s3-full-access-policy
# * The multi-part upload actions have been added to support large objects
# * Object ACL write permissions have been removed because ACLs are more or less deprecated. https://docs.aws.amazon.com/AmazonS3/latest/userguide/about-object-ownership.html
data "aws_iam_policy_document" "s3" {
  # Abuse the for_each meta attribute to determine if the S3 policy is needed
  for_each = toset(var.s3_access == null ? [] : ["access"])


  dynamic "statement" {
    for_each = 0 < length(local.all_bucket_arns) ? ["Enabled"] : []
    content {
      sid = "BucketAccess"
      actions = [
        "s3:GetBucketLocation",
        "s3:ListBucket",
        "s3:ListBucketMultipartUploads",
        "s3:ListBucketVersions",
      ]
      resources = local.all_bucket_arns
      condition {
        test     = "StringEquals"
        values   = [data.aws_caller_identity.current.account_id]
        variable = "s3:ResourceAccount"
      }
    }
  }

  dynamic "statement" {
    for_each = 0 < length(local.all_object_arns) ? ["Enabled"] : []
    content {
      sid = "ObjectReadAccess"
      actions = [
        "s3:GetObject",
        "s3:GetObjectAttributes",
        "s3:GetObjectLegalHold",
        "s3:GetObjectRetention",
        "s3:GetObjectTagging",
        "s3:GetObjectVersion",
        "s3:GetObjectVersionAttributes",
        "s3:GetObjectVersionTagging",
        "s3:ListMultipartUploadParts",
      ]
      resources = local.all_object_arns
      condition {
        test     = "StringEquals"
        values   = [data.aws_caller_identity.current.account_id]
        variable = "s3:ResourceAccount"
      }
    }
  }

  dynamic "statement" {
    for_each = 0 < length(local.writer_object_arns) ? ["Enabled"] : []
    content {
      sid = "ObjectWriteAccess"
      actions = [
        "s3:AbortMultipartUpload",
        "s3:DeleteObject",
        "s3:DeleteObjectTagging",
        "s3:DeleteObjectVersion",
        "s3:DeleteObjectVersionTagging",
        "s3:PutObject",
        "s3:PutObjectLegalHold",
        "s3:PutObjectRetention",
        "s3:PutObjectTagging",
        "s3:PutObjectVersionTagging",
      ]
      resources = local.writer_object_arns
      condition {
        test     = "StringEquals"
        values   = [data.aws_caller_identity.current.account_id]
        variable = "s3:ResourceAccount"
      }
    }
  }

  # Info on KMS permissions for buckets that are configured with a server-side KMS CMK is at  https://repost.aws/knowledge-center/s3-large-file-encryption-kms-key
  # Info on the encryption context is at https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingKMSEncryption.html#encryption-context
  # Info on the encryption context condition key is https://docs.aws.amazon.com/kms/latest/developerguide/conditions-kms.html#conditions-kms-encryption-context

  dynamic "statement" {
    for_each = local.writer_bucket_keys
    content {
      actions = [
        "kms:GenerateDataKey",
      ]
      resources = [statement.key]
      condition {
        test     = "StringEquals"
        values   = ["s3.${data.aws_region.current.name}.amazonaws.com"]
        variable = "kms:ViaService"
      }
      condition {
        test     = "StringEquals"
        values   = [data.aws_caller_identity.current.account_id]
        variable = "kms:CallerAccount"
      }
      condition {
        test     = "StringEquals"
        values   = statement.value
        variable = "kms:EncryptionContext:aws:s3:arn"
      }
    }
  }

  dynamic "statement" {
    for_each = local.all_bucket_keys
    content {
      actions = [
        "kms:Decrypt",
      ]
      resources = [statement.key]
      condition {
        test     = "StringEquals"
        values   = ["s3.${data.aws_region.current.name}.amazonaws.com"]
        variable = "kms:ViaService"
      }
      condition {
        test     = "StringEquals"
        values   = [data.aws_caller_identity.current.account_id]
        variable = "kms:CallerAccount"
      }
      condition {
        test     = "StringEquals"
        values   = statement.value
        variable = "kms:EncryptionContext:aws:s3:arn"
      }
    }
  }
}

data "aws_iam_policy_document" "sqs" {
  # Abuse the for_each meta attribute to determine if the SQS policy is needed
  for_each = toset(var.sqs_access == null ? [] : ["access"])

  # The https://github.com/jegesh/python-sqs-listener library used by some projects requires permission
  # to execute the ListQueues action.
  statement {
    sid = "ResourceReadAccess"
    actions = [
      "sqs:ListQueues",
    ]
    resources = ["*"]
  }

  # https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-policy-template-list.html#sqs-send-message-policy
  dynamic "statement" {
    for_each = 0 < length(var.sqs_access.producer_queue_arns) ? ["enabled"] : []
    content {
      sid = "QueueProducer"
      actions = [
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl",
        "sqs:SendMessage*",
      ]
      resources = var.sqs_access.producer_queue_arns
    }
  }

  # https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-policy-template-list.html#sqs-poller-policy
  dynamic "statement" {
    for_each = 0 < length(var.sqs_access.consumer_queue_arns) ? ["enabled"] : []
    content {
      sid = "QueueConsumer"
      actions = [
        "sqs:ChangeMessageVisibility",
        "sqs:ChangeMessageVisibilityBatch",
        "sqs:DeleteMessage",
        "sqs:DeleteMessageBatch",
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl",
        "sqs:ReceiveMessage",
      ]
      resources = var.sqs_access.consumer_queue_arns
    }
  }
}

data "aws_iam_policy_document" "ses" {
  # Abuse the for_each meta attribute to determine if the SES policy is needed
  for_each = toset(var.ses_access == null ? [] : ["access"])

  dynamic "statement" {
    for_each = 0 < length(var.ses_access.email_identity_arns) ? ["enabled"] : []
    content {
      sid = "SendEmail"
      actions = [
        "ses:SendEmail",
        "ses:SendRawEmail",
      ]
      resources = var.ses_access.email_identity_arns
    }
  }
  statement {
    sid = "GetSendQuota"
    actions = [
      "ses:GetSendQuota",
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy" "this" {
  for_each = var.managed_policy_names
  name     = each.key
}

resource "aws_iam_role" "this" {
  assume_role_policy  = data.aws_iam_policy_document.trust_policy.json
  description         = "The ${var.service_account.name} service account in the ${var.service_account.namespace} namespace in the ${var.eks_cluster.cluster_name}"
  managed_policy_arns = values(data.aws_iam_policy.this)[*].arn
  name                = var.name
  path                = var.path

  dynamic "inline_policy" {
    for_each = data.aws_iam_policy_document.s3
    content {
      name   = "s3-${inline_policy.key}"
      policy = inline_policy.value.json
    }
  }

  dynamic "inline_policy" {
    for_each = data.aws_iam_policy_document.sqs
    content {
      name   = "sqs-${inline_policy.key}"
      policy = inline_policy.value.json
    }
  }

  dynamic "inline_policy" {
    for_each = data.aws_iam_policy_document.ses
    content {
      name   = "ses-${inline_policy.key}"
      policy = inline_policy.value.json
    }
  }

  dynamic "inline_policy" {
    for_each = var.custom_inline_policies
    content {
      name   = inline_policy.key
      policy = inline_policy.value
    }
  }

  tags = local.tags
}
