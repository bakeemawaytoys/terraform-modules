variable "alertmanager_pod_configuration" {
  default     = {}
  description = <<-EOF
  An object whose attributes configure the image registry, persistent volume size (in gigabytes), node selector, tolerations, resource requests and resource limits for
  the Alertmanager pods.  The image is pulled from the registry specified in the `image_registry` attribute.  It must be in the 'prometheus/alertmanager' repository.
  The value can have an optional path suffix to support the use of ECR pull-through caches.
  EOF
  nullable    = false
  type = object({
    image_registry = optional(string, "quay.io")
    node_selector  = optional(map(string), {})
    node_tolerations = optional(
      list(
        object(
          {
            key      = string
            operator = string
            value    = optional(string)
            effect   = string
          }
        )
      ),
    [])
    resources = optional(
      object({
        limits = optional(
          object({
            cpu    = optional(string, "250m")
            memory = optional(string, "256Mi")
          }),
        {})
        requests = optional(
          object({
            cpu    = optional(string, "250m")
            memory = optional(string, "256Mi")
          }),
        {})
      }),
    {})
    volume_size = optional(number, 10)
  })

  validation {
    condition     = can(regex("^([a-z0-9\\-]+\\.)*[a-z0-9\\-]+(/[a-z0-9\\-._]+)?$", var.alertmanager_pod_configuration.image_registry))
    error_message = "The image registry is not a syntactically valid container registry name."
  }

  validation {
    condition     = alltrue([for v in values(var.alertmanager_pod_configuration.node_selector) : can(regex("^(?i)(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))?$", v))])
    error_message = "One or more node selector values is syntactically invalid or null.  See https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/ for details."
  }

  validation {
    condition     = alltrue([for k in keys(var.alertmanager_pod_configuration.node_selector) : can(regex("^(?i)(([a-z0-9]/)|([a-z0-9][a-z0-9\\-.]{0,251}[a-z0-9])/)?(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))$", k))])
    error_message = "One or more node selector keys is syntactically invalid or null.  See https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/ for details."
  }


  validation {
    condition     = alltrue([for t in var.alertmanager_pod_configuration.node_tolerations : contains(["NoExecute", "NoSchedule", "PreferNoSchedule", ""], t.effect)])
    error_message = "The toleration effects must be one of NoExecute, NoSchedule, PreferNoSchedule, or an empty string."
  }

  validation {
    condition     = alltrue([for t in var.alertmanager_pod_configuration.node_tolerations : contains(["Equal", "Exists"], t.operator)])
    error_message = "The toleration operators must be either Equal or Exists."
  }

  validation {
    condition     = alltrue([for t in var.alertmanager_pod_configuration.node_tolerations : t.value == null if t.operator == "Exists"])
    error_message = "The toleration value must be null if the operator is set to Exists."
  }

  validation {
    condition     = alltrue([for t in var.alertmanager_pod_configuration.node_tolerations : can(regex("^(?i)(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))?$", t.value)) if t.operator == "Equal"])
    error_message = "If the operator is set to Equal, the toleration value cannot be null and must be a syntactically valid Kubernetes label value.  See https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set for details."
  }

  validation {
    condition     = alltrue([for t in var.alertmanager_pod_configuration.node_tolerations : can(regex("^(?i)(([a-z0-9]/)|([a-z0-9][a-z0-9\\-.]{0,251}[a-z0-9])/)?(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))$", t.key))])
    error_message = "Toleration keys cannot be null and must be syntactically valid Kubernetes label keys.  See https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set for details."
  }
  validation {
    condition     = 1 <= var.alertmanager_pod_configuration.volume_size && var.alertmanager_pod_configuration.volume_size <= 16384
    error_message = "Invalid volume size.  See: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-volume-types.html#solid-state-drives for valid values."

  }
}

variable "alertmanager_slack_vault_kv_secret" {
  description = "The path to the Vault k/v secret containing the Slack API URL to use for sending alerts."
  nullable    = false
  type = object(
    {
      path              = string
      slack_api_url_key = optional(string, "alertmanager_slack_api_url")
      slack_channel     = string
    }
  )

  validation {
    condition     = startswith(var.alertmanager_slack_vault_kv_secret.slack_channel, "#")
    error_message = "The Slack channel must start with a '#' character."
  }

  validation {
    condition     = startswith(var.alertmanager_slack_vault_kv_secret.path, "secret/")
    error_message = "The 'path' attribute must start with 'secret/'."
  }

  validation {
    condition     = !endswith(var.alertmanager_slack_vault_kv_secret.path, "/")
    error_message = "The 'path' attribute must not end with a '/' character."
  }
}


