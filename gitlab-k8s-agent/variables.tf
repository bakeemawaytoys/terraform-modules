variable "agent_name" {
  description = "The name of the agent as it appears in the Gitlab UI.  Corresponds to the name of the directory in the project's repository under the path .gitlab/agents that was used to generate the access token."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.\\-]{0,61}[a-z0-9]$", var.agent_name))
    error_message = "The 'agent_name' value must meet the agent naming requirements described at https://docs.gitlab.com/ee/user/clusters/agent/install/#create-an-agent-configuration-file."
  }
}

variable "chart_version" {
  description = "The version of the agent's Helm chart to use for the release. Supported versions are 1.20.x and 1.21.x"
  type        = string
  validation {
    condition     = can(regex("^1\\.2[0-1]\\.\\d+$", var.chart_version))
    error_message = "The 'chart_version' variable must be a semantic version string between 1.20.x and 1.21.x."
  }
}

variable "gitlab_hostname" {
  default     = "gitlab.com"
  description = "The hostname of the Gitlab instance the agent will connect to."
  nullable    = false
  type        = string
  validation {
    condition     = 0 < length(trimspace(var.gitlab_hostname))
    error_message = "The 'gitlab_hostname' variable cannot be empty."
  }
}

variable "labels" {
  default     = {}
  description = "An optional map of kubernetes labels to attach to every resource created by the module."
  nullable    = false
  type        = map(string)
}

variable "namespace" {
  default     = "gitlab-agent"
  description = "The existing namespace where the agent will be deployed."
  nullable    = false
  type        = string
  validation {
    condition     = 0 < length(trimspace(var.namespace))
    error_message = "The 'namespace' variable cannot be empty."
  }
}


variable "node_selector" {
  default     = {}
  description = "An optional map of node labels to use the node selector of all pods."
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

variable "node_tolerations" {
  default     = []
  description = <<-EOF
  An optional list of objects to set node tolerations on all pods.  The object structure corresponds to the structure of the
  toleration syntax in the Kubernetes pod spec.

  https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/
  EOF
  nullable    = false
  type = list(object(
    {
      key      = string
      operator = string
      value    = optional(string)
      effect   = string
    }
  ))

  validation {
    condition     = alltrue([for t in var.node_tolerations : contains(["NoExecute", "NoSchedule", "PreferNoSchedule", ""], t.effect)])
    error_message = "The toleration effects must be one of NoExecute, NoSchedule, PreferNoSchedule, or an empty string."
  }

  validation {
    condition     = alltrue([for t in var.node_tolerations : contains(["Equal", "Exists"], t.operator)])
    error_message = "The toleration operators must be either Equal or Exists."
  }

  validation {
    condition     = alltrue([for t in var.node_tolerations : t.value == null if t.operator == "Exists"])
    error_message = "The toleration value must be null if the operator is set to Exists."
  }

  validation {
    condition     = alltrue([for t in var.node_tolerations : can(regex("^(?i)(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))?$", t.value)) if t.operator == "Equal"])
    error_message = "If the operator is set to Equal, the toleration value cannot be null and must be a syntactically valid Kubernetes label value.  See https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set for details."
  }

  validation {
    condition     = alltrue([for t in var.node_tolerations : can(regex("^(?i)(([a-z0-9]/)|([a-z0-9][a-z0-9\\-.]{0,251}[a-z0-9])/)?(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))$", t.key))])
    error_message = "Toleration keys cannot be null and must be syntactically valid Kubernetes label keys.  See https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set for details."
  }

}

variable "pod_resources" {
  default     = {}
  description = "CPU and memory settings for the pods."
  nullable    = false
  type = object(
    {
      limits = optional(object(
        {
          cpu    = optional(string, "200m")
          memory = optional(string, "256Mi")
        }
        ),
      {})
      requests = optional(
        object(
          {
            cpu    = optional(string, "100m")
            memory = optional(string, "128Mi")
          }
        ),
      {})
    }
  )
}

variable "project_id" {
  description = "The unique numeric identifier of the Gitlab project that was used to generate the access token."
  type        = number
  nullable    = false
  validation {
    condition     = 0 < var.project_id
    error_message = "The 'project_id' variable must be greater than zero."
  }
}

variable "sealed_access_token" {
  description = <<-EOF
  The access token the agent uses to register with Gitlab.  Must be sealed with the Bitnami Sealed Secrets
  controller using the kubeseal tool in raw mode.  The name of the secret is the value of the 'name' variable
  and the namespace of the secert is the value of the 'namespace' variable.
  EOF
  type        = string
}
