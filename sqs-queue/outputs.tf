output "arn" {
  description = "The ARN of the queue."
  value       = aws_sqs_queue.this.arn
}

output "dead_letter_queue" {
  description = "An object containing the attributes of the dead letter queue resource."
  value       = one(values(aws_sqs_queue.dlq))
}

output "dead_letter_queue_arn" {
  description = "The ARN of the dead letter queue."
  value       = one(values(aws_sqs_queue.dlq)[*].arn)
}

output "dead_letter_queue_name" {
  description = "The name of the dead letter queue."
  value       = one(values(aws_sqs_queue.dlq)[*].name)
}

output "dead_letter_queue_url" {
  description = "The URL of the dead letter queue."
  value       = one(values(aws_sqs_queue.dlq)[*].url)
}


output "message_age_alarm" {
  description = "An object containing the attributes of the alarm that triggers when the age of the oldest message breaches the configured threshold."
  value       = module.alarms.message_age_alarm
}

output "message_age_alarm_arn" {
  description = "The ARN of the alarm that triggers when the age of the oldest message depth breaches the configured threshold."
  value       = module.alarms.message_age_alarm_arn
}

output "message_age_alarm_name" {
  description = "The name of the alarm that triggers when the age of the oldest message breaches the configured threshold."
  value       = module.alarms.message_age_alarm_name
}

output "message_age_alarm_event_pattern" {
  description = "The pattern to use for EventBridge rules that trigger off of the message age alarm."
  value       = module.alarms.message_age_alarm_event_pattern
}

output "name" {
  description = "The name of the queue."
  value       = aws_sqs_queue.this.name
}

output "queue" {
  description = "An object containing the attributes of the queue resource."
  value       = aws_sqs_queue.this
}

output "queue_depth_alarm" {
  description = "An object containing the attributes of the alarm that triggers when the depth of the queue breaches the configured threshold."
  value       = module.alarms.queue_depth_alarm
}

output "queue_depth_alarm_arn" {
  description = "The ARN of the alarm that triggers when the depth of the queue breaches the configured threshold."
  value       = module.alarms.queue_depth_alarm_arn
}

output "queue_depth_alarm_name" {
  description = "The name of the alarm that triggers when the depth of the queue breaches the configured threshold."
  value       = module.alarms.queue_depth_alarm_name
}

output "queue_depth_alarm_event_pattern" {
  description = "The pattern to use for EventBridge rules that trigger off of the queue depth alarm."
  value       = module.alarms.queue_depth_alarm_event_pattern
}

output "url" {
  description = "The URL of the queue."
  value       = aws_sqs_queue.this.url
}
