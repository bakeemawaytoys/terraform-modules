output "dashboard_config" {
  description = "An object containing the values required for Grafana to load a dashboard from a Kubernetes configmap.  It is intended to be consumed as an argument in other modules."
  value = {
    folder_annotation_key = local.dashboard_folder_annotation_key
    namespace             = kubernetes_namespace_v1.grafana_dashboards.metadata[0].name
    label = {
      (local.dashboard_label_key) = local.dashboard_label_value
    }
  }
}

output "dashboard_folder_annotation_key" {
  description = "The Kubernetes annotation to add to Grafana dashboard configmaps to specify the folder for the dashboards."
  value       = local.dashboard_folder_annotation_key
}

output "dashboard_label" {
  description = "A map containing the Kubernetes label that must be present on a configmap for its data to be loaded as Granfana dashboard."
  value = {
    (local.dashboard_label_key) = local.dashboard_label_value
  }
}

output "dashboard_label_key" {
  description = "The key of the Kubernetes label that must be present on a configmap for its data to be loaded as Granfana dashboard."
  value       = local.dashboard_label_key
}

output "dashboard_label_value" {
  description = "The value of the Kubernetes label that must be present on a configmap for its data to be loaded as Granfana dashboard."
  value       = local.dashboard_label_value
}

output "dashboard_namespace" {
  description = "The name of the Kubernetes namespace that Grafana monitors for configmaps containing Grafana dashboard definitions."
  value       = kubernetes_namespace_v1.grafana_dashboards.metadata[0].name
}

output "namespace" {
  description = "The name of the Kubernetes namespace where the stack resources are deployed."
  value       = helm_release.prometheus_stack.namespace
}

output "prometheus_service_url" {
  description = "The URL of the Prometheus service in the Kubernetes cluster."
  value       = "http://${local.release_name}-prometheus.${var.namespace}.svc.cluster.local:${local.prometheus_port}"
}
