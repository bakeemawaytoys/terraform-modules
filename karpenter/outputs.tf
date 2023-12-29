output "bottlerocket_node_template_name" {
  description = "The name of the AWSNodeTemplate resource for Bottlerocket nodes."
  value       = kubectl_manifest.karpenter_bottlerocket_node_template.name
}

output "bottlerocket_node_template_provider_ref" {
  description = "An object to use as the value of the Karpenter Provisioner resource's spec.providerRef attribute for Bottlerocket nodes."
  value = {
    apiVersion = kubectl_manifest.karpenter_bottlerocket_node_template.api_version
    kind       = kubectl_manifest.karpenter_bottlerocket_node_template.kind
    name       = kubectl_manifest.karpenter_bottlerocket_node_template.name
  }
  depends_on = [
    kubectl_manifest.karpenter_bottlerocket_node_template
  ]
}

output "required_tags" {
  description = "A map of AWS tags that Karpenter must apply to the EC2 resources it creates.  It must be included in the spec.tags attribute in any Karpenter AWSNodeTemplate resource."
  value       = local.required_node_template_tags
}

output "node_security_group_selector" {
  description = "A string containing the cluster security group IDs separated by a comma.  Intended to be used as the value of the spec.securityGroupSelector.aws-id attribute in Karpenter AWSNodeTemplate K8s resources."
  value       = local.node_security_group_selector
}

output "node_subnet_id_selector" {
  description = "A string containing the node subnet IDs separated by a comma.  Intended to be used as the value of the spec.subnetSelector.aws-id attribute in Karpenter AWSNodeTemplate K8s resources."
  value       = local.node_subnet_id_selector
}
