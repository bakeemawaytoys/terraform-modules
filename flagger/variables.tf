variable "chart_version" {
  description = "The version of the Flagger Helm chart to deploy.  Must be 1.35.x where x is a positive integer."
  nullable    = false
  type        = string

  validation {
    condition     = can(regex("^1\\.35\\.[0-9]+$", var.chart_version))
    error_message = "The chart version must be 1.35.x where 'x' is a positive integer value."
  }
}

variable "cluster_name" {
  description = "The name of the EKS cluster in which Flagger is deployed by this module."
  nullable    = false
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

  validation {
    condition     = alltrue([for v in values(var.labels) : can(regex("^(?i)(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))?$", v))])
    error_message = "One or more label values is syntactically invalid or null.  See https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set for details."
  }

  validation {
    condition     = alltrue([for k in keys(var.labels) : can(regex("^(?i)(([a-z0-9]/)|([a-z0-9][a-z0-9\\-.]{0,251}[a-z0-9])/)?(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))$", k))])
    error_message = "One or more label keys is syntactically invalid or null.  See https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set for details."
  }
}

variable "log_level" {
  default     = "info"
  description = "Configures the level of the Flagger logger.  Must be one of `debug`, `info`, `warning`, or `error`."
  nullable    = false
  type        = string

  validation {
    condition     = contains(["debug", "info", "warning", "error"], var.log_level)
    error_message = "The log level must be one of `debug`, `info`, `warning`, or `error`."
  }
}

variable "namespace" {
  description = "The namespace where the controller will be installed.  It must already exist and must be the namespace that contains the nginx ingress controller(s)."
  nullable    = false
  type        = string

  validation {
    condition     = 0 < length(var.namespace) && length(var.namespace) < 64
    error_message = "The namespace variable must contain at least one character and at most 63 characters."
  }

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9\\-]*[a-z0-9])*$", var.namespace))
    error_message = "The namespace variable must be a syntactically valid Kubernetes namespace. https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/#namespaces-and-dns"
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
  description = "CPU and memory resource for the controller pods."
  nullable    = false
  type = object(
    {
      limits = optional(object(
        {
          cpu    = optional(string, "500m")
          memory = optional(string, "256Mi")
        }
        ),
      {})
      requests = optional(
        object(
          {
            cpu    = optional(string, "250m")
            memory = optional(string, "128Mi")
          }
        ),
      {})
    }
  )
}

variable "prometheus_rule" {
  default     = {}
  description = "An object whose attributes enable and configure a PromtheusRule Kubernetes resource to monitor Flagger's metrics."
  nullable    = false
  type = object({
    enabled                   = optional(bool, true)
    interval                  = optional(string, "30s")
    canary_rollback_serverity = optional(string, "critical")
  })
}

variable "prometheus_url" {
  description = "The URL of the Prometheus instance containing the metrics to analyze during deployments."
  nullable    = false
  type        = string
}

variable "replica_count" {
  default     = 2
  description = "The number of controller pods to run."
  nullable    = false
  type        = number
  validation {
    condition     = 0 <= var.replica_count
    error_message = "The replica count must be greater than or equal to zero."
  }
}

variable "service_monitor" {
  default     = {}
  description = "Controls deployment and configuration of a ServiceMonitor custom resource to enable Prometheus metrics scraping.  The kube-prometheus-stack CRDs must be available in the k8s cluster if  `enabled` is set to `true`."
  nullable    = false
  type = object({
    enabled      = optional(bool, true)
    honor_labels = optional(bool, false)
  })
}
