# Vault Authentication for Kubernetes Applications Deployed By Gitlab CI/CD

## Overview

The primary purpose of this module is to replace Ansible tasks used to create the Vault authentication roles and polices.  Version 1.x is only intended to be used with a private Vault cluster.  Given the inconsistencies of the names of the resources created by the Ansible tasks, very little is done by the module to enforce naming conventions.  The K/V2 paths in the Vault polices created by Ansible are not carried over to Terraform because the K/V2 engine is not mounted in the cluster nor are there any plans to do so.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_vault"></a> [vault](#requirement\_vault) | >= 3.21 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_vault"></a> [vault](#provider\_vault) | >= 3.21 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [vault_identity_entity.this](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/identity_entity) | resource |
| [vault_identity_entity_alias.this](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/identity_entity_alias) | resource |
| [vault_kubernetes_auth_backend_role.this](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/kubernetes_auth_backend_role) | resource |
| [vault_policy.this](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/policy) | resource |
| [vault_policy_document.this](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/data-sources/policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_application_kv_secrets"></a> [application\_kv\_secrets](#input\_application\_kv\_secrets) | The names of K/V1 secrets whose paths are prefixed with `secret/<application_name>/<environment>` to include in the application's Vault policy. | `set(string)` | <pre>[<br>  ""<br>]</pre> | no |
| <a name="input_application_name"></a> [application\_name](#input\_application\_name) | The name of the application as it appears in the Vault resource names and policy paths. | `string` | n/a | yes |
| <a name="input_auth_backend"></a> [auth\_backend](#input\_auth\_backend) | An object containing the attributes of the role's Vault authentication backend | <pre>object({<br>    accessor = string<br>    path     = string<br>  })</pre> | n/a | yes |
| <a name="input_custom_kv_secrets"></a> [custom\_kv\_secrets](#input\_custom\_kv\_secrets) | Additional K/V1 secrets whose paths do not follow established naming conventions covered by the `application_kv_secrets` and `external_kv_secrets` variables. | `set(string)` | `[]` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | The short name of the deployment environment.  Must be set to either `dev` or `prod`. | `string` | n/a | yes |
| <a name="input_external_kv_secrets"></a> [external\_kv\_secrets](#input\_external\_kv\_secrets) | The names of K/V1 secrets whose paths are prefixed with `secret/external` to include in the application's Vault policy.  The value of the `environment` variable is added as a suffix to construct the full path. | `list(string)` | `[]` | no |
| <a name="input_metadata"></a> [metadata](#input\_metadata) | A map containing data to add to every Vault resource as metadata. | `map(string)` | `{}` | no |
| <a name="input_policies"></a> [policies](#input\_policies) | The names of additional policies to attach to the Vault tokens created by the role. | `set(string)` | `[]` | no |
| <a name="input_role_name_prefix"></a> [role\_name\_prefix](#input\_role\_name\_prefix) | An optional prefix for the auth role's name.  Defaults to empty string. | `string` | `""` | no |
| <a name="input_service_accounts"></a> [service\_accounts](#input\_service\_accounts) | A list of the application's Kubernetes service accounts allowed to authenticate using the role. | <pre>list(object({<br>    name      = string<br>    namespace = string<br>    uid       = string<br>  }))</pre> | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_entities"></a> [entities](#output\_entities) | A map whose keys are the UIDs of the Kubernetes service accounts allowed to authenticate with the auth role and whose values are object's containing the attributes of the corresponding identity entity. |
| <a name="output_policy_name"></a> [policy\_name](#output\_policy\_name) | The name of the application's Vault policy. |
| <a name="output_role_name"></a> [role\_name](#output\_role\_name) | The name of the application's Kubernetes auth role. |
<!-- END_TF_DOCS -->