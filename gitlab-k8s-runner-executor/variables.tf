variable "allowed_images" {
  default     = []
  description = <<-EOF
  Restricts the images that may be used in build jobs to those that match the the patterns in the list.  If the list is empty, any image is allowed (the default).
  See also: https://docs.gitlab.com/runner/configuration/advanced-configuration.html#restricting-docker-images-and-services
  EOF
  nullable    = false
  type        = list(string)
}


variable "architecture" {
  default     = "x86_64"
  description = "The CPU architecture on which the exectuor and the jobs will run."
  type        = string
  validation {
    condition     = contains(["x86_64", "arm64"], var.architecture)
    error_message = "The 'architecture variable must be either x86_64 or arm64."
  }
}

variable "build_pod_annotations" {
  default     = {}
  description = <<-EOF
  Kubernetes annotations to apply to every build pod created by the runner.  Annotation values can contain Gitlab CI variables.
  See https://docs.gitlab.com/ee/ci/variables/predefined_variables.html for the list of available variables.  The module automatically
  includes the 'karpenter.sh/do-not-evict' annotation to prevent Karpenter from evicting pods while jobs are running.  For more
  details, see https://karpenter.sh/preview/tasks/deprovisioning/#pod-set-to-do-not-evict.
  EOF
  nullable    = false
  type = object(
    {
      static            = optional(map(string), {})
      overwrite_allowed = optional(string, "")
    }
  )
}

variable "build_container_security_context" {
  default     = {}
  description = "Specifies the Linux user ID, group ID, and capabilites to add or remove on the build container's security context."
  type = object(
    {
      run_as_user       = optional(number, 1000)
      run_as_group      = optional(number, 1000)
      add_capabilities  = optional(set(string), [])
      drop_capabilities = optional(set(string), ["ALL"])
    }
  )
  validation {
    condition     = 0 <= var.build_container_security_context.run_as_user && 0 <= var.build_container_security_context.run_as_group
    error_message = "The 'build_container' variable's run_as_user and run_as_group attributes must be greater than or equal to zero."
  }
}

variable "build_container_resources" {
  default     = {}
  description = <<-EOF
    CPU and memory settings for the build container that runs the job script.  Sets default request and limit values as well as the maximum
    allowed values that can be set in the job variables.  See https://docs.gitlab.com/runner/executors/kubernetes.html#overwriting-container-resources
    for more on using the job variables.
  EOF
  nullable    = false
  type = object(
    {
      limits = optional(
        object({
          cpu = optional(
            object({
              default = optional(string, "500m")
              max     = optional(string, "")
            }),
          {})
          ephemeral_storage = optional(
            object({
              default = optional(string, "20Gi")
              max     = optional(string, "")
            }),
          {})
          memory = optional(
            object({
              default = optional(string, "1Gi")
              max     = optional(string, "")
            }),
          {})
        }),
      {})
      requests = optional(
        object({
          cpu = optional(
            object({
              default = optional(string, "250m")
              max     = optional(string, "")
            }),
          {})
          ephemeral_storage = optional(
            object({
              default = optional(string, "20Gi")
              max     = optional(string, "")
            }),
          {})
          memory = optional(
            object({
              default = optional(string, "512Mi")
              max     = optional(string, "")
            }),
          {})
        }),
      {})
    }
  )
}

variable "build_pod_aws_iam_role" {
  default     = null
  description = <<-EOF
  The required annotations for the IAM Roles for Service Accounts feature are added to the build pod's service account to allow it to assume the specified IAM role in the
  specified account.  The OIDC tokens projected into the pods are configured to expire after 1 hour.  The annotations are merged with any annotations specified in the
  build_pod_service_account variable with the annotations generated by this variable taking precedence.  Role paths are not supported.    The IAM role is NOT created by the module.
  See https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html for more details.
  EOF
  nullable    = true
  type = object(
    {
      name       = string
      account_id = string
    }
  )
  validation {
    condition     = var.build_pod_aws_iam_role == null || can(regex("^[0-9]+$", var.build_pod_aws_iam_role.account_id)) && can(regex("^[\\w+=,.@-]{1,64}$", var.build_pod_aws_iam_role.name))
    error_message = "The `build_pod_aws_iam_role.account_id` value must be a numeric string and the `build_pod_aws_iam_role.name` value must meet the IAM role name requirements."
  }
}

variable "build_pod_node_selector" {
  default     = {}
  description = <<-EOF
  An optional map of Kubernetes labels to use as the build pods' node selectors.  The module automatically
  includes the 'kubernetes.io/arch' and 'kubernetes.io/os' labels in the selector.
  https://docs.gitlab.com/runner/executors/kubernetes.html#using-node-selectors
  EOF
  nullable    = false
  type        = map(string)

  validation {
    condition     = alltrue([for v in values(var.build_pod_node_selector) : can(regex("^(?i)(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))?$", v))])
    error_message = "One or more node selector values is syntactically invalid or null.  See https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set for details."
  }

  validation {
    condition     = alltrue([for k in keys(var.build_pod_node_selector) : can(regex("^(?i)(([a-z0-9]/)|([a-z0-9][a-z0-9\\-.]{0,251}[a-z0-9])/)?(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))$", k))])
    error_message = "One or more node selector keys is syntactically invalid or null.  See https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set for details."
  }
}


