terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = ">= 3.21"
    }
  }

  required_version = ">= 1.5"
}

locals {
  metadata = merge(
    var.metadata,
    {
      application_name = var.application_name
      managed_with     = "terraform"
    }
  )
  one_minute_in_seconds = 60
  one_hour_in_minutes   = 60 * local.one_minute_in_seconds


  kv1_mount_path        = "secret"
  application_root_path = join("/", compact([local.kv1_mount_path, var.application_name, var.environment]))
  external_root_path    = join("/", compact([local.kv1_mount_path, "external"]))

}

data "vault_policy_document" "this" {
  # The policy data resource does not provide a way to insert comments outside the context of a rule.
  # To work around this limitation, add a rule for a path that cannot exist in Vault and use its
  # description argument as documentation for the entire policy.
  rule {
    capabilities = ["deny"]

    # The '#' character is included in all but the first line because, as of version 3.15, the Vault provider
    # does not insert the leading '#' beyond the first line.
    description = <<-EOF
    This policy is managed by Terraform.
    # ----- Metadata -----
    %{for k, v in local.metadata~}# ${k}: ${v}
    %{endfor~}# --------------------
    EOF
    path        = "~~~ POLICY DOCUMENTATION  ~~~"
  }

  dynamic "rule" {
    for_each = var.application_kv_secrets
    content {
      capabilities = endswith(rule.value, "*") || endswith(rule.value, "/") ? ["read", "list"] : ["read"]
      path         = rule.value == "" ? local.application_root_path : join("/", [local.application_root_path, rule.value])
    }
  }

  dynamic "rule" {
    for_each = var.external_kv_secrets
    content {
      capabilities = endswith(rule.value, "*") ? ["read", "list"] : ["read"]
      path         = endswith(rule.value, "/*") ? join("/", [local.external_root_path, trimsuffix(rule.value, "/*"), var.environment, "*"]) : join("/", [local.external_root_path, rule.value, var.environment])
    }
  }

  dynamic "rule" {
    for_each = var.custom_kv_secrets
    content {
      capabilities = endswith(rule.value, "*") || endswith(rule.value, "/") ? ["read", "list"] : ["read"]
      path         = join("/", [local.kv1_mount_path, rule.value])
    }
  }
}

resource "vault_policy" "this" {
  name   = join("-", compact([var.application_name, var.environment]))
  policy = data.vault_policy_document.this.hcl
}

resource "vault_kubernetes_auth_backend_role" "this" {
  backend                          = var.auth_backend.path
  bound_service_account_names      = var.service_accounts[*].name
  bound_service_account_namespaces = var.service_accounts[*].namespace
  role_name                        = join("-", compact([var.role_name_prefix, var.application_name, var.environment]))
  token_policies                   = setunion([vault_policy.this.name], var.policies)
  token_max_ttl                    = 1 * local.one_hour_in_minutes
}

resource "vault_identity_entity" "this" {
  for_each = { for acct in var.service_accounts : acct.uid => acct }
  name     = join("-", compact([var.auth_backend.path, var.application_name, each.value.name]))
  metadata = merge(
    local.metadata,
    {
      backend_role_name             = vault_kubernetes_auth_backend_role.this.role_name
      k8s_service_account_name      = each.value.name
      k8s_service_account_namespace = each.value.namespace
    }
  )
}

resource "vault_identity_entity_alias" "this" {
  for_each = vault_identity_entity.this

  canonical_id   = each.value.id
  name           = each.key
  mount_accessor = var.auth_backend.accessor
  custom_metadata = merge(
    each.value.metadata,
    {
      entity_name = each.value.name
    }
  )
}