variable "chart_version" {
  description = "The version of the kube-prometheus-stack chart to deploy.  It must be one of the 51.x, 52.x, 53.x, 54.x, or 55.x releases."
  nullable    = false
  type        = string
  validation {
    condition     = can(regex("^5[1-5]\\.\\d+\\.\\d+$", var.chart_version))
    error_message = "The chart version must be x.y.z where x is in the range 51 through 55, inclusive, and x and y are positive integers."
  }
}

variable "namespace" {
  description = "The name of the namespace where all module's Kubernetes resources, including the Helm release, are deployed."
  nullable    = false
  type        = string
}

variable "cluster_cert_issuer_name" {
  default     = "letsencrypt-prod"
  description = "The value to use for the'cert-manager.io/cluster-issuer' annotation on every Kubernetes ingress resource."
  nullable    = false
  type        = string
}

variable "grafana_admin_user_vault_kv_secret" {

  description = <<-EOF
  The Vault K/V secret used to construct the VaultSecret Kubernetes resource containing the default Grafana admin account.
  The default admin account should only be used for emergencies when LDAP authentication is not an option.
  EOF
  nullable    = false
  type = object(
    {
      path         = string
      username_key = optional(string, "ADMIN_USER")
      password_key = optional(string, "ADMIN_PASS")
    }
  )

  validation {
    condition     = startswith(var.grafana_admin_user_vault_kv_secret.path, "secret/")
    error_message = "The 'path' attribute must start with 'secret/'."
  }

  validation {
    condition     = !endswith(var.grafana_admin_user_vault_kv_secret.path, "/")
    error_message = "The 'path' attribute must not end with a '/' character."
  }
}

variable "grafana_ldap_config_vault_kv_secret" {
  description = <<-EOF
  The path to the Vault k/v secret containing the LDAP settings to use for configuring Grafana's authentication settings.
  For details on the LDAP configuration file see https://grafana.com/docs/grafana/v8.4/auth/ldap/
  EOF
  nullable    = false
  type = object(
    {
      path     = string
      toml_key = string
    }
  )

}

variable "grafana_pod_configuration" {
  default     = {}
  description = <<-EOF
  An object whose attributes configure the image registry, node selector, tolerations, resource requests and resource limits for the Grafana pods.
  The image must be in the `grafana/grafana` repository in the specified image registry.
  EOF
  nullable    = false
  type = object({
    image_registry = optional(string, "docker.io")
    node_selector  = optional(map(string), {})
    node_tolerations = optional(
      list(
        object(
          {
            key      = string
            operator = string
            value    = optional(string)
            effect   = string
          }
        )
      ),
    [])
    resources = optional(
      object({
        limits = optional(
          object({
            cpu    = optional(string, "500m")
            memory = optional(string, "512Mi")
          }),
        {})
        requests = optional(
          object({
            cpu    = optional(string, "500m")
            memory = optional(string, "512Mi")
          }),
        {})
      }),
    {})
  })

  validation {
    condition     = can(regex("^([a-z0-9\\-]+\\.)*[a-z0-9\\-]+(/[a-z0-9\\-._]+)?$", var.grafana_pod_configuration.image_registry))
    error_message = "The image registry is not a syntactically valid container registry name."
  }

  validation {
    condition     = alltrue([for v in values(var.grafana_pod_configuration.node_selector) : can(regex("^(?i)(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))?$", v))])
    error_message = "One or more node selector values is syntactically invalid or null.  See https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/ for details."
  }

  validation {
    condition     = alltrue([for k in keys(var.grafana_pod_configuration.node_selector) : can(regex("^(?i)(([a-z0-9]/)|([a-z0-9][a-z0-9\\-.]{0,251}[a-z0-9])/)?(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))$", k))])
    error_message = "One or more node selector keys is syntactically invalid or null.  See https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/ for details."
  }


  validation {
    condition     = alltrue([for t in var.grafana_pod_configuration.node_tolerations : contains(["NoExecute", "NoSchedule", "PreferNoSchedule", ""], t.effect)])
    error_message = "The toleration effects must be one of NoExecute, NoSchedule, PreferNoSchedule, or an empty string."
  }

  validation {
    condition     = alltrue([for t in var.grafana_pod_configuration.node_tolerations : contains(["Equal", "Exists"], t.operator)])
    error_message = "The toleration operators must be either Equal or Exists."
  }

  validation {
    condition     = alltrue([for t in var.grafana_pod_configuration.node_tolerations : t.value == null if t.operator == "Exists"])
    error_message = "The toleration value must be null if the operator is set to Exists."
  }

  validation {
    condition     = alltrue([for t in var.grafana_pod_configuration.node_tolerations : can(regex("^(?i)(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))?$", t.value)) if t.operator == "Equal"])
    error_message = "If the operator is set to Equal, the toleration value cannot be null and must be a syntactically valid Kubernetes label value.  See https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set for details."
  }

  validation {
    condition     = alltrue([for t in var.grafana_pod_configuration.node_tolerations : can(regex("^(?i)(([a-z0-9]/)|([a-z0-9][a-z0-9\\-.]{0,251}[a-z0-9])/)?(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))$", t.key))])
    error_message = "Toleration keys cannot be null and must be syntactically valid Kubernetes label keys.  See https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set for details."
  }
}

