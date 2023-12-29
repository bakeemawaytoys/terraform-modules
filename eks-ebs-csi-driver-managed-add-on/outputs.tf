output "role_name" {
  description = "The name of the IAM role assumed by the driver."
  value       = aws_iam_role.service_account.name
}

output "role_arn" {
  description = "The ARN of the IAM role assumed by the driver."
  value       = aws_iam_role.service_account.arn
}

output "addon_version" {
  description = "The deployed version of the driver."
  value       = aws_eks_addon.driver.addon_version
}

output "default_storage_class_name" {
  description = "The name of the storage class that is annotated as the default."
  value       = kubernetes_storage_class_v1.ebs_default.metadata[0].name
}
