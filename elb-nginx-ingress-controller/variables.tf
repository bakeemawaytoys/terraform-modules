variable "access_logging" {
  default     = {}
  description = <<-EOF
  An object whose attributes configures the generation and destination of the ELB access logs.

  The `enabled` attribute determines if access logs are generated for this bucket.  Defaults to false.
  The `bucket` attribute is the name of the S3 bucket where the access logs will be written.  It cannot be empty if `enabled` is set to true.
  The `prefix` attribute configures a a string to prepend to the key of every access log object created.  It is optional.
  EOF
  nullable    = false
  type = object({
    enabled = optional(bool, false)
    bucket  = optional(string)
    prefix  = optional(string, "")
  })

  validation {
    condition     = !startswith(var.access_logging.prefix, "/")
    error_message = "The prefix cannot start with a '/' character."
  }

  validation {
    condition     = var.access_logging.prefix == "" || endswith(var.access_logging.prefix, "/")
    error_message = "The prefix must end with a '/' character."
  }
}


variable "allow_snippet_annotations" {
  default     = false
  description = "Set to true to allow ingress resources to set the `nginx.ingress.kubernetes.io/configuration-snippet` annotation.  Defaults to false."
  nullable    = false
  type        = bool
}

variable "chart_version" {
  description = "The version of the 'ingress-nginx' Helm chart to use.  Must be in either the 4.7.x, 4.8.x, or 4.9.x releases.  See https://github.com/kubernetes/ingress-nginx/releases for the list of valid versions."
  nullable    = false
  type        = string
  validation {
    condition     = can(regex("^4\\.[7-9]+\\.[0-9]+$", var.chart_version))
    error_message = "The chart version must be 4.7.x, 4.8.x, 4.9.x where 'x' is a positive integer value."
  }
}

variable "controller_pod_resources" {
  default     = {}
  description = "CPU and memory settings for the controller pods.  Defaults to the same values as the Helm chart's default values."
  nullable    = false
  type = object(
    {
      limits = optional(object(
        {
          cpu    = optional(string, "200m")
          memory = optional(string, "180Mi")
        }
        ),
      {})
      requests = optional(
        object(
          {
            cpu    = optional(string, "100m")
            memory = optional(string, "90Mi")
          }
        ),
      {})
    }
  )
}

variable "controller_replica_count" {
  default     = 2
  description = "The number of controller pods to run."
  nullable    = false
  type        = number

  validation {
    condition     = 0 < var.controller_replica_count
    error_message = "The 'controller_replica_count' variable must be greater than or equal to one."
  }

}

variable "default_ssl_certificate_name" {
  description = "The name (without the namespace) of the Kubernetes secret containing the TLS certificate to use by default.  Must be in the namespace specified in the 'namespace' variable."
  nullable    = false
  type        = string
  validation {
    condition     = length(trimspace(var.default_ssl_certificate_name)) > 0
    error_message = "The 'default_ssl_certificate_name' variable cannot be empty."
  }
}

variable "enable_admission_webhook" {
  default     = true
  description = "Enables deployment of the ingress controller's validating webhook."
  nullable    = false
  type        = bool
}

variable "image_registry" {
  default     = "registry.k8s.io"
  description = <<-EOF
  The container image registry from which the controller images will be pulled.  The images must be in the `ingress-nginx/controller` repository.
  The value can have an optional path suffix to support the use of ECR pull-through caches.
  EOF
  nullable    = false
  type        = string
  validation {
    condition     = can(regex("^([a-z0-9\\-]+\\.)*[a-z0-9\\-]+(/[a-z0-9\\-._]+)?$", var.image_registry))
    error_message = "The image registry is not a syntactically valid container registry name."
  }
}

variable "ingress_class_resource" {
  default     = {}
  description = "Configures the attributes of the ingress class resource created by the Helm chart.  Note that unlike the Helm chart, the ingress class will be set as the default class."
  nullable    = false
  type = object(
    {
      name    = optional(string, "nginx")
      default = optional(bool, true)
    }
  )
}

variable "grafana_dashboard_config" {
  default     = null
  description = <<-EOF
  Configures the optional deployment of Grafana dashboards in configmaps.  Set the value to null to disable dashboard installation.  The dashboards will be added to the "Nginx Ingress" folder in the Grafana UI.

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

variable "internal" {
  default     = false
  description = "Set to true if the ingress traffic originates inside the AWS network or false if it originates from the Internet."
  type        = bool
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

variable "nginx_custom_configuration" {
  default     = {}
  description = "Custom Nginx configuration options.  See https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/ for the full list of available options."
  type        = map(any)
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

variable "priority_class_name" {
  default     = "system-cluster-critical"
  description = "The k8s priority class to assign to the controller pods.  Defaults to system-cluster-critical.  Set to an empty string to use the cluster default priority."
  nullable    = false
  type        = string

  validation {
    condition     = length(var.priority_class_name) < 253
    error_message = "The priority_class_name variable must be at most 253 characters."
  }

  validation {
    condition     = var.priority_class_name == "" || can(regex("^[a-z0-9]([a-z0-9\\-]*[a-z0-9])*$", var.priority_class_name))
    error_message = "The priority_class_name variable must be null or a syntactically valid Kubernetes object name. https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#dns-subdomain-names"
  }
}

variable "release_name" {
  default     = "nginx"
  description = "The name to give to the Helm release."
  nullable    = false
  type        = string
  validation {
    condition     = length(trimspace(var.release_name)) > 0
    error_message = "The 'release_name' variable cannot be empty."
  }
}

variable "namespace" {
  default     = "kube-system"
  description = "The namespace where the controller will be installed.  It must already exist."
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

variable "tags" {
  default     = {}
  description = "An optional map of AWS tags to attach to every resource created by the module."
  nullable    = false
  type        = map(string)
}

variable "watch_ingress_without_class" {
  default     = false
  description = "Set to true to process Ingress objects without ingressClass annotation/ingressClassName field, false to ignore them."
  nullable    = false
  type        = bool
}