variable "ingress_class_name" {
  default     = "nginx"
  description = "The name of the ingress class to use for every Kubernetes ingress resource created by the Helm release."
  nullable    = false
  type        = string
}

variable "kube_base_domain" {
  description = "The base domain to use when constructing the hostnames in the module."
  nullable    = false
  type        = string
}

variable "kube_state_metrics_pod_configuration" {
  default     = {}
  description = <<-EOF
  An object whose attributes configure the image registry, node selector, tolerations, resource requests and resource limits for the Kube State Metrics pods.
  The image must be in the `kube-state-metrics/kube-state-metrics repository` in the specified image registry.
  EOF
  nullable    = false
  type = object({
    image_registry = optional(string, "registry.k8s.io")
    node_selector  = optional(map(string), {})
    node_tolerations = optional(
      list(
        object(
          {
            key      = string
            operator = string
            value    = optional(string)
            effect   = string
          }
        )
      ),
    [])
    replica_count = optional(number, 2)
    resources = optional(
      object({
        limits = optional(
          object({
            cpu    = optional(string, "100m")
            memory = optional(string, "256Mi")
          }),
        {})
        requests = optional(
          object({
            cpu    = optional(string, "100m")
            memory = optional(string, "256Mi")
          }),
        {})
      }),
    {})
  })

  validation {
    condition     = can(regex("^([a-z0-9\\-]+\\.)*[a-z0-9\\-]+(/[a-z0-9\\-._]+)?$", var.kube_state_metrics_pod_configuration.image_registry))
    error_message = "The image registry is not a syntactically valid container registry name."
  }

  validation {
    condition     = 0 <= var.kube_state_metrics_pod_configuration.replica_count
    error_message = "The number of replicas must be greater than or equal to zero."
  }

  validation {
    condition     = alltrue([for v in values(var.kube_state_metrics_pod_configuration.node_selector) : can(regex("^(?i)(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))?$", v))])
    error_message = "One or more node selector values is syntactically invalid or null.  See https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/ for details."
  }

  validation {
    condition     = alltrue([for k in keys(var.kube_state_metrics_pod_configuration.node_selector) : can(regex("^(?i)(([a-z0-9]/)|([a-z0-9][a-z0-9\\-.]{0,251}[a-z0-9])/)?(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))$", k))])
    error_message = "One or more node selector keys is syntactically invalid or null.  See https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/ for details."
  }


  validation {
    condition     = alltrue([for t in var.kube_state_metrics_pod_configuration.node_tolerations : contains(["NoExecute", "NoSchedule", "PreferNoSchedule", ""], t.effect)])
    error_message = "The toleration effects must be one of NoExecute, NoSchedule, PreferNoSchedule, or an empty string."
  }

  validation {
    condition     = alltrue([for t in var.kube_state_metrics_pod_configuration.node_tolerations : contains(["Equal", "Exists"], t.operator)])
    error_message = "The toleration operators must be either Equal or Exists."
  }

  validation {
    condition     = alltrue([for t in var.kube_state_metrics_pod_configuration.node_tolerations : t.value == null if t.operator == "Exists"])
    error_message = "The toleration value must be null if the operator is set to Exists."
  }

  validation {
    condition     = alltrue([for t in var.kube_state_metrics_pod_configuration.node_tolerations : can(regex("^(?i)(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))?$", t.value)) if t.operator == "Equal"])
    error_message = "If the operator is set to Equal, the toleration value cannot be null and must be a syntactically valid Kubernetes label value.  See https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set for details."
  }

  validation {
    condition     = alltrue([for t in var.kube_state_metrics_pod_configuration.node_tolerations : can(regex("^(?i)(([a-z0-9]/)|([a-z0-9][a-z0-9\\-.]{0,251}[a-z0-9])/)?(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))$", t.key))])
    error_message = "Toleration keys cannot be null and must be syntactically valid Kubernetes label keys.  See https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set for details."
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

variable "prometheus_operator_pod_configuration" {
  default     = {}
  description = <<-EOF
  An object whose attributes configure the container image registry, node selector, tolerations, resource requests and resource limits for the Prometheus Operator pods.
  The prometheus-operator and the prometheus-config-reloader images are pulled from the registry specified in the `image_registry` attribute.  The images must be under the
  `prometheus-operator/prometheus-operator` repository and the `prometheus-config-reloader` repository, respectively.  The value can have an optional path suffix
  to support the use of ECR pull-through caches.
  EOF
  nullable    = false
  type = object({
    image_registry = optional(string, "quay.io")
    node_selector  = optional(map(string), {})
    node_tolerations = optional(
      list(
        object(
          {
            key      = string
            operator = string
            value    = optional(string)
            effect   = string
          }
        )
      ),
    [])
    resources = optional(
      object({
        limits = optional(
          object({
            cpu    = optional(string, "100m")
            memory = optional(string, "256Mi")
          }),
        {})
        requests = optional(
          object({
            cpu    = optional(string, "100m")
            memory = optional(string, "256Mi")
          }),
        {})
      }),
    {})
  })

  validation {
    condition     = can(regex("^([a-z0-9\\-]+\\.)*[a-z0-9\\-]+(/[a-z0-9\\-._]+)?$", var.prometheus_operator_pod_configuration.image_registry))
    error_message = "The image registry is not a syntactically valid container registry name."
  }

  validation {
    condition     = alltrue([for v in values(var.prometheus_operator_pod_configuration.node_selector) : can(regex("^(?i)(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))?$", v))])
    error_message = "One or more node selector values is syntactically invalid or null.  See https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/ for details."
  }

  validation {
    condition     = alltrue([for k in keys(var.prometheus_operator_pod_configuration.node_selector) : can(regex("^(?i)(([a-z0-9]/)|([a-z0-9][a-z0-9\\-.]{0,251}[a-z0-9])/)?(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))$", k))])
    error_message = "One or more node selector keys is syntactically invalid or null.  See https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/ for details."
  }


  validation {
    condition     = alltrue([for t in var.prometheus_operator_pod_configuration.node_tolerations : contains(["NoExecute", "NoSchedule", "PreferNoSchedule", ""], t.effect)])
    error_message = "The toleration effects must be one of NoExecute, NoSchedule, PreferNoSchedule, or an empty string."
  }

  validation {
    condition     = alltrue([for t in var.prometheus_operator_pod_configuration.node_tolerations : contains(["Equal", "Exists"], t.operator)])
    error_message = "The toleration operators must be either Equal or Exists."
  }

  validation {
    condition     = alltrue([for t in var.prometheus_operator_pod_configuration.node_tolerations : t.value == null if t.operator == "Exists"])
    error_message = "The toleration value must be null if the operator is set to Exists."
  }

  validation {
    condition     = alltrue([for t in var.prometheus_operator_pod_configuration.node_tolerations : can(regex("^(?i)(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))?$", t.value)) if t.operator == "Equal"])
    error_message = "If the operator is set to Equal, the toleration value cannot be null and must be a syntactically valid Kubernetes label value.  See https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set for details."
  }

  validation {
    condition     = alltrue([for t in var.prometheus_operator_pod_configuration.node_tolerations : can(regex("^(?i)(([a-z0-9]/)|([a-z0-9][a-z0-9\\-.]{0,251}[a-z0-9])/)?(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))$", t.key))])
    error_message = "Toleration keys cannot be null and must be syntactically valid Kubernetes label keys.  See https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set for details."
  }

}

variable "prometheus_pod_configuration" {
  default     = {}
  description = <<-EOF
  An object whose attributes configure the image registry, persistent volume size (in gigabytes), node selector, tolerations, resource requests and resource limits for the Prometheus pods.
  The prometheus and node-exporter images are pulled from the registry specified in the `image_registry` attribute.
  The images must be in the 'prometheus/prometheus' and 'prometheus/node-exporter' repositories, respectively.
  The value can have an optional path suffix to support the use of ECR pull-through caches.
  EOF
  nullable    = false
  type = object({
    image_registry = optional(string, "quay.io")
    node_selector  = optional(map(string), {})
    node_tolerations = optional(
      list(
        object(
          {
            key      = string
            operator = string
            value    = optional(string)
            effect   = string
          }
        )
      ),
    [])
    resources = optional(
      object({
        limits = optional(
          object({
            cpu    = optional(string, "1")
            memory = optional(string, "2Gi")
          }),
        {})
        requests = optional(
          object({
            cpu    = optional(string, "1")
            memory = optional(string, "2Gi")
          }),
        {})
      }),
    {})
    volume_size = optional(number, 150)
  })

  validation {
    condition     = can(regex("^([a-z0-9\\-]+\\.)*[a-z0-9\\-]+(/[a-z0-9\\-._]+)?$", var.prometheus_pod_configuration.image_registry))
    error_message = "The image registry is not a syntactically valid container registry name."
  }

  validation {
    condition     = alltrue([for v in values(var.prometheus_pod_configuration.node_selector) : can(regex("^(?i)(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))?$", v))])
    error_message = "One or more node selector values is syntactically invalid or null.  See https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/ for details."
  }

  validation {
    condition     = alltrue([for k in keys(var.prometheus_pod_configuration.node_selector) : can(regex("^(?i)(([a-z0-9]/)|([a-z0-9][a-z0-9\\-.]{0,251}[a-z0-9])/)?(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))$", k))])
    error_message = "One or more node selector keys is syntactically invalid or null.  See https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/ for details."
  }


  validation {
    condition     = alltrue([for t in var.prometheus_pod_configuration.node_tolerations : contains(["NoExecute", "NoSchedule", "PreferNoSchedule", ""], t.effect)])
    error_message = "The toleration effects must be one of NoExecute, NoSchedule, PreferNoSchedule, or an empty string."
  }

  validation {
    condition     = alltrue([for t in var.prometheus_pod_configuration.node_tolerations : contains(["Equal", "Exists"], t.operator)])
    error_message = "The toleration operators must be either Equal or Exists."
  }

  validation {
    condition     = alltrue([for t in var.prometheus_pod_configuration.node_tolerations : t.value == null if t.operator == "Exists"])
    error_message = "The toleration value must be null if the operator is set to Exists."
  }

  validation {
    condition     = alltrue([for t in var.prometheus_pod_configuration.node_tolerations : can(regex("^(?i)(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))?$", t.value)) if t.operator == "Equal"])
    error_message = "If the operator is set to Equal, the toleration value cannot be null and must be a syntactically valid Kubernetes label value.  See https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set for details."
  }

  validation {
    condition     = alltrue([for t in var.prometheus_pod_configuration.node_tolerations : can(regex("^(?i)(([a-z0-9]/)|([a-z0-9][a-z0-9\\-.]{0,251}[a-z0-9])/)?(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))$", t.key))])
    error_message = "Toleration keys cannot be null and must be syntactically valid Kubernetes label keys.  See https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set for details."
  }

  validation {
    condition     = 1 <= var.prometheus_pod_configuration.volume_size && var.prometheus_pod_configuration.volume_size <= 16384
    error_message = "Invalid volume size.  See: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-volume-types.html#solid-state-drives for valid values."

  }
}

variable "vault_auth_backend_path" {
  description = "The Vault Kubernetes backend configured for the K8s cluster where the module resources are deployed.  Any Vault roles created by the module will be added to this backend."
  nullable    = false
  type        = string


  validation {
    condition     = can(regex("^[a-z0-9\\-]+$", var.vault_auth_backend_path))
    error_message = "The path may only consist of lower case alpha-numeric characters and dashes."
  }

  validation {
    condition     = !startswith(var.vault_auth_backend_path, "auth/")
    error_message = "The path must not include the 'auth/' prefix."
  }
}


variable "vault_metadata" {
  default     = {}
  description = "A map containing data to add to every Vault resource as metadata."
  nullable    = false
  type        = map(string)
}
