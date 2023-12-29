output "vault_auth_backend" {
  description = "An object containing the attributes of the Kubernetes auth backend.  See https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/auth_backend for the available attributes."
  value       = vault_auth_backend.kubernetes
}

output "vault_auth_backend_accessor" {
  description = "The accessor of the Vault Kubernetes backed managed by this module."
  value       = vault_auth_backend.kubernetes.accessor
}

output "vault_auth_backend_full_path" {
  description = "The full path (including the auth/ prefix) to the Vault Kubernetes auth backend managed by this module."
  value       = "auth/${vault_auth_backend.kubernetes.path}"
}

output "vault_auth_backend_path" {
  description = "The path of the Vault Kubernetes auth backend managed by this module."
  value       = vault_auth_backend.kubernetes.path
}
