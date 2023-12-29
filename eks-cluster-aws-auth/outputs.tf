output "fargate_role_arn" {
  description = "The ARN of the IAM role to use as the cluster's Fargate pod execution role"
  value       = aws_iam_role.fargate.arn
}

output "fargate_role_name" {
  description = "The name of the IAM role to use as the cluster's Fargate pod execution role"
  value       = aws_iam_role.fargate.name
}

output "node_instance_profile_arn" {
  description = "The ARN of the instance profile attached to the  cluster's node group role"
  value       = aws_iam_instance_profile.node.arn
}

output "node_instance_profile_name" {
  description = "The name of the instance profile attached to the  cluster's node group role"
  value       = aws_iam_instance_profile.node.name
}

output "node_role_arn" {
  description = "The ARN of the IAM role to use as the cluster's node group role"
  value       = aws_iam_role.node.arn
}

output "node_role_name" {
  description = "The name of the IAM role to use as the cluster's node group role"
  value       = aws_iam_role.node.name
}