variable "build_pod_node_tolerations" {
  default     = []
  description = <<-EOF
  An optional list of objects to set node tolerations on the build pods.  The object structure corresponds to the structure of the
  toleration syntax in the Kubernetes pod spec.  The module converts the objects to the equivalent TOML in the runner configurataion file.

  https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/
  https://docs.gitlab.com/runner/executors/kubernetes.html
  EOF
  nullable    = false
  type = list(object(
    {
      key      = string
      operator = string
      value    = string
      effect   = string
    }
  ))

  validation {
    condition     = alltrue([for t in var.build_pod_node_tolerations : contains(["NoExecute", "NoSchedule", "PreferNoSchedule", ""], t.effect)])
    error_message = "The toleration effects must be one of NoExecute, NoSchedule, PreferNoSchedule, or an empty string."
  }

  validation {
    condition     = alltrue([for t in var.build_pod_node_tolerations : contains(["Equal", "Exists"], t.operator)])
    error_message = "The toleration operators must be either Equal or Exists."
  }

  validation {
    condition     = alltrue([for t in var.build_pod_node_tolerations : t.value == null if t.operator == "Exists"])
    error_message = "The toleration value must be null if the operator is set to Exists."
  }

  validation {
    condition     = alltrue([for t in var.build_pod_node_tolerations : can(regex("^(?i)(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))?$", t.value)) if t.operator == "Equal"])
    error_message = "If the operator is set to Equal, the toleration value cannot be null and must be a syntactically valid Kubernetes label value.  See https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set for details."
  }

  validation {
    condition     = alltrue([for t in var.build_pod_node_tolerations : can(regex("^(?i)(([a-z0-9]/)|([a-z0-9][a-z0-9\\-.]{0,251}[a-z0-9])/)?(([a-z0-9])|([a-z0-9]([a-z0-9\\-_.]){0,61}[a-z0-9]))$", t.key))])
    error_message = "Toleration keys cannot be null and must be syntactically valid Kubernetes label keys.  See https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set for details."
  }

}

variable "build_pod_service_account" {
  default     = {}
  description = "An object containing optional attribute values to apply to the service account used for the build pods."
  nullable    = false
  type = object(
    {
      annotations                     = optional(map(string), {})
      automount_service_account_token = optional(bool, false)
    }
  )
}

variable "cluster_name" {
  description = "The name of the target EKS cluster."
  type        = string
  validation {
    # The naming constraints are defined at https://docs.aws.amazon.com/eks/latest/APIReference/API_CreateCluster.html#API_CreateCluster_RequestBody
    condition     = can(regex("^[0-9A-Za-z][A-Za-z0-9\\-_]{0,99}$", var.cluster_name))
    error_message = "The cluster name must adhere to the EKS cluster name restrictions."
  }
}

variable "chart_version" {
  description = "The version of the runner Helm chart to use for the release. Must be a 0.57.x or 0.58.x version."
  type        = string
  validation {
    condition     = can(regex("^0\\.5[7-8]+\\.[0-9]+$", var.chart_version))
    error_message = "The chart_version must be 0.57.x or 0.58.x where 'x' is a positive integer value."
  }
}

variable "default_build_image" {
  default     = "public.ecr.aws/docker/library/alpine:3.17.3"
  description = "The default image to use if the CI job does not specify one."
  type        = string

}

variable "distributed_cache_bucket" {
  description = "An object containing the name of the S3 bucket used as the runner's distributed cache as well as the AWS region where the bucket is located."
  type = object(
    {
      name   = string
      region = string
    }
  )
}

variable "pod_security_standards" {
  default     = {}
  description = <<-EOF
  Configures the levels of the pod security admission modes on the build pod namespace

  https://kubernetes.io/docs/concepts/security/pod-security-admission/
  https://kubernetes.io/docs/tasks/configure-pod-container/enforce-standards-namespace-labels/
  https://kubernetes.io/docs/concepts/security/pod-security-standards/
  EOF
  nullable    = false
  type = object({
    audit   = optional(string, "restricted")
    enforce = optional(string, "baseline")
    warn    = optional(string, "restricted")
  })

  validation {
    condition     = alltrue([for v in values(var.pod_security_standards) : contains(["baseline", "privileged", "restricted"], v)])
    error_message = "One or more pod security standard levels are invalid.  Valid levels are baseline, privileged, or restricted."
  }
}

