terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.50"
    }
  }
  required_version = ">= 1.3.9"
}

locals {
  is_fifo     = var.type == "fifo"
  name_prefix = join("-", compact([var.name, var.environment]))
  name_suffix = local.is_fifo ? ".fifo" : ""

  # convert the max size from kilobytes to bytes
  max_message_size = 1024 * var.max_message_size
  tags             = var.tags

  consumer_actions = [
    "sqs:ChangeMessageVisibility",
    "sqs:DeleteMessage",
    "sqs:GetQueueAttributes",
    "sqs:GetQueueUrl",
    "sqs:ReceiveMessage",
  ]

  producer_actions = [
    "sqs:GetQueueUrl",
    "sqs:SendMessage",
  ]

}

resource "aws_sqs_queue" "dlq" {
  for_each         = var.dead_letter_queue.enabled ? { "${local.name_prefix}-dlq${local.name_suffix}" = var.dead_letter_queue } : {}
  fifo_queue       = local.is_fifo
  name             = each.key
  max_message_size = local.max_message_size

  # Set the retention to the maximum value to ensure there is plenty of time to deal with the messages
  message_retention_seconds = 14 * (24 * 60 * 60)

  # Set an empty redrive policy to ensure one isn't added outside of the module.
  redrive_policy          = null
  sqs_managed_sse_enabled = true
  tags                    = local.tags
}

resource "aws_sqs_queue" "this" {

  content_based_deduplication = local.is_fifo ? var.fifo_settings.content_based_deduplication : null
  delay_seconds               = var.delay_seconds
  deduplication_scope         = local.is_fifo ? var.fifo_settings.deduplication_scope : null
  fifo_queue                  = local.is_fifo
  fifo_throughput_limit       = local.is_fifo ? var.fifo_settings.fifo_throughput_limit : null
  max_message_size            = local.max_message_size
  message_retention_seconds   = var.message_retention_seconds
  name                        = "${local.name_prefix}${local.name_suffix}"
  receive_wait_time_seconds   = var.receive_wait_time_seconds
  # Add a redrive policy to the queue that prevents it from being used as a DLQ.
  redrive_allow_policy = jsonencode({
    redrivePermission = "denyAll"
  })

  sqs_managed_sse_enabled    = true
  tags                       = local.tags
  visibility_timeout_seconds = var.visibility_timeout_seconds
}

resource "aws_sqs_queue_redrive_policy" "this" {
  for_each = aws_sqs_queue.dlq
  redrive_policy = jsonencode({
    deadLetterTargetArn = each.value.arn
    maxReceiveCount     = var.max_receive_count
  })
  queue_url = aws_sqs_queue.this.url

  depends_on = [
    aws_sqs_queue_policy.dlq
  ]
}

resource "aws_sqs_queue_redrive_allow_policy" "dlq" {
  for_each  = aws_sqs_queue.dlq
  queue_url = each.value.url

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.this.arn]
  })
}

##################
# Queue Policies
##################

# Most of the statements come from https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-least-privilege-policy.html#sqs-least-privilege-overview
data "aws_iam_policy_document" "this" {

  statement {
    sid    = "EnforceHTTPS"
    effect = "Deny"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions = ["sqs:*"]
    resources = [
      aws_sqs_queue.this.arn,
    ]
    condition {
      test     = "Bool"
      values   = ["false"]
      variable = "aws:SecureTransport"
    }
  }


  dynamic "statement" {
    for_each = { for k, v in {
      Producers = {
        identifiers = var.producer_role_arns
        actions     = local.producer_actions
      }
      Consumers = {
        identifiers = var.consumer_role_arns
        actions     = local.consumer_actions
      }
      } : k => v if 0 < length(v.identifiers)
    }

    content {
      sid = statement.key
      principals {
        type        = "AWS"
        identifiers = statement.value.identifiers
      }
      actions = statement.value.actions
      resources = [
        aws_sqs_queue.this.arn,
      ]
    }
  }

  dynamic "statement" {
    for_each = { for service, arns in var.aws_service_message_producers : service => arns if 0 < length(arns) }
    content {
      principals {
        type        = "Service"
        identifiers = ["${statement.key}.amazonaws.com"]
      }
      actions = local.producer_actions
      resources = [
        aws_sqs_queue.this.arn,
      ]
      condition {
        test     = "ArnEquals"
        variable = "aws:SourceArn"
        values   = statement.value
      }
    }
  }
}

resource "aws_sqs_queue_policy" "this" {
  queue_url = aws_sqs_queue.this.url
  policy    = data.aws_iam_policy_document.this.json
}


data "aws_iam_policy_document" "dlq" {
  for_each = aws_sqs_queue.dlq
  # Prevent the use of the dead letter queue as a normal queue.
  # https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-least-privilege-policy.html#sqs-policy-dlq
  statement {
    sid    = "DenyProducerAccess"
    effect = "Deny"
    principals {
      type        = "AWS"
      identifiers = ["*"]

    }
    actions = [
      "sqs:SendMessage",
    ]
    resources = [
      each.value.arn,
    ]
    condition {
      test     = "ArnNotLike"
      values   = [aws_sqs_queue.this.arn]
      variable = "aws:SourceArn"
    }
  }

  statement {
    sid    = "EnforceHTTPS"
    effect = "Deny"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions = ["sqs:*"]
    resources = [
      each.value.arn,
    ]
    condition {
      test     = "Bool"
      values   = ["false"]
      variable = "aws:SecureTransport"
    }
  }

  dynamic "statement" {
    for_each = 0 < length(var.dead_letter_queue.consumer_role_arns) ? [var.dead_letter_queue.consumer_role_arns] : []
    content {
      sid = "Consumers"
      principals {
        type        = "AWS"
        identifiers = statement.value
      }
      actions = local.consumer_actions
      resources = [
        each.value.arn,
      ]
    }
  }
}

resource "aws_sqs_queue_policy" "dlq" {
  for_each  = aws_sqs_queue.dlq
  policy    = data.aws_iam_policy_document.dlq[each.key].json
  queue_url = each.value.url
}


#################
# Monitoring
################

module "alarms" {
  source = "./modules/alarms"

  actions           = var.cloudwatch_alarms.actions
  message_age_alarm = var.cloudwatch_alarms.message_age_alarm
  queue             = aws_sqs_queue.this
  queue_depth_alarm = var.cloudwatch_alarms.queue_depth_alarm
  tags              = local.tags
}

module "dlq_alarms" {
  for_each = aws_sqs_queue.dlq
  source   = "./modules/alarms"

  actions           = var.cloudwatch_alarms.actions
  message_age_alarm = var.cloudwatch_alarms.message_age_alarm
  queue             = each.value
  queue_depth_alarm = var.cloudwatch_alarms.queue_depth_alarm
  tags              = local.tags
}
