output "bucket_name" {
  description = "The name of the S3 bucket where Velero stores its backup files."
  value       = aws_s3_bucket.velero.bucket
}

output "bucket_arn" {
  description = "The ARN of the S3 bucket where Velero stsores its back up files."
  value       = aws_s3_bucket.velero.arn
}

output "service_account_role_name" {
  description = "The name of the IAM role created for Velero's k8s service account."
  value       = aws_iam_role.service_account.name
}

output "service_account_role_arn" {
  description = "The ARN of the IAM role created for Velero's k8s service account."
  value       = aws_iam_role.service_account.arn
}

output "storage_location_name" {
  description = "The name of the BackupStorageLocation Kubernetes resource corresponding to the S3 bucket managed by this module."
  value       = local.storage_location_name
}
