variable "chart_version" {
  description = "The Metrics Server Helm chart version to use.  Supported versions are 3.8.x, 3.9.x, and 3.10.x.  See https://github.com/kubernetes-sigs/metrics-server/releases for the list of available versions."
  nullable    = false
  type        = string

  validation {
    condition     = can(regex("^3\\.8|9|(10)\\.\\d+$", var.chart_version))
    error_message = "The chart_version must be 3.8.x, 3.9,x or 3.10.x where 'x' is an integer greater than or equal to zero."
  }
}

variable "enable_service_monitor" {
  default     = true
  description = "Set to true to deploy a ServiceMonitor resource for scraping Prometheus Karpenter metrics."
  nullable    = false
  type        = bool
}

variable "image_registry" {
  default     = "registry.k8s.io"
  description = <<-EOF
  The container image registry from which the images will be pulled.  The images must be in the metrics-server/metrics-server repository.  Defaults to the registry.k8s.io.
  The value can have an optional path suffix to support the use of ECR pull-through caches.
  EOF
  nullable    = false
  type        = string
  validation {
    condition     = can(regex("^([a-z0-9\\-]+\\.)*[a-z0-9\\-]+(/[a-z0-9\\-._]+)?$", var.image_registry))
    error_message = "The image registry is not a syntactically valid container registry name."
  }
}

variable "labels" {
  default     = {}
  description = "An optional map of kubernetes labels to attach to every resource created by the module."
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

variable "node_selector" {
  default     = {}
  description = "An optional map of node labels to use the node selector of the pods."
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
  An optional list of objects to set node tolerations on the pods.  The object structure corresponds to the structure of the
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
      limits = optional(
        object(
          {
            cpu    = optional(string, "100m")
            memory = optional(string, "256Mi")
          }
        ),
      {})
      requests = optional(
        object(
          {
            cpu    = optional(string, "100m")
            memory = optional(string, "256Mi")
          }
        ),
      {})
    }
  )
}

variable "replicas" {
  default     = 2
  type        = number
  description = "The number of pods to run.  Must be greater than or equal to two."
  nullable    = false
  validation {
    condition     = 2 <= var.replicas
    error_message = "The value of the 'replicas' variable must be an integer greater than two."
  }
}
