output "profile_name" {
  description = "The full name, including the generated suffix, of the profile."
  value       = aws_eks_fargate_profile.this.fargate_profile_name
}
