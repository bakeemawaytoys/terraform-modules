variable "annotations" {
  default     = {}
  description = "An optional map containing the namespace's annotations."
  nullable    = false
  type        = map(string)
}

variable "distributed_cache_bucket" {
  description = "An object containing the name of the S3 bucket used as the runner's distributed cache as well as the AWS region where the bucket is located."
  nullable    = false
  type = object({
    bucket = string
    region = optional(string, "us-west-2")
  })
}

variable "eks_cluster" {
  description = <<-EOF
  Attributes of the EKS cluster on which Karpenter is deployed.  The names of the attributes match the names of outputs in the eks-cluster module to allow using the module as the argument to this variable.

  The `cluster_name` attribute the the name of the EKS cluster.  It is required.
  The 'service_account_oidc_provider_arn' attribute is the ARN of the cluster's IAM OIDC identity provider.  It is required.
  EOF
  nullable    = false
  type = object({
    cluster_name                      = string
    service_account_oidc_provider_arn = string
  })

  validation {
    # The naming constraints are defined at https://docs.aws.amazon.com/eks/latest/APIReference/API_CreateCluster.html#API_CreateCluster_RequestBody
    condition     = can(regex("^[0-9A-Za-z][A-Za-z0-9\\-_]{0,99}$", var.eks_cluster.cluster_name))
    error_message = "The cluster name must adhere to the EKS cluster name restrictions."
  }

  validation {
    condition     = var.eks_cluster.service_account_oidc_provider_arn != null
    error_message = "The service_account_oidc_provider_arn attribute cannot be null."
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

variable "fargate_profile" {
  description = "An object whose attributes configure the Fargate profile in which the pods in the namespace run."
  nullable    = false
  type = object({
    pod_execution_role_arn = string
    subnet_ids             = set(string)
  })
}

variable "pod_security_standards" {
  default     = {}
  description = <<-EOF
  Configures the levels of the pod security admission modes.

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

variable "tags" {
  default     = {}
  description = "An optional map of AWS tags to attach to every resource created by the module."
  nullable    = false
  type        = map(string)
}
