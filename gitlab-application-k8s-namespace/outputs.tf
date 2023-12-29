output "name" {
  description = "The name of the namespace."
  value       = kubernetes_namespace_v1.this.metadata[0].name
}

output "application_service_account" {
  description = "An object containing the name and namespace attributes of the application's Kubernetes service account metadata."
  value = {
    name      = kubernetes_service_account_v1.application.metadata[0].name
    namespace = kubernetes_service_account_v1.application.metadata[0].namespace
    uid       = kubernetes_service_account_v1.application.metadata[0].uid
  }
}

output "application_service_account_name" {
  description = "The name of the application's Kubernetes service account."
  value       = kubernetes_service_account_v1.application.metadata[0].name
}

output "application_token_oidc_subject_claim" {
  description = "The full value of the OIDC sub claim on the application service account's token."
  value       = "system:serviceaccount:${kubernetes_service_account_v1.application.metadata[0].namespace}:${kubernetes_service_account_v1.application.metadata[0].name}"
}

output "gitlab_group_developer_member_k8s_group_name" {
  description = "The name of the Kubernetes group containing members of the Gitlab project's Gitlab group assigned the developer role."
  value       = local.group_member_k8s_groups[local.gitlab_developer_role_name]
}

output "gitlab_group_maintainer_member_k8s_group_name" {
  description = "The name of the Kubernetes group containing members of the Gitlab project's Gitlab group assigned the maintainer role."
  value       = local.group_member_k8s_groups[local.gitlab_maintainer_role_name]
}

output "gitlab_project_developer_member_k8s_group_name" {
  description = "The name of the Kubernetes group containing members of the Gitlab project assigned the developer role."
  value       = local.project_memeber_k8s_groups[local.gitlab_developer_role_name]
}

output "gitlab_project_maintainer_member_k8s_group_name" {
  description = "The name of the Kubernetes group containing members of the Gitlab project assigned the maintainer role."
  value       = local.project_memeber_k8s_groups[local.gitlab_maintainer_role_name]
}

output "iam_eks_role_module_service_account_value" {
  description = "A map suitable for use as the value of the cluster_service_accounts variable of version 5.2+ of the terraform-aws-modules/iam-eks-role public module."
  value = var.application_iam_role == null ? null : {
    (var.application_iam_role.cluster_name) = ["${kubernetes_service_account_v1.application.metadata[0].namespace}:${kubernetes_service_account_v1.application.metadata[0].name}"]
  }
}

output "iam_role_arn" {
  description = "The arn of the IAM role associated with the build pod service account or null if the build_pod_aws_iam_role variable was not assigned a value."
  value       = local.iam_role_arn
}

output "iam_role_name" {
  description = "The name of the IAM role associated with the build pod service account or null if the build_pod_aws_iam_role variable was not assigned a value."
  value       = local.iam_role_name
}

output "iam_role_path" {
  description = "The path of the IAM role associated with the build pod service account or null if the build_pod_aws_iam_role variable was not assigned a value."
  value       = local.iam_role_path
}

output "project_name_slug" {
  description = "The name of the project converted to a URL friendly value."
  value       = local.project_name_slug
}

output "group_name_slug" {
  description = "The name of the project converted to a URL friendly value."
  value       = local.group_name_slug
}

output "project" {
  description = "The value of the project variable augmented with the group and project name slugs."
  value = merge(
    var.project,
    {
      name_slug  = local.project_name_slug
      group_slug = local.group_name_slug
    }
  )
}
