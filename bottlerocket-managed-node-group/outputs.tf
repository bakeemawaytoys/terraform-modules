output "node_group_arn" {
  description = "The ARN of the node group created by the module."
  value       = aws_eks_node_group.this.arn
}

output "node_group_name" {
  description = "The name of the node group created by the module."
  # The node group ID returned by the module is the EKS Cluster name and EKS Node Group name separated by a colon (:)
  value = split(":", aws_eks_node_group.this.id)[1]
}

output "launch_template_arn" {
  description = "The ARN of the launch template created by the module."
  value       = aws_launch_template.this.arn
}

output "launch_template_id" {
  description = "The id of the launch template created by the module."
  value       = aws_launch_template.this.id
}
