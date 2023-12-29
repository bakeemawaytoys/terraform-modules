variable "application_kv_secrets" {
  default     = [""]
  description = "The names of K/V1 secrets whose paths are prefixed with `secret/<application_name>/<environment>` to include in the application's Vault policy."
  nullable    = false
  type        = set(string)

  validation {
    condition     = alltrue([for path in var.application_kv_secrets : !startswith(path, "secret/")])
    error_message = "Values cannot have the `secret/` prefix.  The module automatically adds the prefix."
  }

  validation {
    condition     = alltrue([for path in var.application_kv_secrets : !startswith(path, "/")])
    error_message = "Values cannot start with the `/` character."
  }
}

variable "application_name" {
  description = "The name of the application as it appears in the Vault resource names and policy paths."
  nullable    = false
  type        = string
}

variable "role_name_prefix" {
  default     = ""
  description = "An optional prefix for the auth role's name.  Defaults to empty string."
  nullable    = false
  type        = string

  validation {
    condition     = !endswith(var.role_name_prefix, "-")
    error_message = "The role name prefix cannot end with a `-` character."
  }
}

variable "auth_backend" {
  description = "An object containing the attributes of the role's Vault authentication backend"
  nullable    = false
  type = object({
    accessor = string
    path     = string
  })
}

variable "custom_kv_secrets" {
  default     = []
  description = "Additional K/V1 secrets whose paths do not follow established naming conventions covered by the `application_kv_secrets` and `external_kv_secrets` variables."
  nullable    = false
  type        = set(string)

  validation {
    condition     = alltrue([for path in var.custom_kv_secrets : !startswith(path, "secret/")])
    error_message = "Values cannot have the `secret/` prefix.  The module automatically adds the prefix."
  }

  validation {
    condition     = alltrue([for path in var.custom_kv_secrets : !startswith(path, "/")])
    error_message = "Values cannot start with the `/` character."
  }
}

variable "environment" {
  description = "The short name of the deployment environment.  Must be set to either `dev` or `prod`."
  nullable    = false
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be set to `dev`, or `prod`."
  }
}

variable "external_kv_secrets" {
  default     = []
  description = "The names of K/V1 secrets whose paths are prefixed with `secret/external` to include in the application's Vault policy.  The value of the `environment` variable is added as a suffix to construct the full path."
  nullable    = false
  type        = list(string)

  validation {
    condition     = alltrue([for path in var.external_kv_secrets : !startswith(path, "secret/external/")])
    error_message = "Values cannot have the `secret/external/` prefix.  The module automatically adds the prefix."
  }

  validation {
    condition     = alltrue([for path in var.external_kv_secrets : !startswith(path, "/")])
    error_message = "Values cannot start with the `/` character."
  }

  validation {
    condition     = alltrue([for path in var.external_kv_secrets : !endswith(path, "/")])
    error_message = "Values cannot end with the `/` character."
  }

  validation {
    condition     = alltrue([for path in var.external_kv_secrets : path != ""])
    error_message = "Values cannot be the empty string."
  }
}

variable "metadata" {
  default     = {}
  description = "A map containing data to add to every Vault resource as metadata."
  nullable    = false
  type        = map(string)
}

variable "policies" {
  default     = []
  description = "The names of additional policies to attach to the Vault tokens created by the role."
  nullable    = false
  type        = set(string)
}

variable "service_accounts" {
  default     = []
  description = "A list of the application's Kubernetes service accounts allowed to authenticate using the role."
  type = list(object({
    name      = string
    namespace = string
    uid       = string
  }))
}
