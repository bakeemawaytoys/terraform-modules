terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.50"
    }
  }
  required_version = ">= 1.3.9"
}


resource "aws_cloudwatch_metric_alarm" "queue_depth" {
  actions_enabled     = var.queue_depth_alarm.actions_enabled
  alarm_actions       = var.actions
  alarm_description   = <<-EOF
  Monitors the approximate number of visible messages in the queue.  If the threshold is breached, it indicates there is an issue with the consumer.
  EOF
  alarm_name          = "sqs-${var.queue.name}-depth"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  dimensions = {
    "QueueName" = var.queue.name
  }
  evaluation_periods        = var.queue_depth_alarm.evaluation_periods
  insufficient_data_actions = var.actions
  metric_name               = "ApproximateNumberOfMessagesVisible"
  namespace                 = "AWS/SQS"
  ok_actions                = var.actions
  period                    = var.queue_depth_alarm.period
  statistic                 = "Sum"
  threshold                 = var.queue_depth_alarm.threshold
  treat_missing_data        = "breaching"
  tags                      = var.tags
}


resource "aws_cloudwatch_metric_alarm" "message_age" {
  actions_enabled     = var.message_age_alarm.actions_enabled
  alarm_actions       = var.actions
  alarm_description   = <<-EOF
  Monitors the average age of the oldest message in the queue.  If the threshold is breached, it indicates there is an issue with the consumer.
  EOF
  alarm_name          = "sqs-${var.queue.name}-message-age"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  dimensions = {
    "QueueName" = var.queue.name
  }
  evaluation_periods        = var.message_age_alarm.evaluation_periods
  insufficient_data_actions = var.actions
  metric_name               = "ApproximateAgeOfOldestMessage"
  namespace                 = "AWS/SQS"
  ok_actions                = var.actions
  period                    = var.message_age_alarm.period
  statistic                 = "Average"
  threshold                 = var.message_age_alarm.threshold
  treat_missing_data        = "breaching"
  tags                      = var.tags
}
