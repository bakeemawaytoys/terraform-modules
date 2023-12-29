variable "annotations" {
  default     = {}
  description = "An optional map of kubernetes annotations to attach to the SealedSecret resource created by the module."
  nullable    = false
  type        = map(string)

  validation {
    condition     = alltrue([for k in keys(var.annotations) : can(regex("^(?i)(([a-z0-9]/)|([a-z0-9][a-z0-9\\-.]{0,251}[a-z0-9])/)?(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))$", k))])
    error_message = "One or more annotation keys is syntactically invalid or null.  See https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/#syntax-and-character-set for details."
  }
}

variable "encrypted_data" {
  description = "A map of strings that is used to populate the 'spec.encryptedData' attribute of the SealedSecret resource."
  nullable    = false
  type        = map(string)

  validation {
    condition     = 0 < length(var.encrypted_data)
    error_message = "The 'encrypted_data' variable must contain at least one entry."
  }
}

variable "labels" {
  default     = {}
  description = "An optional map of kubernetes labels to attach to the SealedSecret resource created by the module."
  nullable    = false
  type        = map(string)

  validation {
    condition     = alltrue([for v in values(var.labels) : can(regex("^(?i)(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))?$", v))])
    error_message = "One or more label values is syntactically invalid or null.  See https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set for details."
  }

  validation {
    condition     = alltrue([for k in keys(var.labels) : can(regex("^(?i)(([a-z0-9]/)|([a-z0-9][a-z0-9\\-.]{0,251}[a-z0-9])/)?(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))$", k))])
    error_message = "One or more label keys is syntactically invalid or null.  See https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set for details."
  }
}

variable "name" {
  description = "The name to use for both the SealedSecret resource and the generated Secret resource."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.\\-]{0,251}[a-z0-9]$", var.name))
    error_message = "The 'name' variable must be a valid Kubernetes resource name as per https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#dns-subdomain-names"
  }
}

variable "namespace" {
  description = "The namespace where both the SealedSecret and Secret resources will be created."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.\\-]{0,251}[a-z0-9]$", var.namespace))
    error_message = "The 'name' variable must be a valid Kubernetes namespace name as per https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#dns-subdomain-names"
  }
}

variable "scope" {
  default     = "strict"
  description = <<-EOF
  Specifies the scope of the sealed secret  The module will add the appropriate scope annotation to the SealedSecret resource based on this variable.
  Must be one of 'strict', 'namespace-wide', or 'cluster-wide'.  The default is 'strict'."
  EOF
  nullable    = false
  type        = string
  validation {
    condition     = contains(["strict", "namespace-wide", "cluster-wide"], var.scope)
    error_message = "The 'scope' variable must be one of 'strict', 'namespace-wide', or 'cluster-wide'."
  }
}

variable "secret_metadata" {
  default     = {}
  description = "An optional object containing labels and/or annotations to apply to the generated Secret resource."
  nullable    = false
  type = object(
    {
      annotations = optional(map(string), {})
      labels      = optional(map(string), {})
    }
  )

  validation {
    condition     = alltrue([for k in keys(var.secret_metadata.annotations) : can(regex("^(?i)(([a-z0-9]/)|([a-z0-9][a-z0-9\\-.]{0,251}[a-z0-9])/)?(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))$", k))])
    error_message = "One or more annotation keys is syntactically invalid or null.  See https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/#syntax-and-character-set for details."
  }

  validation {
    condition     = alltrue([for v in values(var.secret_metadata.labels) : can(regex("^(?i)(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))?$", v))])
    error_message = "One or more label values is syntactically invalid or null.  See https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set for details."
  }

  validation {
    condition     = alltrue([for k in keys(var.secret_metadata.labels) : can(regex("^(?i)(([a-z0-9]/)|([a-z0-9][a-z0-9\\-.]{0,251}[a-z0-9])/)?(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))$", k))])
    error_message = "One or more label keys is syntactically invalid or null.  See https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set for details."
  }
}

variable "templated_secret_data" {
  default     = {}
  type        = map(string)
  description = <<-EOF
  A map containing additional plaintext values to include in the spec.template.data attribute of the generated Secret resource.  The values in the map support injection
  of secret values defined in the 'encrypted_data' variable.  To inject a value use the following Go template function.

  {{ index . "The key in the encrypted_data variable that maps to the secret value to inject.  It must be wrapped in double quotes" }}

  The primary use case is to store configuration files in the Generated secret without encrypting the entire configuration file.
  For more details, see https://github.com/bitnami-labs/sealed-secrets/tree/main/docs/examples/config-template
  EOF
  nullable    = false
}

variable "secret_type" {
  default     = "Opaque"
  description = "The secret type of the generated Secret resource.  Defaults to Opaque."
  type        = string
  nullable    = false
  validation {
    condition     = contains(["Opaque", "kubernetes.io/service-account-token", "kubernetes.io/dockercfg", "kubernetes.io/dockerconfigjson", "kubernetes.io/basic-auth", "kubernetes.io/ssh-auth", "kubernetes.io/tls"], var.secret_type)
    error_message = "The `secret_type` argument must be one of the built-in types.  https://kubernetes.io/docs/concepts/configuration/secret/#secret-types"
  }
}

variable "timeouts" {
  default     = {}
  description = "Configures the create, update, and delete timeouts (in seconds) on the SealedSecret's Terraform resource."
  nullable    = false
  type = object({
    create = optional(number, 30)
    delete = optional(number, 30)
    update = optional(number, 30)
  })

  validation {
    condition     = 0 < var.timeouts.create
    error_message = "The create timeout must be greater than zero."
  }

  validation {
    condition     = 0 < var.timeouts.delete
    error_message = "The delete timeout must be greater than zero."
  }

  validation {
    condition     = 0 < var.timeouts.update
    error_message = "The update timeout must be greater than zero."
  }
}
