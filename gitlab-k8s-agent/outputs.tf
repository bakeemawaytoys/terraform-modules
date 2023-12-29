output "service_account" {
  description = "The name and namespace of the k8s service account created for the agent."
  value = {
    name      = local.resource_name
    namespace = var.namespace
  }
}
