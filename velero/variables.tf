variable "access_logging" {
  default     = {}
  description = <<-EOF
  An object whose attributes configures the generation and destination of the S3 access logs.

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

variable "aws_plugin_version" {
  default     = "1.7.1"
  description = <<-EOF
  The version of Velero's AWS plugin to use.  Restricted to the version 1.7.x for Velero 1.11.x and version 1.8 for Velero 1.12.
  Valid values are listed at https://github.com/vmware-tanzu/velero-plugin-for-aws/releases.
  EOF
  nullable    = false
  type        = string
  validation {
    condition     = can(regex("^1\\.[78]\\.[0-9]+$", var.aws_plugin_version))
    error_message = "The 'aws_plugin_version' must be 1.7.x where 'x' is a positive integer."
  }
}

variable "chart_version" {
  description = <<-EOF
  The version of the 'velero' Helm chart to use.  Restricted to the versions 4.4.x for Velero 1.11.x and 5.1.x for Velero 1.12.
  See https://github.com/vmware-tanzu/helm-charts for the list of valid versions.
  EOF
  nullable    = false
  type        = string
  validation {
    condition     = can(regex("^4\\.4\\.[0-9]+$", var.chart_version)) || can(regex("^5\\.1\\.[0-9]+$", var.chart_version))
    error_message = "The 'chart_version' variable must be 4.4.x where 'x' is a positive integer."
  }
}


variable "eks_cluster" {
  description = <<-EOF
  Attributes of the EKS cluster on which the controller is deployed.  The names of the attributes match the names of outputs in the eks-cluster module to allow using the module as the argument to this variable.

  The `cluster_name` attribute the the name of the EKS cluster.  It is required.
  The `service_account_oidc_audience_variable` attribute is the ID of the cluster's IAM OIDC identity provider with the string ":aud" appended to it.  It is required.
  The `service_account_oidc_subject_variable` attribute is the ID of the cluster's IAM OIDC identity provider with the string ":sub" appended to it.  It is required.
  The 'service_account_oidc_provider_arn' attribute is the ARN of the cluster's IAM OIDC identity provider.  It is required.
  EOF
  nullable    = false
  type = object({
    cluster_name                           = string
    service_account_oidc_audience_variable = string
    service_account_oidc_subject_variable  = string
    service_account_oidc_provider_arn      = string
  })

  validation {
    # The naming constraints are defined at https://docs.aws.amazon.com/eks/latest/APIReference/API_CreateCluster.html#API_CreateCluster_RequestBody
    condition     = can(regex("^[0-9A-Za-z][A-Za-z0-9\\-_]{0,99}$", var.eks_cluster.cluster_name))
    error_message = "The cluster name must adhere to the EKS cluster name restrictions."
  }

  validation {
    condition     = endswith(var.eks_cluster.service_account_oidc_audience_variable, ":aud")
    error_message = "The service_account_oidc_audience_variable attribute must have the ':aud' suffix."
  }

  validation {
    condition     = endswith(var.eks_cluster.service_account_oidc_subject_variable, ":sub")
    error_message = "The service_account_oidc_subject_variable attribute must have the ':sub' suffix."
  }

  validation {
    condition     = var.eks_cluster.service_account_oidc_provider_arn != null
    error_message = "The service_account_oidc_provider_arn attribute cannot be null."
  }
}

variable "create_namespace" {
  description = "Set to true to have the module create the namespace.  Set to false if it already exists."
  nullable    = false
  type        = bool
}

variable "custom_bucket_name" {
  default     = ""
  description = "Optionally use a custom bucket name instead of the generated bucket name."
  type        = string
}

variable "enable_goldilocks" {
  default     = true
  description = <<-EOF
  Determines if Goldilocks monitors the namespace to give recommendations on tuning pod resource requests and limits.
  https://goldilocks.docs.fairwinds.com/installation/#enable-namespace
  EOF
  nullable    = false
  type        = bool
}


variable "enable_prometheus_rules" {
  default     = true
  description = "Set to true to deploy a PrometheusRule resource to generate alerts based on the metrics scraped by Prometheus."
  nullable    = false
  type        = bool
}

variable "enable_service_monitor" {
  default     = true
  description = "Controls installation of a ServiceMonitor resource to enable metrics scraping when the Prometheus Operator is installed in the cluster."
  nullable    = false
  type        = bool
}

variable "grafana_dashboard_config" {
  default     = null
  description = <<-EOF
  Configures the optional deployment of Grafana dashboards in configmaps.  Set the value to null to disable dashboard installation.  The dashboards will be added to the "Cert-Manager" folder in the Grafana UI.

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
  description = "Configures the log verbosity.  Must be one of panic, debug, info, warning, error, or fatal."
  nullable    = false
  type        = string
  validation {
    condition     = contains(["panic", "debug", "info", "warning", "error", "fatal"], var.log_level)
    error_message = "The log level must be one of panic, debug, info, warning, error, or fatal."
  }
}

variable "namespace" {
  default     = "velero"
  description = "The namespace where Velero's resources, including its Helm chart, will be installed."
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
  description = "An optional map of node labels to use the node selector of the Velero pods."
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
  An optional list of objects to set node tolerations on the Velero pods.  The object structure corresponds to the structure of the
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

variable "pod_security_standards" {
  default     = {}
  description = <<-EOF
  Configures the levels of the pod security admission modes.  Defaults to enforcing the restricted standard.

  https://kubernetes.io/docs/concepts/security/pod-security-admission/
  https://kubernetes.io/docs/tasks/configure-pod-container/enforce-standards-namespace-labels/
  https://kubernetes.io/docs/concepts/security/pod-security-standards/
  EOF
  nullable    = false
  type = object({
    audit   = optional(string, "restricted")
    enforce = optional(string, "restricted")
    warn    = optional(string, "restricted")
  })

  validation {
    condition     = alltrue([for v in values(var.pod_security_standards) : contains(["baseline", "privileged", "restricted"], v)])
    error_message = "One or more pod security standard levels are invalid.  Valid levels are baseline, privileged, or restricted."
  }
}

variable "pod_resources" {
  default     = {}
  description = "CPU and memory settings for the controller pods.  The default values match the default values of the Helm chart"
  nullable    = false
  type = object(
    {
      limits = optional(
        object(
          {
            cpu    = optional(string, "1000m")
            memory = optional(string, "512Mi")
          }
        ),
      {})
      requests = optional(
        object(
          {
            cpu    = optional(string, "500m")
            memory = optional(string, "128Mi")
          }
        ),
      {})
    }
  )
}

variable "release_name" {
  default     = "velero"
  description = "The name to give to the Helm release."
  nullable    = false
  type        = string
  validation {
    condition     = length(trimspace(var.release_name)) > 0
    error_message = "The 'release_name' variable cannot be empty."
  }
}

variable "schedules" {
  default = {
    default-scheduled-backup = {
      template = {
        includedNamespaces = ["*"]
        excludedNamespaces = [
          "default",
          "kube-system",
          "kube-public",
          "kube-node-lease",
          "velero",
        ]
        excludedResources = ["storageclasses.storage.k8s.io"]
      }
    }
  }
  description = <<-EOF
  An optional collection of backup schedules that will be managed by Helm.  Only a subset of the template
  attributes are allowed to be set to ensure valid schedule objects are created.
  For more details on the template attributes see https://velero.io/docs/v1.9/api-types/backup/.
  EOF
  nullable    = false
  type = map(
    object(
      {
        annotations = optional(map(string), {})
        disabled    = optional(bool, false)
        labels      = optional(map(string), {})
        schedule    = optional(string, "00 11 * * *")
        template = optional(
          object(
            {
              includedNamespaces      = optional(list(string), ["*"])
              excludedNamespaces      = optional(list(string), [])
              includedResources       = optional(list(string), ["*"])
              excludedResources       = optional(list(string), [])
              includeClusterResources = optional(bool)
            }
          ),
        {})
        useOwnerReferencesInBackup = optional(bool, false)
      }
    )
  )
}

variable "service_account_name" {
  default     = "velero"
  description = "The name to give to the k8s service account created for Velero."
  nullable    = false
  type        = string
  validation {
    condition     = length(trimspace(var.service_account_name)) > 0
    error_message = "The 'service_account_name' variable cannot be empty."
  }
}

variable "tags" {
  default     = {}
  description = "An optional map of AWS tags to attach to every resource created by the module."
  nullable    = false
  type        = map(string)
}

variable "velero_image_registry" {
  default     = "docker.io"
  description = <<-EOF
  The container image registry from which the velero and velero-plugin-for-aws images will be pulled.  The images must be in the velero/velero and velero/velero-plugin-for-aws repositories, respectively.
  The value can have an optional path suffix to support the use of ECR pull-through caches.
  EOF
  nullable    = false
  type        = string
  validation {
    condition     = can(regex("^([a-z0-9\\-]+\\.)*[a-z0-9\\-]+(/[a-z0-9\\-._]+)?$", var.velero_image_registry))
    error_message = "The 'velero_image_registry' variable is not a syntactically valid container registry name."
  }
}
