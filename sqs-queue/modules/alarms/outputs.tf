output "queue_depth_alarm" {
  description = "An object containing the attributes of the alarm that triggers when the depth of the queue breaches the configured threshold."
  value       = aws_cloudwatch_metric_alarm.queue_depth
}

output "queue_depth_alarm_arn" {
  description = "The ARN of the alarm that triggers when the depth of the queue breaches the configured threshold."
  value       = aws_cloudwatch_metric_alarm.queue_depth.arn
}

output "queue_depth_alarm_name" {
  description = "The name of the alarm that triggers when the depth of the queue breaches the configured threshold."
  value       = aws_cloudwatch_metric_alarm.queue_depth.alarm_name
}

output "queue_depth_alarm_event_pattern" {
  description = "The pattern to use for EventBridge rules that trigger off of the queue depth alarm."
  value = jsonencode({

    source = [
      "aws.cloudwatch"
    ]
    detail-type = [
      "CloudWatch Alarm State Change"
    ]
    resources = [
      aws_cloudwatch_metric_alarm.queue_depth.arn
    ]
  })
}

output "message_age_alarm" {
  description = "An object containing the attributes of the alarm that triggers when the age of the oldest message breaches the configured threshold."
  value       = aws_cloudwatch_metric_alarm.message_age
}

output "message_age_alarm_arn" {
  description = "The ARN of the alarm that triggers when the age of the oldest message depth breaches the configured threshold."
  value       = aws_cloudwatch_metric_alarm.message_age.arn
}

output "message_age_alarm_name" {
  description = "The name of the alarm that triggers when the age of the oldest message breaches the configured threshold."
  value       = aws_cloudwatch_metric_alarm.message_age.alarm_name
}

output "message_age_alarm_event_pattern" {
  description = "The pattern to use for EventBridge rules that trigger off of the message age alarm."
  value = jsonencode({

    source = [
      "aws.cloudwatch"
    ]
    detail-type = [
      "CloudWatch Alarm State Change"
    ]
    resources = [
      aws_cloudwatch_metric_alarm.message_age.arn
    ]
  })
}
