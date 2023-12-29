variable "agent_default_configuration" {
  default     = {}
  description = <<-EOF
  The default settings for the injected Vault agent containers.  The defaults match the default values in the Helm chart."
  For details on the template_config settings, see https://developer.hashicorp.com/vault/docs/agent-and-proxy/agent/template?page=agent&page=template
  The vault_version attibute is optional and can be used to override the Helm chart's default version of Vault used in the agent container.
  EOF
  nullable    = false
  type = object(
    {
      resources = optional(
        object({
          limits = optional(
            object({
              cpu               = optional(string, "500m")
              ephemeral_storage = optional(string, "512Mi")
              memory            = optional(string, "128Mi")
            }),
          {})
          requests = optional(
            object({
              cpu               = optional(string, "250m")
              ephemeral_storage = optional(string, "256Mi")
              memory            = optional(string, "64Mi")
            }),
          {})
        }),
      {})
      template_type = optional(string, "map")
      template_config = optional(object({
        exit_on_retry_failure         = optional(bool, true)
        static_secret_render_interval = optional(string, "5m")
      }), {})
      vault_version = optional(string)
    }
  )

  validation {
    condition     = contains(["json", "map"], var.agent_default_configuration.template_type)
    error_message = "The template_type must be either 'json' or 'map'."
  }

  validation {
    condition     = var.agent_default_configuration.vault_version == null || can(regex("^1\\.1[4-5]\\.\\d+$", var.agent_default_configuration.vault_version))
    error_message = "The vault_version must be either null or one of 1.14.x or 1.15.x where x is an positive integer value."
  }

}

variable "agent_injector_configuration" {
  default     = {}
  description = "Settings for the agent injector controller workload.  The default resoures match the default values in the Helm chart."
  nullable    = false
  type = object(
    {
      node_selector = optional(map(string), {})
      replicas      = optional(number, 2)
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
    }
  )

  validation {
    condition     = 0 <= var.agent_injector_configuration.replicas
    error_message = "The replicas attribute must greater than or equal to zero."
  }
}

variable "auth_backend" {
  default     = {}
  description = "Settings to configure the Vault Kubernetes authentication backend managed by the module."
  nullable    = false
  type = object({
    metadata = optional(map(string), {})
    path     = optional(string, "kubernetes")
  })

  validation {
    condition     = var.auth_backend.metadata != null
    error_message = "The metadata attribute cannot be null."
  }

  validation {
    condition     = var.auth_backend.path != null && can(regex("^[a-z0-9\\-]+$", var.auth_backend.path))
    error_message = "The path attribute cannot be null and may only consist of lower case alpha-numeric characters and dashes."
  }

  validation {
    condition     = !startswith(var.auth_backend.path, "auth/")
    error_message = "The path attribute must not include the 'auth/' prefix."
  }
}

variable "image_registry" {
  default     = "public.ecr.aws"
  description = <<-EOF
  The container image registry from which the hashicorp images will be pulled.
  The images must be in the 'hashicorp/vault', 'hashicorp/vault-k8s', and 'hashicorp/vault-csi-provider' repositories.
  The value can have an optional path suffix to support the use of ECR pull-through caches.
  EOF
  nullable    = false
  type        = string
  validation {
    condition     = can(regex("^([a-z0-9\\-]+\\.)*[a-z0-9\\-]+(/[a-z0-9\\-._]+)?$", var.image_registry))
    error_message = "The 'image_registry' variable is not a syntactically valid container registry name."
  }
}

variable "kubernetes_cluster" {
  description = <<-EOF
  An object containing attributes of the EKS cluster that are required for configuring Vault's Kubernetes authentication backend.

  The certificate_authority_pem attribute is the cluster endpoint's certificate authority's root certificate encoded in PEM format.
  The cluster_endpoint attribute is the URL of the cluster's Kubernetes API.
  The cluster_name attribute is the name of the cluster in EKS.
  EOF
  nullable    = false
  type = object({
    certificate_authority_pem = string
    cluster_endpoint          = string
    cluster_name              = string
  })

  validation {
    condition     = var.kubernetes_cluster.certificate_authority_pem != null && 0 < length(var.kubernetes_cluster.certificate_authority_pem)
    error_message = "The certificate_authority_pem attribute cannot be null or empty."
  }

  validation {
    condition     = var.kubernetes_cluster.cluster_endpoint != null && 0 < length(var.kubernetes_cluster.cluster_endpoint)
    error_message = "The cluster_endpoint attribute cannot be null or empty."
  }

  validation {
    # The naming constraints are defined at https://docs.aws.amazon.com/eks/latest/APIReference/API_CreateCluster.html#API_CreateCluster_RequestBody
    condition     = can(regex("^[0-9A-Za-z][A-Za-z0-9\\-_]{0,99}$", var.kubernetes_cluster.cluster_name))
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

variable "namespace" {
  description = "The name of the namespace where all module's Kubernetes resources, including the Helm releases, are deployed."
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

variable "secrets_store_csi_driver_chart_version" {
  default     = "1.3.4"
  description = "The version of the Vault Helm chart to deploy.  Valid versions are listed at https://github.com/kubernetes-sigs/secrets-store-csi-driver/releases."
  nullable    = false
  type        = string
  validation {
    condition     = can(regex("^1\\.3\\.4$", var.secrets_store_csi_driver_chart_version))
    error_message = "The secrets_store_csi_driver_chart_version must be 1.3.4."
  }
}

variable "vault_chart_version" {
  default     = "0.26.1"
  description = "The version of the Vault Helm chart to deploy.  Valid versions are listed at https://github.com/hashicorp/vault-helm/releases."
  nullable    = false
  type        = string

  validation {
    condition     = can(regex("^0\\.2[56]\\.\\d+$", var.vault_chart_version))
    error_message = "The vault_chart_version must be 0.25.x or 0.26.x where 'x' is an integer greater than or equal to zero."
  }
}

variable "vault_csi_provider_configuration" {
  default     = {}
  description = "Settings for the Vault CSI provider daemonset.  The defaults match the default values in the Helm chart."
  nullable    = false
  type = object(
    {
      resources = optional(
        object({
          limits = optional(
            object({
              cpu    = optional(string, "50m")
              memory = optional(string, "128Mi")
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
}

variable "vault_server_address" {
  description = "The URL of the Vault server."
  nullable    = false
  type        = string

  validation {
    condition     = 0 < length(var.vault_server_address)
    error_message = "The vault_server_address variable cannot be empty."
  }
}
