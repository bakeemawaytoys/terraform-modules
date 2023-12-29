variable "acme_dns01_route53_solvers" {
  type = map(
    object({
      dns_names = optional(list(string), [])
      dns_zones = optional(list(string), [])
    })
  )
  description = <<-EOF
  A map whose keys are the names of the public Route53 public zones cert-manager can use for ACME DNS01 challenges  The objects in the map are
  the partially qualified domain names inside the Route53 zone that are allowed to be used for DNS01 challenges.  The values are used to construct
  the IAM policy attached to cert-manager's role.

  The `dns_names`attribute defines a list of DNS names that must match exactly to be used with DNS01 challenges.  The `dns_zones` attribue define
  a list of subdomains under which any domain name can be used with DNS01 challenges.  The values in both attributes must be relative to the
  Route53 zone's name.  The attributes are analogus to the DNS name selctors in cert-manager's issuer resources.

  The if neither the `dns_names`nor the `dns_zones` attributes contain any values, then any name in the Route53 zone, including the apex is permitted.

  See also: https://cert-manager.io/docs/reference/api-docs/#acme.cert-manager.io/v1.CertificateDNSNameSelector
  EOF
  nullable    = false

  validation {
    condition     = 0 < length(var.acme_dns01_route53_solvers)
    error_message = "The 'acme_dns01_route53_solvers' variable must contain at least one entry."
  }

  validation {
    condition     = alltrue([for name in keys(var.acme_dns01_route53_solvers) : can(regex("^[a-z0-9][a-z0-0\\-]{0,61}[a-z0-9]?(\\.[a-z0-9][a-z0-0\\-]{0,61}[a-z0-9]?)*$", name))])
    error_message = "One or more keys is not a syntactically valid domain name."
  }

  validation {
    condition     = alltrue([for name in flatten(values(var.acme_dns01_route53_solvers)[*].dns_names) : can(regex("^[a-z0-9][a-z0-0\\-]{0,61}[a-z0-9]?(\\.[a-z0-9][a-z0-0\\-]{0,61}[a-z0-9]?)*$", name))])
    error_message = "One or more 'dns_names' values is not a syntactically valid domain name."
  }

  validation {
    condition     = alltrue([for name in flatten(values(var.acme_dns01_route53_solvers)[*].dns_zones) : can(regex("^[a-z0-9][a-z0-0\\-]{0,61}[a-z0-9]?(\\.[a-z0-9][a-z0-0\\-]{0,61}[a-z0-9]?)*$", name))])
    error_message = "One or more 'dns_zones' values is not a syntactically valid domain name."
  }
}

variable "ca_injector_pod_configuration" {
  default     = {}
  description = "Specifies the replica count, resource requests, and resource limits of the CA injector pods."
  nullable    = false
  type = object(
    {
      node_selector = optional(map(string), {})
      replicas      = optional(number, 2)
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
              cpu    = optional(string, "50m")
              memory = optional(string, "128Mi")
            }),
          {})
        }),
      {})
    }
  )
  validation {
    condition     = var.ca_injector_pod_configuration.replicas != null && 0 < var.ca_injector_pod_configuration.replicas
    error_message = "The 'ca_injector_pod_configuration.replicas' value must be greater than or equal to 1."
  }
}

