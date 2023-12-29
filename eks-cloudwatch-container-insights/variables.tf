variable "cloudwatch_agent_pod_resources" {
  default     = {}
  description = "CPU and memory settings for the CloudWatch agent pods."
  nullable    = false
  type = object(
    {
      limits = optional(
        object({
          cpu    = optional(string, "400m")
          memory = optional(string, "400Mi")
        }),
      {})
      requests = optional(
        object({
          cpu    = optional(string, "200m")
          memory = optional(string, "200Mi")
        }),
      {})
    }
  )
}

variable "cluster_name" {
  description = "The name of the target EKS cluster."
  nullable    = false
  type        = string

  validation {
    # The naming constraints are defined at https://docs.aws.amazon.com/eks/latest/APIReference/API_CreateCluster.html#API_CreateCluster_RequestBody
    condition     = can(regex("^[0-9A-Za-z][A-Za-z0-9\\-_]{0,99}$", var.cluster_name))
    error_message = "The cluster name must adhere to the EKS cluster name restrictions."
  }
}

variable "enable_enhanced_observability" {
  default     = true
  description = "Enables the Enhanced Observability feature on the CloudWatch agent"
  nullable    = false
  type        = bool
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

variable "fargate_logging" {
  default     = {}
  description = <<-EOF
  An object to optionally enable and configure Fargate pod log collection.  When enabled, the pod logs are pushed to
  the Container Insights application log group.  When enabled, at least one Fargate pod execution role must be provided.
  The role names specified in the `pod_execution_role_names` attribute.  The Fluent Bit process logs are enabled by default.
  They can be disabled using the `enabled` attribute of the `fluent_bit_process_logging` object attribute.  The process log
  retention defaults to one year.  It can be modified using the `retention_in_days` attribute of the `fluent_bit_process_logging`
  object attribute.

  EOF
  nullable    = false
  type = object({
    enabled = optional(bool, false)
    fluent_bit_process_logging = optional(
      object({
        enabled           = optional(bool, true)
        retention_in_days = optional(number, 365)
      }),
    {})
    pod_execution_role_names = optional(set(string), [])
  })

  validation {
    condition     = (var.fargate_logging.enabled && 0 < length(var.fargate_logging.pod_execution_role_names)) || !var.fargate_logging.enabled
    error_message = "At least one pod execution role must be provided if Fargate logging is enabled."
  }

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.fargate_logging.fluent_bit_process_logging.retention_in_days)
    error_message = "The process logging retention must be one of 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, or 3653."
  }
}

variable "fluent_bit_pod_resources" {
  default     = {}
  description = "CPU and memory settings for the Fluent Bit pods."
  nullable    = false
  type = object({
    limits = optional(
      object({
        cpu    = optional(string, "1000m")
        memory = optional(string, "200Mi")
      }),
    {})
    requests = optional(
      object({
        cpu    = optional(string, "500m")
        memory = optional(string, "100Mi")
      }),
    {})
  })
}

variable "http_server_enabled" {
  default     = true
  description = "Enables the Fluent Bit HTTP server for Prometheus metrics scraping."
  nullable    = false
  type        = bool
}

variable "image_registry" {
  default     = "public.ecr.aws"
  description = <<-EOF
  The container image registry from which the AWS CloudWatch agent image will be pulled.  The images must be in the cloudwatch-agent/cloudwatch-agent repository.
  The value can have an optional path suffix to support the use of ECR pull-through caches.
  EOF
  nullable    = false
  type        = string
  validation {
    condition     = can(regex("^([a-z0-9\\-]+\\.)*[a-z0-9\\-]+(/[a-z0-9\\-._]+)?$", var.image_registry))
    error_message = "The 'image_registry' variable is not a syntactically valid container registry name."
  }
}

variable "http_server_port" {
  default     = 2020
  description = "Configures the listening port for Prometheus metrics scraping."
  nullable    = false
  type        = number
  validation {
    # Allow the ports between the well-known range and the ephemeral range.
    condition     = 1024 < var.http_server_port && var.http_server_port < 32768
    error_message = "The 'http_server_port' variable must be between 1024 and 32768."
  }
}

variable "labels" {
  default     = {}
  description = "An optional map of kubernetes labels to attach to every resource created by the module."
  nullable    = false
  type        = map(string)
}

variable "log_retention_in_days" {
  default     = 365
  description = "The number of days to retain the logs in the CloudWatch log groups."
  type        = number
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_in_days)
    error_message = "The 'log_retention_in_days' variable must be one of 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, or 3653."
  }
}

variable "metrics_collection_interval" {
  default     = 30
  description = "The interval, in seconds, in which the CloudWatch agent will collect metrics.  Defaults to 30 seconds"
  nullable    = false
  type        = number

  validation {
    condition     = 0 < var.metrics_collection_interval
    error_message = "The metrics collection interval must be greater than zero."
  }
}

variable "namespace" {
  default     = "amazon-cloudwatch"
  description = "The namespace where Kubernetes resources will be installed."
  nullable    = false
  type        = string
  validation {
    condition     = length(trimspace(var.namespace)) > 0
    error_message = "The 'namespace' variable cannot be empty."
  }
}

variable "read_from_head" {
  default     = false
  description = "Configures Fluent Bit to read from the head of the log files."
  nullable    = false
  type        = bool
}

variable "read_from_tail" {
  default     = true
  description = "Configures Fluent Bit to read from the tail of the log files."
  nullable    = false
  type        = bool
}

variable "tags" {
  default     = {}
  description = "An optional map of AWS tags to attach to every resource created by the module."
  nullable    = false
  type        = map(string)
}
