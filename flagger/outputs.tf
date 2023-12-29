output "admin_cluster_role" {
  description = "The name of the Kubernetes ClusterRole that grants admin privileges to all Flagger custom resources."
  value       = kubernetes_cluster_role_v1.admin_aggregate.metadata[0].name
}

output "edit_cluster_role" {
  description = "The name of the Kubernetes ClusterRole that grants edit privileges to some Flagger custom resources."
  value       = kubernetes_cluster_role_v1.edit_aggregate.metadata[0].name
}

output "namespace" {
  description = "The namespace containing the Flagger deployment."
  value       = helm_release.this.namespace
}

output "view_cluster_role" {
  description = "The name of the Kubernetes ClusterRole that grants view privileges to some Flagger custom resources."
  value       = kubernetes_cluster_role_v1.view_aggregate.metadata[0].name
}