variable "runner_image_registry" {
  default     = "public.ecr.aws"
  description = <<-EOF
  The container image registry from which the runner and runner-helper images will be pulled.  The images must be in the gitlab/gitlab-runner and the gitlab/gitlab-runner-helper repositories, respectively.
  The value can have an optional path suffix to support the use of ECR pull-through caches.
  EOF
  nullable    = false
  type        = string
  validation {
    condition     = can(regex("^([a-z0-9\\-]+\\.)*[a-z0-9\\-]+(/[a-z0-9\\-._]+)?$", var.runner_image_registry))
    error_message = "The 'runner_image_registry' variable is not a syntactically valid container registry name."
  }
}

variable "executor_namespace" {
  description = "The name of the Kubernets namespace where the executor pod will run.  The namespace must already exist."
  nullable    = false
  type        = string
}

variable "executor_iam_role_arn" {
  description = "The ARN of the AWS IAM role the executor can assume.  Must have permission to access the distributed cache bucket."
  nullable    = false
  type        = string
}

variable "executor_pod_annotations" {
  default     = {}
  description = "An optional map of annotations to assign to the executor pod."
  nullable    = false
  type        = map(string)
}

variable "executor_pod_resources" {
  default     = {}
  description = "CPU and memory settings for the executor pod."
  nullable    = false
  type = object({
    limits = optional(
      object({
        cpu    = optional(string, "200m")
        memory = optional(string, "512Mi")
      }),
    {})
    requests = optional(
      object({
        cpu    = optional(string, "100m")
        memory = optional(string, "256Mi")
      }),
    {})
  })
}

variable "helper_container_resources" {
  default     = {}
  description = "CPU and memory settings for the helper container that runs in the build pod."
  nullable    = false
  type = object({
    limits = optional(
      object({
        cpu               = optional(string, "1")
        ephemeral_storage = optional(string, "5Gi")
        memory            = optional(string, "1Gi")

      }),
    {})
    requests = optional(
      object({
        cpu               = optional(string, "500m")
        ephemeral_storage = optional(string, "5Gi")
        memory            = optional(string, "512Mi")
      }),
    {})
  })
}

variable "gitlab_url" {
  description = "The URL the runner will use to access the Gitlab API."
  default     = "https://gitlab.com"
  type        = string
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

variable "protected_branches" {
  default     = false
  description = "Set to 'true' to only run jobs on protected branches or 'false' to run jobs for any branch."
  type        = bool
}

variable "runner_scope" {
  description = "The scope (project, group, or instance) of jobs the runner will handle."
  type        = string
  validation {
    condition     = can(regex("^(instance)|(group-[1-9]\\d*)|(project-[1-9]\\d*)$", var.runner_scope))
    error_message = "The 'runner_scope' variable must be one of 'instance', 'group-<group ID>', or 'project-<project ID>'."
  }
}

variable "runner_flavor" {
  description = "An additional value for constructing resource names to differentiate between multiple runners in the same scope."
  default     = "default"
  nullable    = false
  type        = string
  validation {
    condition     = can(regex("^[0-9a-z\\-_]+$", var.runner_flavor))
    error_message = "The 'runner_flavor' variable can only consist of numbers, lower-case characters, dashes, and underscores."
  }
}

variable "runner_job_tags" {
  default     = []
  description = "https://docs.gitlab.com/ee/ci/runners/configure_runners.html#use-tags-to-control-which-jobs-a-runner-can-run"
  type        = set(string)
}

variable "sealed_runner_registration_token" {
  description = "The runner's registration token as secret value sealed using kubeseal's raw mode. https://github.com/bitnami-labs/sealed-secrets#raw-mode-experimental"
  type        = string
}

variable "service_container_resources" {
  default     = {}
  description = <<-EOF
    CPU and memory settings for the service containers that runs the job script.  Sets default request and limit values as well as the maximum
    allowed values that can be set in the job variables.  See https://docs.gitlab.com/runner/executors/kubernetes.html#overwriting-container-resources
    for more on using the job variables.
  EOF
  nullable    = false
  type = object({
    limits = optional(
      object({
        cpu = optional(
          object({
            default = optional(string, "500m")
            max     = optional(string, "")
          }),
        {})
        ephemeral_storage = optional(
          object({
            default = optional(string, "1Gi")
            max     = optional(string, "")
          }),
        {})
        memory = optional(
          object({
            default = optional(string, "1Gi")
            max     = optional(string, "")
          }),
        {})
      }),
    {})
    requests = optional(object({
      cpu = optional(
        object({
          default = optional(string, "250m")
          max     = optional(string, "")
        }),
      {})
      ephemeral_storage = optional(
        object({
          default = optional(string, "1Gi")
          max     = optional(string, "")
        }),
      {})
      memory = optional(
        object({
          default = optional(string, "512Mi")
          max     = optional(string, "")
        }),
      {})
      }),
    {})
  })
}