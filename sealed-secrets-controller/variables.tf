variable "chart_version" {
  description = "The version of the 'sealed-secrets' Helm chart to use.  Support versions are 2.13.x.  See https://github.com/bitnami-labs/sealed-secrets/releases for the list of valid versions."
  nullable    = false
  type        = string
  validation {
    condition     = can(regex("^2\\.13\\.\\d+$", var.chart_version))
    error_message = "The chart_version must be 2.13.x where x is any positive integer."
  }
}

variable "enable_prometheus_rules" {
  default     = true
  description = "Set to true to deploy a PrometheusRule resource to generate alerts based on the metrics scraped by Prometheus."
  nullable    = false
  type        = bool
}

variable "grafana_dashboard_config" {
  default     = null
  description = <<-EOF
  Configures the optional deployment of Grafana dashboards in configmaps.  Set the value to null to disable dashboard installation.  The dashboards will be added to the "General" folder in the Grafana UI.

  The 'folder_annotation_key' attribute is the Kubernets annotation that configures the Grafana folder into which the dasboards will appear in the Grafana UI.  It cannot be null or empty.
  The 'label' attribute is a single element map containing the label the Grafana sidecar uses to discover configmaps containing dashboards.  It cannot be null or empty.
  The 'namespace' attribute is the namespace where the configmaps are deployed.  It cannot be null or empty.

  * https://github.com/grafana/helm-charts/tree/main/charts/grafana#sidecar-for-dashboards
  EOF
  nullable    = true
  type = object(
    {
      folder_annotation_key = string
      label                 = map(string)
      namespace             = string
    }
  )

  validation {
    condition     = var.grafana_dashboard_config == null || can(regex("^(?i)(([a-z0-9]/)|([a-z0-9][a-z0-9\\-.]{0,251}[a-z0-9])/)?(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))$", var.grafana_dashboard_config.folder_annotation_key))
    error_message = "The folder annotation key is syntactically invalid or null.  See https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/#syntax-and-character-set for details."
  }

  validation {
    condition     = try(length(var.grafana_dashboard_config.label) == 1, var.grafana_dashboard_config == null)
    error_message = "The 'label' attribute must not be null and must contain exactly one entry."
  }

  validation {
    condition     = try(alltrue([for v in values(var.grafana_dashboard_config.label) : can(regex("^(?i)(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))?$", v))]), var.grafana_dashboard_config == null)
    error_message = "One or more 'label' attribute values is syntactically invalid or null.  See https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set for details."
  }


  validation {
    condition     = try(alltrue([for k in keys(var.grafana_dashboard_config.label) : can(regex("^(?i)(([a-z0-9]/)|([a-z0-9][a-z0-9\\-.]{0,251}[a-z0-9])/)?(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))$", k))]), var.grafana_dashboard_config == null)
    error_message = "One or more 'label' attribute keys is syntactically invalid or null.  See https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set for details."
  }

  validation {
    condition     = try((0 < length(var.grafana_dashboard_config.namespace) && length(var.grafana_dashboard_config.namespace) < 64), var.grafana_dashboard_config == null)
    error_message = "The 'namespace' attribute must contain at least one character and at most 63 characters."
  }

  validation {
    condition     = var.grafana_dashboard_config == null || can(regex("^[a-z0-9]([a-z0-9\\-]*[a-z0-9])*$", var.grafana_dashboard_config.namespace))
    error_message = "The 'namespace' attribute must be a syntactically valid Kubernetes namespace. https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/#namespaces-and-dns"
  }
}

variable "image_registry" {
  default     = "docker.io"
  description = "The hostname of the image registry (or registry proxy) containing the controller's image.  The image must be in the 'bitnami/sealed-secrets-controller' repository."
  nullable    = false
  type        = string
  validation {
    condition     = can(regex("^([a-z0-9\\-]+\\.)*[a-z0-9\\-]+$", var.image_registry))
    error_message = "The 'image_registry' variable must be syntactically valid hostname."
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

variable "namespace" {
  description = "The namespace where the controller will be installed.  It must already exist."
  default     = "kube-system"
  nullable    = false
  type        = string
  validation {
    condition     = length(trimspace(var.namespace)) > 0
    error_message = "The 'namespace' variable cannot be empty."
  }
}

variable "node_selector" {
  default     = {}
  description = <<-EOF
  An optional map of Kubernetes labels to use as the controller pod's node selectors.
  EOF
  nullable    = false
  type        = map(string)

  validation {
    condition     = alltrue([for v in values(var.node_selector) : can(regex("^(?i)(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))?$", v))])
    error_message = "One or more node selector values is syntactically invalid or null.  See https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set for details."
  }

  validation {
    condition     = alltrue([for k in keys(var.node_selector) : can(regex("^(?i)(([a-z0-9]/)|([a-z0-9][a-z0-9\\-.]{0,251}[a-z0-9])/)?(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))$", k))])
    error_message = "One or more node selector keys is syntactically invalid or null.  See https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set for details."
  }
}

variable "node_tolerations" {
  default     = []
  description = <<-EOF
  An optional list of objects to set node tolerations on the controller pod.  The object structure corresponds to the structure of the
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
  description = "CPU and memory settings for the controller pods.  Defaults to the same values as the Helm chart's default values."
  nullable    = false
  type = object(
    {
      limits = optional(
        object(
          {
            cpu    = optional(string, "100m")
            memory = optional(string, "128Mi")
          }
        ),
      {})
      requests = optional(
        object(
          {
            cpu    = optional(string, "50m")
            memory = optional(string, "64Mi")
          }
        ),
      {})
    }
  )
}

variable "release_name" {
  default     = "sealed-secrets-controller"
  description = "The name to give to the Helm release."
  nullable    = false
  type        = string
  validation {
    condition     = length(trimspace(var.release_name)) > 0
    error_message = "The 'release_name' variable cannot be empty."
  }
}

variable "service_monitor" {
  default     = {}
  description = "Controls deployment and configuration of a ServiceMonitor custom resource to enable Prometheus metrics scraping.  The kube-prometheus-stack CRDs must be available in the k8s cluster if  `enabled` is set to `true`."
  nullable    = false
  type = object({
    enabled         = optional(bool, true)
    scrape_interval = optional(string, "30s")
  })

  validation {
    condition     = can(regex("^[1-9][0-9]*[hms]$", var.service_monitor.scrape_interval))
    error_message = "The service monitor scrape interval must be a non-zero duration string whose unit is h, m, or s.  https://prometheus-operator.dev/docs/operator/api/#monitoring.coreos.com/v1.Duration"
  }
}
