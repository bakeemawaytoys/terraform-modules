output "certificate_authority_base64" {
  description = "The cluster endpoint's certificate authority's root certificate encoded in base64."
  value       = data.aws_eks_cluster.cluster.certificate_authority[0].data
}

output "certificate_authority_pem" {
  description = "The cluster endpoint's certificate authority's root certificate encoded in PEM format."
  value       = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
}

output "cluster_arn" {
  description = "The AWS ARN of the EKS cluster."
  value       = data.aws_eks_cluster.cluster.arn
}

output "cluster_creator_arn" {
  description = "The AWS ARN of the IAM principal that created the EKS cluster.  This is the principal with implicit system:masters access to the cluster's k8s API."
  value       = local.cluster_creator
}

output "cluster_endpoint" {
  description = "The URL of the cluster's Kubernetes API."
  value       = data.aws_eks_cluster.cluster.endpoint
}

output "cluster_name" {
  description = "The name of the EKS cluster."
  value       = var.cluster_name
}

output "cluster_security_group_id" {
  description = "The unique identifier of the cluster security group created by EKS."
  value       = local.cluster_security_group_id
}

output "k8s_version" {
  description = "The version of Kubernetes running in the cluster."
  value       = var.k8s_version
  depends_on  = [aws_cloudformation_stack.cluster]
}

output "log_group_arn" {
  description = "The ARN of the CloudWatch log group containing the Kubernetes control plane logs."
  value       = aws_cloudwatch_log_group.cluster.arn
}

output "cloudformation_role_arn" {
  description = "The ARN of the IAM role assumed by CloudFormation to manage the EKS cluster."
  value       = aws_iam_role.cloudformation_role.arn
}

output "cloudformation_role_name" {
  description = "The name of the IAM role assumed by CloudFormation to manage the EKS cluster."
  value       = aws_iam_role.cloudformation_role.name
}

output "service_account_issuer" {
  description = "The OpenID issuer of the cluster's service account tokens."
  value       = "https://${aws_iam_openid_connect_provider.cluster.url}"
}

output "service_account_oidc_audience_variable" {
  description = "The name of the OIDC 'audience' variable to use for IAM policy condition keys in the trust policies of IAM roles for k8s service accounts. "
  value       = local.oidc_audience_variable
}

output "service_account_oidc_provider_arn" {
  description = "The ARN of the IAM OIDC provider to use for IAM roles for k8s service accounts."
  value       = aws_iam_openid_connect_provider.cluster.arn
}

output "service_account_oidc_provider_name" {
  description = "The name of the IAM OIDC provider to use for IAM roles for k8s service accounts."
  value       = local.oidc_provider_id
}

output "service_account_oidc_subject_variable" {
  description = "The name of the OIDC 'sub' variable to use for IAM policy condition keys in the trust policies of IAM roles for k8s service accounts. "
  value       = local.oidc_subject_variable
}

output "service_role_arn" {
  description = "The ARN of the IAM role assumed by the EKS cluster."
  value       = data.aws_iam_role.cluster_service_role.arn
}

output "service_role_name" {
  description = "The name of the IAM role assumed by the EKS cluster."
  value       = data.aws_iam_role.cluster_service_role.name
}
