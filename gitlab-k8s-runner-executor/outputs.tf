output "build_pod_iam_role_name" {
  description = "The name of the IAM role associated with the build pod service account or null if the build_pod_aws_iam_role variable was not assigned a value."
  value       = try(var.build_pod_aws_iam_role.name, null)
}

output "build_pod_namespace" {
  description = "The name of the k8s namespace where the build pods run."
  value       = kubernetes_namespace_v1.build.metadata[0].name
}

output "build_pod_service_account" {
  description = "A map containing the name and namespace of the k8s service account created for the build pods."
  value = {
    name      = kubernetes_service_account_v1.build.metadata[0].name
    namespace = kubernetes_service_account_v1.build.metadata[0].namespace
    uid       = kubernetes_service_account_v1.build.metadata[0].uid
  }
}

output "build_pod_token_oidc_subject_claim" {
  description = "The full value of the OIDC sub claim on the build pod service account's token."
  value       = "system:serviceaccount:${kubernetes_service_account_v1.build.metadata[0].namespace}:${kubernetes_service_account_v1.build.metadata[0].name}"
}

output "iam_eks_role_module_service_account_value" {
  description = "A map suitable for use as the value of the cluster_service_accounts variable of version 5.2+ of the terraform-aws-modules/iam-eks-role public module."
  value = {
    (var.cluster_name) = ["${kubernetes_service_account_v1.build.metadata[0].namespace}:${kubernetes_service_account_v1.build.metadata[0].name}"]
  }
}

output "global_runner_name" {
  description = "The name of the runner that is globally unique across all runners registered with the Gitlab instance."
  value       = local.global_runner_name
}

output "cluster_runner_name" {
  description = "The name of the runner that is unique within the k8s cluster."
  value       = local.cluster_runner_name
}

output "runner_scope" {
  description = "The value of the `runner_scope` variable."
  value       = var.runner_scope
}
