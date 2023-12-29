variable "cluster_name" {
  description = "The name of the target EKS cluster."
  type        = string
  nullable    = false
  validation {
    # The naming constraints are defined at https://docs.aws.amazon.com/eks/latest/APIReference/API_CreateCluster.html#API_CreateCluster_RequestBody
    condition     = can(regex("^[0-9A-Za-z][A-Za-z0-9\\-_]{0,99}$", var.cluster_name))
    error_message = "The cluster name must adhere to the EKS cluster name restrictions."
  }
}

variable "fargate_profile_name" {
  description = "The value to use as the name of the profile.  It will be suffixed with a dynamically generated value to ensure it is unique.  AWS allows names to be up to 63 characters in length but to account for the suffix, arguments are limited to 48 characters."
  nullable    = false
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9_\\-]{0,48}[a-zA-Z0-9]$", var.fargate_profile_name))
    error_message = "The name must contain at least two characters and 48 or fewer characters.  It must begin with letter or digit and can have any of the following characters: English letters, digits, hyphens and underscores."
  }
}

variable "selectors" {
  description = "The selectors to determine which pods will be scheduled in the onto Fargate nodes with this profile.  See https://docs.aws.amazon.com/eks/latest/userguide/fargate-profile.html for more details on valid values."
  nullable    = false
  type = list(object({
    namespace = string
    labels    = optional(map(string), {})
  }))

  validation {
    condition     = 0 < length(var.selectors)
    error_message = "At least one selector must be specified."
  }

  validation {
    condition     = length(var.selectors) <= 5
    error_message = "Cannot specify more than five selectors."
  }

  validation {
    condition     = alltrue([for s in var.selectors : length(s.labels) <= 5])
    error_message = "Cannot specify more than five labels in a selector."
  }

  validation {
    condition     = alltrue([for namespace in var.selectors[*].namespace : can(regex("^[?*a-z0-9\\-]+$", namespace))])
    error_message = "Selector namespaces cannot be null or empty and must consist of lower-case letters, numbers, hyphens, `*`, or `?`."
  }

  validation {
    condition     = alltrue([for value in flatten([for labels in var.selectors[*].labels : values(labels)]) : can(regex("^[a-z0-9A-Z*_.\\-?]+$", value))])
    error_message = "Selector label values cannot be null or empty and must consist of letters, numbers, hyphens, periods, underscores, `*`, or `?`."
  }

  validation {
    condition     = alltrue([for key in flatten([for labels in var.selectors[*].labels : keys(labels)]) : can(regex("^[a-z0-9A-Z*_.\\-?/]+$", key))])
    error_message = "Selector label keys cannot be empty and must consist of letters, numbers, hyphens, periods, underscores, `*`, `?`, or forward slashes."
  }
}

variable "subnet_ids" {
  description = "The subnets in which the ENIs of the pods scheduled on the profile will be created."
  nullable    = false
  type        = list(string)

  validation {
    condition     = 0 < length(var.subnet_ids)
    error_message = "At least one subnet must be specified."
  }

  validation {
    condition     = alltrue([for id in var.subnet_ids : can(regex("^subnet-[a-f0-9]+$", id))])
    error_message = "One or more of the values is not a syntactically valid subnet identifier."
  }

}
variable "pod_execution_role_arn" {
  description = "Amazon Resource Name (ARN) of the IAM Role that provides permissions for the EKS Fargate Profile."
  nullable    = false
  type        = string

  validation {
    condition     = 0 < length(var.pod_execution_role_arn)
    error_message = "The pod_execution_role_arn cannot be empty."
  }

  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]+:role/[\\w+=,.@\\-]+$", var.pod_execution_role_arn))
    error_message = "The pod_execution_role_arn is not a syntactically valid IAM role ARN."
  }
}

variable "tags" {
  default     = {}
  description = "An optional map of AWS tags to attach to every resource created by the module."
  nullable    = false
  type        = map(string)
}
