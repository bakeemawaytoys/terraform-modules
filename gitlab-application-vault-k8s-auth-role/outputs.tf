output "role_name" {
  description = "The name of the application's Kubernetes auth role."
  value       = vault_kubernetes_auth_backend_role.this.role_name
}

output "entities" {
  description = "A map whose keys are the UIDs of the Kubernetes service accounts allowed to authenticate with the auth role and whose values are object's containing the attributes of the corresponding identity entity."
  value       = vault_identity_entity.this
}

output "policy_name" {
  description = "The name of the application's Vault policy."
  value       = vault_policy.this.name
}
