output "elb_hostname" {
  description = "The hostname of the ELB the cluster created for the controller's Kubernetes service."
  value       = one(flatten(data.kubernetes_service_v1.controller.status[*].load_balancer[*].ingress[*].hostname))
}

output "namespace" {
  description = "The name of the Kubernetes namespace where the controller resources are deployed."
  value       = helm_release.nginx.namespace
}
