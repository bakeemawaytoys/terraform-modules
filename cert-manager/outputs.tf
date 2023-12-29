output "issuer_acme_dns01_route53_solvers" {
  description = <<-EOF
  A list of objects suitable for use as the list of solvers on a cert-bot ClusterIssuer or Issuer resource.  The list containts items for every entry in the acme_dns01_route53_solvers variable.
  https://cert-manager.io/docs/reference/api-docs/#acme.cert-manager.io/v1.ACMEIssuerDNS01ProviderRoute53
  EOF
  value       = flatten(values(local.issuer_solvers))
  depends_on = [
    kubectl_manifest.crd,
    aws_iam_role_policy.service_account,
  ]
}

output "issuer_acme_dns01_route53_solvers_by_zone" {
  description = <<-EOF
  A map whose values are lists of objects suitable for use as elments in the list of solvers on a cert-bot ClusterIssuer or Issuer resource.
  Each entry in the map corresponds to an entry in the acme_dns01_route53_solvers variable.
  https://cert-manager.io/docs/reference/api-docs/#acme.cert-manager.io/v1.ACMEIssuerDNS01ProviderRoute53
  EOF
  value       = local.issuer_solvers
  depends_on = [
    kubectl_manifest.crd,
    aws_iam_role_policy.service_account,
  ]
}

output "service_account_role_name" {
  description = "The name of the IAM role created for the cert-manager k8s service account."
  value       = aws_iam_role.service_account.name
}

output "service_account_role_arn" {
  description = "The ARN of the IAM role created for the cert-manager k8s service account."
  value       = aws_iam_role.service_account.arn
}

output "route53_zone_ids" {
  description = "The unique identifiers of the Route53 public zones cert-manager has permission to use."
  value       = values(data.aws_route53_zone.zones)[*].zone_id
}

output "route53_zone_names" {
  description = "The names of the Route53 public zones cert-manager has permission to use."
  value       = values(data.aws_route53_zone.zones)[*].name
}

output "route53_zones" {
  description = "A list of objects contatining the attributes of the Route53 public zones cert-manager has permission to use."
  value       = values(data.aws_route53_zone.zones)
}

output "namespace" {
  description = "The name of the namespace containing all of the cert-manager resources."
  value       = kubernetes_namespace_v1.this.metadata[0].name
}
