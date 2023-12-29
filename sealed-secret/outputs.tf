output "name" {
  description = "The name of both the SealdSecret resource and the Secret resource."
  value       = data.kubernetes_resource.sealed_secret.object.metadata.name
}

output "namespace" {
  description = "The namespace in which both the Secret and SealedSecret resource exist."
  value       = data.kubernetes_resource.sealed_secret.object.metadata.namespace
}
