output "address" {
  description = "The generated hostname of the instance"
  value       = aws_db_instance.this.address
}

output "allocated_storage" {
  description = "The instance's allocated storage."
  value       = aws_db_instance.this.allocated_storage
}

output "backup_retention_period" {
  description = "The instance's backup retention period."
  value       = aws_db_instance.this.backup_retention_period
}

output "db_instance_identifier" {
  description = "The instance's identifier.  An alias of the identifier output."
  value       = aws_db_instance.this.identifier
}

output "engine" {
  description = "The database engine running in the instance."
  value       = aws_db_instance.this.engine
}

output "engine_version" {
  description = "The verison of the database engine running in the instance."
  value       = aws_db_instance.this.engine_version_actual
}

output "ca_cert_identifier" {
  description = "The identifer of the certificate authority's root certificate used to generate the instance's certificate."
  value       = aws_db_instance.this.ca_cert_identifier
}

output "cpu_utilization_alarm_arn" {
  description = "The ARN of the CloudWatch alarm that monitors the instance's CPUUtilization metric."
  value       = aws_cloudwatch_metric_alarm.this["cpu-utilization"].arn
}

output "disk_queue_depth_alarm_arn" {
  description = "The ARN of the CloudWatch alarm that monitors the instance's DiskQueueDepth metric."
  value       = aws_cloudwatch_metric_alarm.this["disk-queue-depth"].arn
}

output "final_snapshot_identifier" {
  description = "The name of the final snapshot created when the instance is destroyed."
  value       = aws_db_instance.this.final_snapshot_identifier
}

output "freeable_memory_alarm_arn" {
  description = "The ARN of the CloudWatch alarm that monitors the instance's FreeableMemory metric."
  value       = aws_cloudwatch_metric_alarm.this["freeable-memory"].arn
}

output "freeable_storage_alarm_arn" {
  description = "The ARN of the CloudWatch alarm that monitors the instance's FreeStorageSpace metric."
  value       = aws_cloudwatch_metric_alarm.this["freeable-storage"].arn
}

output "iam_role_arn" {
  description = "The ARN of the IAM role assumed by the instance."
  value       = aws_iam_role.this.arn
}

output "iam_role_name" {
  description = "The name of the IAM role assumed by the instance."
  value       = aws_iam_role.this.name
}

output "identifier" {
  description = "The identifier of the instance."
  value       = aws_db_instance.this.identifier
}

output "kms_key_id" {
  description = "The ARN of the KMS key used to encrypt the instance's storage."
  value       = aws_db_instance.this.kms_key_id
}

output "master_username" {
  description = "The username of the database engine's master user."
  value       = aws_db_instance.this.username
}

output "master_user_secret_arn" {
  description = "The ARN of the Secrets Manager secret that contains the master user's password or null if RDS does not manage the password."
  value       = one(aws_db_instance.this.master_user_secret[*].secret_arn)
}

output "port" {
  description = "The port number the instance listens on for client connections."
  value       = aws_db_instance.this.port
}

output "preferred_backup_window" {
  description = "The window of time when RDS takes automated snapshots of the instance."
  value       = aws_db_instance.this.backup_window
}

output "read_iops_alarm_arn" {
  description = "The ARN of the CloudWatch alarm that monitors the instance's ReadIOPS metric."
  value       = aws_cloudwatch_metric_alarm.this["read-iops"].arn
}

output "resource_id" {
  description = "The unique resource identifier of the instance."
  value       = aws_db_instance.this.resource_id
}

output "security_group_arn" {
  description = "The ARN of the security group managed by this module."
  value       = aws_security_group.this.arn
}

output "security_group_id" {
  description = "The identifier of the security group managed by this module."
  value       = aws_security_group.this.id
}

output "write_iops_alarm_arn" {
  description = "The ARN of the CloudWatch alarm that monitors the instance's WriteIOPS metric."
  value       = aws_cloudwatch_metric_alarm.this["write-iops"].arn
}
