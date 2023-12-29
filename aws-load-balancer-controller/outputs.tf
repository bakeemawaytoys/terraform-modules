output "shared_backend_security_group_arn" {
  description = "The ARN of the backend security group shared among all application load balancers managed by the controller."
  value       = aws_security_group.alb_backend.id
}

output "shared_backend_security_group_id" {
  description = "The ID of the backend security group shared among all application load balancers managed by the controller."
  value       = aws_security_group.alb_backend.id
}

output "shared_backend_security_group_resource" {
  description = "An object containing all of the attributes of the backend security group shared among all application load balancers managed by the controller."
  value       = aws_security_group.alb_backend
}

output "ingress_class_parameters_access_logs_attributes" {
  description = "A map containing the load balancer attributes that configure ALB access logging.  The values match the values supplied by the alb_access_logs variable.  Any IngressClassParams resource created outside fo the module should include these attributes."
  value       = local.access_logs_attributes
}

output "ingress_class_controller" {
  description = "The value to use for the spec.controller field on a Kubernetes IngressClass resource to have the controller reconcile Ingress resources configured with the class."
  value       = local.ingress_class_controller
}

output "ingress_class_parameters_api_group" {
  description = "The Kubernetes API group of the custom resource the controller uses to configure the IngressClasses it reconciles."
  value       = local.ingress_class_parameters_api_group
}

output "ingress_class_parameters_api_version" {
  description = "The Kubernetes API group of the custom resource the controller uses to configure the IngressClasses it reconciles."
  value       = local.ingress_class_parameters_api_version
}

output "ingress_class_parameters_kind" {
  description = "The Kubernetes Kind of the custom resource the controller uses to configure the IngressClasses it reconciles."
  value       = local.ingress_class_parameters_kind
}

output "internal_ingress_class_name" {
  description = "The name of the IngressClass resource to use for internal application load balancers."
  value       = kubernetes_ingress_class_v1.predefined["internet-facing"].metadata[0].name
}

output "internet_facing_ingress_class_name" {
  description = "The name of the IngressClass resource to use for internet-facing application load balancers."
  value       = kubernetes_ingress_class_v1.predefined["internet-facing"].metadata[0].name
}

output "pod_readiness_gate_namespace_labels" {
  description = "A map containing the labels to add to a namespace to enable the controller's pod readiness gate in that namespace.  https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/deploy/pod_readiness_gate"
  value = {
    "elbv2.k8s.aws/pod-readiness-gate-inject" = "enabled"
  }
}

output "service_account_role_name" {
  description = "The name of the IAM role created for the controller's k8s service account."
  value       = aws_iam_role.service_account.name
}

output "service_account_role_arn" {
  description = "The ARN of the IAM role created for the controller's k8s service account."
  value       = aws_iam_role.service_account.arn
}

output "service_load_balancer_class" {
  description = "When creating a Kubernetes Service resource whose type is LoadBalancer, specify the spec.loadBalancerClass attribute of the Service to this value to have the controller manage the service's NLB.  https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/guide/service/nlb/"
  value       = "service.k8s.aws/nlb"
}
