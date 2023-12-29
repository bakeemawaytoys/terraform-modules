variable "custom_inline_policies" {
  default     = {}
  description = "A map whose entries are custom inline policies to attach to the role.  The keys are the name of the policies and the values are strings containing the policy JSON."
  nullable    = false
  type        = map(string)
}


variable "eks_cluster" {
  description = <<-EOF
  Attributes of the EKS cluster in which the application is deployed.  The names of the attributes match the names of outputs in the eks-cluster module to allow using the module as the argument to this variable.

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
    condition     = can(regex("^(arn:aws:iam::[0-9]+:oidc-provider/oidc\\.eks\\.us-((east)|(west))-[1-9]\\.amazonaws.com/id/[0-9A-F]+)$", var.eks_cluster.service_account_oidc_provider_arn))
    error_message = "The OIDC provider ARN is not syntactically valid for an EKS cluster identity provider."
  }
}

variable "managed_policy_names" {
  default     = []
  description = "An optional set of the names of managed IAM policies to attach to the role."
  nullable    = false
  type        = set(string)
}

variable "name" {
  description = "The name of the role managed by this module."
  nullable    = false
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9,+.@_\\-]{1,64}$", var.name))
    error_message = "The role name must meet the IAM naming requirements.  https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_iam-quotas.html#reference_iam-quotas-names"
  }
}

variable "path" {
  default     = "/"
  description = "The path of the role managed by this module."
  nullable    = false
  type        = string

  validation {
    condition     = length(var.path) <= 512
    error_message = "The path cannot exceed 512 characters in length."
  }

  validation {
    condition     = startswith(var.path, "/")
    error_message = "The path must start with a '/' character."
  }

  validation {
    condition     = endswith(var.path, "/")
    error_message = "The path must end with a '/' character."
  }

  validation {
    condition     = can(regex("^/([a-zA-Z0-9,+.@_\\-/]{0,510}/)*$", var.path))
    error_message = "The path contains invalid characters.  For more details see https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_iam-quotas.html."
  }

}

variable "s3_access" {
  default     = null
  description = <<-EOF
  An optional object containing S3 buckets the role has permission to either read from or write to. An inline policy
  is attached to the role to grant access to the queues.  At least one bucket must be provided if the variable is
  not set to null.  The `writer_buckets` attribute contains the list of buckets to which the role has permission to read
  and write objects.  The `read_buckets` attribute contains the list of buckets to which the role only has permission
  to read objects.  All buckets must be in the same AWS account as the role.

  Both lists contain objects with the following properites.  Each object corresponds to one bucket.
  The `arn` attribute is the ARN of the bucket.  It is required if the `bucket` attribute is not set.
  The `bucket` attribute is the name of the bucket.  It is required if the `arn` attribute is not set.
  The `sse_kms_key_arn` attribute is the ARN of the KMS key used to encrypt objects in the bucket, if the bucket is configured with an SSE key.
  The `prefixes` attribute is a list of object key prefixes in the bucket the role can access.  By default, the role has access to all objects.
  EOF
  nullable    = true
  type = object({
    writer_buckets = optional(list(
      object({
        arn             = optional(string)
        bucket          = optional(string)
        sse_kms_key_arn = optional(string)
        prefixes        = optional(list(string), ["*"])
      })
    ), [])
    reader_buckets = optional(list(
      object({
        arn             = optional(string)
        bucket          = optional(string)
        sse_kms_key_arn = optional(string)
        prefixes        = optional(list(string), ["*"])
      })
    ), [])
  })

  validation {
    condition     = try(0 < length(var.s3_access.writer_buckets) || 0 < length(var.s3_access.reader_buckets), var.s3_access == null)
    error_message = "At least one bucket must be supplied if s3_access is not null."
  }

  # Reader bucket attribute validation

  validation {
    condition     = alltrue([for b in try(var.s3_access.reader_buckets, []) : startswith(b.arn, "arn:aws:s3:::") if b.arn != null])
    error_message = "Reader bucket ARNs, if specified, must have the prefix 'arn:aws:s3:::'."
  }

  validation {
    condition     = alltrue([for b in try(var.s3_access.reader_buckets, []) : (b.arn != null && b.bucket == null) || (b.arn == null && b.bucket != null)])
    error_message = "Cannot specify both the bucket and the arn attributes of reader buckets.  Exactly one of them must be specified in each object."
  }

  validation {
    condition     = alltrue([for b in try(var.s3_access.reader_buckets, []) : 0 < length(b.prefixes)])
    error_message = "Every reader bucket 'prefixes' list must contain at least one value."
  }

  validation {
    condition     = alltrue([for p in try(flatten(var.s3_access.reader_buckets[*].prefixes), []) : !startswith(p, "/")])
    error_message = "Reader bucket prefixes cannot start with a '/' character."
  }

  validation {
    condition     = alltrue([for b in try(var.s3_access.reader_buckets, []) : can(regex("^arn:aws:kms:us-((east)|(west))-[1-9]:[0-9]+:key/[a-f0-9\\-]+$", b.sse_kms_key_arn)) if b.sse_kms_key_arn != null])
    error_message = "One or more reader bucket SSE KMS key ARN is not a syntactically valid CMK ARN."
  }


  # Writer bucket attribute validation

  validation {
    condition     = alltrue([for b in try(var.s3_access.writer_buckets, []) : startswith(b.arn, "arn:aws:s3:::") if b.arn != null])
    error_message = "Writer bucket ARNs, if specified, must have the prefix 'arn:aws:s3:::'."
  }

  validation {
    condition     = alltrue([for b in try(var.s3_access.writer_buckets, []) : (b.arn != null && b.bucket == null) || (b.arn == null && b.bucket != null)])
    error_message = "Cannot specify both the bucket and the arn attributes of writer buckets.  Exactly one of them must be specified in each object."
  }

  validation {
    condition     = alltrue([for b in try(var.s3_access.writer_buckets, []) : 0 < length(b.prefixes)])
    error_message = "Every writer bucket 'prefixes' list must contain at least one value."
  }

  validation {
    condition     = alltrue([for p in try(flatten(var.s3_access.writer_buckets[*].prefixes), []) : !startswith(p, "/")])
    error_message = "Writer bucket prefixes cannot start with a '/' character."
  }

  validation {
    condition     = alltrue([for b in try(var.s3_access.writer_buckets, []) : can(regex("^arn:aws:kms:us-((east)|(west))-[1-9]:[0-9]+:key/[a-f0-9\\-]+$", b.sse_kms_key_arn)) if b.sse_kms_key_arn != null])
    error_message = "One or more writer bucket SSE KMS key ARNs are not a syntactically valid CMK ARN."
  }

}

