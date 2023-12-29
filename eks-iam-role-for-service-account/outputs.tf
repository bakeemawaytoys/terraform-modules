output "name" {
  description = "The name of the IAM role managed by this module."
  value       = aws_iam_role.this.name
}

output "arn" {
  description = "The ARN of the IAM role managed by this module."
  value       = aws_iam_role.this.arn

}

output "unique_id" {
  description = "The unique identifier assigned to the role by AWS."
  value       = aws_iam_role.this.unique_id
}
