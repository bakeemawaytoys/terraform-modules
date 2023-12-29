output "application_log_group_arn" {
  description = "The ARN of the CloudWatch log group containing logs from application pods."
  value       = try(aws_cloudwatch_log_group.container_insights_logs["application"].arn, null)
}

output "application_log_group_name" {
  description = "The name of the CloudWatch log group containing logs from application pods."
  value       = try(aws_cloudwatch_log_group.container_insights_logs["application"].name, null)
}

output "cloudwatch_agent_iam_role_arn" {
  description = "The ARN of the AWS IAM role assumed by the CloudWatch agent."
  value       = module.cloudwatch_agent_role.iam_role_arn
}

output "cloudwatch_agent_iam_role_name" {
  description = "The name of the AWS IAM role assumed by the CloudWatch agent."
  value       = module.cloudwatch_agent_role.iam_role_name
}

output "dataplane_log_group_arn" {
  description = "The ARN of the CloudWatch log group containing kubelet, kube-proxy, and container runtime logs."
  value       = try(aws_cloudwatch_log_group.container_insights_logs["dataplane"].arn, null)
}

output "dataplane_log_group_name" {
  description = "The name of the CloudWatch log group containing kubelet, kube-proxy, and container runtime logs."
  value       = try(aws_cloudwatch_log_group.container_insights_logs["dataplane"].name, null)
}

output "fluent_bit_iam_role_arn" {
  description = "The ARN of the AWS IAM role assumed by Fluent Bit."
  value       = module.fluent_bit_role.iam_role_arn
}

output "fluent_bit_iam_role_name" {
  description = "The name of the AWS IAM role assumed by Fluent Bit."
  value       = module.fluent_bit_role.iam_role_name
}

output "host_log_group_arn" {
  description = "The ARN of the CloudWatch log group containing operating system logs generated by Kubernetes nodes."
  value       = try(aws_cloudwatch_log_group.container_insights_logs["host"].arn, null)
}

output "host_log_group_name" {
  description = "The name of the CloudWatch log group containing operating system logs generated by Kubernetes nodes."
  value       = try(aws_cloudwatch_log_group.container_insights_logs["host"].name, null)
}

output "metrics_log_group_arn" {
  description = "The ARN of the CloudWatch log group containing the Kubernetes metrics generated by the CloudWatch agent."
  value       = aws_cloudwatch_log_group.container_insights_metrics.arn
}

output "metrics_log_group_name" {
  description = "The name of the CloudWatch log group containing the Kubernetes metrics generated by the CloudWatch agent."
  value       = aws_cloudwatch_log_group.container_insights_metrics.name
}

output "namespace" {
  description = "The name of the Kubernetes namespace that contains the Container Insights objects managed by this module."
  value       = kubernetes_namespace_v1.cloudwatch.metadata[0].name
}