variable "service_account" {
  description = <<-EOF
  The name and namespace of the Kubernetes service account that can assume the role.  Either value may contain the `?` and `*`
  wildcard characters to configure the roles trust policy to allow multiple service accounts to assume the role.  For more
  details on the wildcards, see the IAM documentation on the `StringLike` condition operator at https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements_condition_operators.html#Conditions_String.
  EOF
  nullable    = false
  type = object({
    name      = string
    namespace = string
  })

  validation {
    condition     = !can(regex("^${replace(replace(var.service_account.name, "?", "."), "*", ".*")}$", "default"))
    error_message = "To avoid accidentally granting AWS access, the name cannot match the `default` service account."
  }

  validation {
    condition     = var.service_account.name != "*"
    error_message = "To avoid accidentally granting AWS access, using the `*` wildcard as the name is not allowed."
  }

  validation {
    condition     = 0 < length(var.service_account.name) && length(var.service_account.name) < 254
    error_message = "The namespace variable must contain at least one character and at most 253 characters."
  }

  validation {
    condition     = can(regex("^[a-z0-9*?]([a-z0-9\\-*?]*[a-z0-9*?])*$", var.service_account.name))
    error_message = "The name must be a syntactically valid Kubernetes name. https://kubernetes.io/docs/concepts/overview/working-with-objects/names/"
  }

  validation {
    condition     = 0 < length(var.service_account.namespace) && length(var.service_account.namespace) < 64
    error_message = "The namespace must contain at least one character and at most 63 characters."
  }

  validation {
    condition     = can(regex("^[a-z0-9*?]([a-z0-9\\-*?]*[a-z0-9*?])*$", var.service_account.namespace))
    error_message = "The namespace must be a syntactically valid Kubernetes namespace. https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/#namespaces-and-dns"
  }

  validation {
    condition     = var.service_account.namespace != "*"
    error_message = "To avoid accidentally granting AWS access, using the `*` wildcard as the namespace is not allowed."
  }
}

variable "sqs_access" {
  default     = null
  description = <<-EOF
  An optional object containing sets of SQS queues the role has permission to either read from or send to. An inline policy
  is attached to the role to grant access to the queues.  At least one queue ARN must be provided if the variable is not
  set to null. The existence of the queues is not checked by the module to allow for cross-account access to queues.

  The `consumer_queue_arns` attribute is the set of ARNs of the queues the role has permission to read from.
  The `producer_queue_arns` attribute is the set of ARNs of the queues the role has permission to write to.
  EOF
  nullable    = true
  type = object({
    consumer_queue_arns = optional(set(string), [])
    producer_queue_arns = optional(set(string), [])
  })

  validation {
    condition     = try(0 < length(var.sqs_access.consumer_queue_arns) || 0 < length(var.sqs_access.producer_queue_arns), var.sqs_access == null)
    error_message = "At least one SQS ARN must be supplied if the sqs_variable is not null."
  }

  validation {
    condition     = alltrue([for arn in try(var.sqs_access.consumer_queue_arns, []) : can(regex("^arn:aws:sqs:us-((east)|(west))-[1-9]:[0-9]+:[a-z0-9\\-_]+(.fifo)?$", arn))])
    error_message = "One or more ARNs are not syntactically valid."
  }

  validation {
    condition     = alltrue([for arn in try(var.sqs_access.producer_queue_arns, []) : can(regex("^arn:aws:sqs:us-((east)|(west))-[1-9]:[0-9]+:[a-z0-9\\-_]+(.fifo)?$", arn))])
    error_message = "One or more ARNs are not syntactically valid."
  }

}

variable "ses_access" {
  default     = null
  description = <<-EOF
  An optional object containing SES identities the role has permission to send email from. An inline policy
  is attached to the role to grant access to the identities.  At least one identity must be provided if the variable is
  not set to null.  The existence of the identities is not checked by the module to allow for cross-account access to identities.

  The `email_identity_arns` attribute is the set of ARNs of the email identities the role has permission to send email from.
  EOF
  nullable    = true
  type = object({
    email_identity_arns = optional(set(string), [])
  })

  validation {
    condition     = try(0 < length(var.ses_access.email_identity_arns), var.ses_access == null)
    error_message = "At least one SES identity ARN must be supplied if the ses_access variable is not null."
  }

  validation {
    condition     = alltrue([for arn in try(var.ses_access.email_identity_arns, []) : can(regex("^arn:aws:ses:us-((east))|((west))-[1-9]:[0-9]+:identity.+$", arn))])
    error_message = "One or more email addresses are not syntactically valid."
  }

}

variable "tags" {
  default     = {}
  description = "An optional map of AWS tags to attach to every resource created by the module."
  nullable    = false
  type        = map(string)
}