variable "chart_version" {
  description = "The version of the Helm chart to install.  The supported versions are v1.12.6 and v1.13.2."
  nullable    = false
  type        = string
  validation {
    condition     = contains(["v1.12.6", "v1.13.2"], var.chart_version)
    error_message = "The chart version must be v1.12.6 or v1.13.2."
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

variable "cluster_resource_namespace" {
  default     = null
  type        = string
  description = <<-EOF
  The Kubernetes namespace in which cert-manager will create the TLS secrets for certificates issued by ClusterIssuer resources.
  Defaults to the value of the `namespace` variable.
  See https://cert-manager.io/docs/configuration/#cluster-resource-namespace for more details.
  EOF

  validation {
    condition     = var.cluster_resource_namespace == null || can(regex("^[a-z0-9][a-z0-0\\-]{0,61}[a-z0-9]?$", var.cluster_resource_namespace))
    error_message = "The 'cluster_resource_namespace' must be either null or conform to the RFC 1123 DNS label standard.  See also https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#dns-label-names"
  }
}

variable "controller_pod_configuration" {
  default     = {}
  description = "Specifies the replica count, resource requests, and resource limits of the controller pods."
  nullable    = false
  type = object(
    {
      node_selector = optional(map(string), {})
      replicas      = optional(number, 2)
      resources = optional(
        object({
          limits = optional(
            object({
              cpu    = optional(string, "100m")
              memory = optional(string, "512Mi")
            }),
          {})
          requests = optional(
            object({
              cpu    = optional(string, "50m")
              memory = optional(string, "256Mi")
            }),
          {})
        }),
      {})
    }
  )

  validation {
    condition     = var.controller_pod_configuration.replicas != null && 0 < var.controller_pod_configuration.replicas
    error_message = "The 'controller_pod_configuration.replicas' value must be greater than or equal to 1."
  }
}

variable "default_ingress_issuer" {
  default     = null
  description = <<-EOF
  An optional object for configuring the default issuer to use if an ingress does not specify one.
  The values are used to set the `--default-issuer-group`, `--default-issuer-kind`, and CLI arguments on the controller.
  For more details see https://cert-manager.io/docs/cli/controller/
  EOF
  nullable    = true
  type = object({
    group = optional(string, "cert-manager.io")
    kind  = optional(string, "ClusterIssuer")
    name  = string
  })

  validation {
    condition     = var.default_ingress_issuer == null || can(regex("^[a-z.\\-0-9]+$", var.default_ingress_issuer.group))
    error_message = "The 'group' attribute must consist of lower case alpha-numeric characters, dots, and dashes."
  }

  validation {
    condition     = try(contains(["ClusterIssuer", "Issuer"], var.default_ingress_issuer.kind), var.default_ingress_issuer == null)
    error_message = "The 'kind' attribute must be either ClusterIssuer or Issuer."
  }

  validation {
    condition     = var.default_ingress_issuer == null || can(regex("^[a-z\\-0-9]+$", var.default_ingress_issuer.name))
    error_message = "The 'name' attribute must consist of lower case alpha-numeric characters and dashes."
  }
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

variable "http_challenge_solver_pod_configuration" {
  default     = {}
  description = <<-EOF
  Customizes the resource requests and limits on the pods created by cert-manager to solve ACME HTTPS01 challenges.
  EOF
  nullable    = false
  type = object({
    resources = optional(
      object({
        limits = optional(
          object({
            cpu    = optional(string, "100m")
            memory = optional(string, "64Mi")
          }),
        {})
        requests = optional(
          object({
            # The default CPU request used by the controller is 10m with a CPU limit of 100m.  This far exceeds the
            # default 2:1 limit-to-request ratio enforced by the gitlab-application-k8s-namespace module.  To prevent
            # the defaults from preventing the pod to spawn, the default request is bumped to half the default limit.
            cpu    = optional(string, "50m")
            memory = optional(string, "64Mi")
          }),
        {})
      }),
    {})
  })
}

variable "image_registry" {
  default     = "quay.io"
  description = <<-EOF
  The container image registry from which the controller, CA injector, webhook, and Helm hook images will be pulled.
  The images must be under the 'jetstack/cert-manager-controller', 'jetstack/cert-manager-cainjector', 'jetstack/cert-manager-webhook' and 'jetstack/cert-manager-ctl' repositories, respectively.
  The value can have an optional path suffix to support the use of ECR pull-through caches.
  EOF
  nullable    = false
  type        = string
  validation {
    condition     = can(regex("^([a-z0-9\\-]+\\.)*[a-z0-9\\-]+(/[a-z0-9\\-._]+)?$", var.image_registry))
    error_message = "The 'image_registry' variable is not a syntactically valid container registry name."
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
  default     = 2
  description = "Configures the the verbosity of cert-manager. Range of 0 - 6 with 6 being the most verbose."
  nullable    = false
  type        = number
  validation {
    condition     = contains(range(7), var.log_level)
    error_message = "The 'log_level' must be an integer in the range of 0 through 6, inclusive."
  }
}

variable "node_tolerations" {
  default     = []
  description = <<-EOF
  An optional list of objects to set node tolerations on all pods deployed by the chart.  The object structure corresponds to the structure of the
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

variable "release_name" {
  default     = "cert-manager"
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

variable "tags" {
  default     = {}
  description = "An optional map of AWS tags to attach to every resource created by the module."
  nullable    = false
  type        = map(string)
}

variable "webhook_pod_configuration" {
  default     = {}
  description = "Specifies the replica count, node selector, resource requests, and resource limits of the webhook pods."
  nullable    = false
  type = object(
    {
      node_selector = optional(map(string), {})
      replicas      = optional(number, 2)
      resources = optional(
        object({
          limits = optional(
            object({
              cpu    = optional(string, "200m")
              memory = optional(string, "256Mi")
            }),
          {})
          requests = optional(
            object({
              cpu    = optional(string, "100m")
              memory = optional(string, "128Mi")
            }),
          {})
        }),
      {})
    }
  )

  validation {
    condition     = var.webhook_pod_configuration.replicas != null && 0 < var.webhook_pod_configuration.replicas
    error_message = "The 'webhook_pod_configuration.replicas' value must be greater than or equal to 1."
  }
}
