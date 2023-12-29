variable "addon_version" {
  description = "The version of the EBS CNI driver add-on to use.  Can be set to 'default', 'latest', or pinned to a specific version."
  default     = "default"
  nullable    = false
  type        = string
  validation {
    condition     = contains(["default", "latest"], var.addon_version) || can(regex("^v\\d+\\.\\d+\\.\\d+-eksbuild\\.\\d+$", var.addon_version))
    error_message = "The 'addon_version' variable must be 'default', 'latest', or a specific version."
  }
}

variable "cluster_name" {
  description = "The name of the target EKS cluster."
  type        = string
  validation {
    # The naming constraints are defined at https://docs.aws.amazon.com/eks/latest/APIReference/API_CreateCluster.html#API_CreateCluster_RequestBody
    condition     = can(regex("^[0-9A-Za-z][A-Za-z0-9\\-_]{0,99}$", var.cluster_name))
    error_message = "The cluster name must adhere to the EKS cluster name restrictions."
  }
}

variable "labels" {
  default     = {}
  description = "An optional map of kubernetes labels to attach to every resource created by the module."
  nullable    = false
  type        = map(string)
}

variable "node_selector" {
  default     = {}
  description = "An optional map of node labels to use the node selector of controller pods."
  type        = map(string)
  nullable    = false

  validation {
    condition     = alltrue([for v in values(var.node_selector) : can(regex("^(?i)(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))?$", v))])
    error_message = "One or more node selector values is syntactically invalid or null.  See https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/ for details."
  }

  validation {
    condition     = alltrue([for k in keys(var.node_selector) : can(regex("^(?i)(([a-z0-9]/)|([a-z0-9][a-z0-9\\-.]{0,251}[a-z0-9])/)?(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))$", k))])
    error_message = "One or more node selector keys is syntactically invalid or null.  See https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/ for details."
  }
}

variable "preserve_on_delete" {
  description = "Indicates if you want to preserve the created resources when deleting the EKS add-on."
  default     = false
  nullable    = false
  type        = bool
}

variable "resolve_conflicts" {
  description = "Define how to resolve parameter value conflicts when applying version updates to the add-on."
  default     = "OVERWRITE"
  nullable    = false
  type        = string
  validation {
    condition     = contains(["NONE", "OVERWRITE"], var.resolve_conflicts)
    error_message = "The 'resolve_conflicts' variable must be either 'OVERWRITE' or 'NONE'."
  }
}

variable "service_account_oidc_provider_arn" {
  description = "The ARN of the IAM OIDC provider associated with the target EKS cluster."
  nullable    = false
  type        = string
  validation {
    condition     = length(trimspace(var.service_account_oidc_provider_arn)) > 0
    error_message = "The 'service_account_oidc_provider_arn' variable cannot be empty."
  }
}

variable "tags" {
  default     = {}
  description = "An optional map of AWS tags to attach to every resource created by the module."
  nullable    = false
  type        = map(string)
}

variable "volume_encryption_key" {
  default     = null
  description = "An KMS CMK alias, ARN, or  key ID of that will be used to encrypt volumes.  Permission to use the key will be granted to the driver's IAM role."
  nullable    = true
  type        = string
}
