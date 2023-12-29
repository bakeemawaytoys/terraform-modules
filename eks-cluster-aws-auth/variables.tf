variable "ssm_agent_credentials_source" {
  default     = "default-host-management"
  description = <<-EOF
  Determines which credentials the Systems Manager agent will use.  When set to the default value of `default-host-management`, the agent will use credentials supplied by
  System Manager's [Default Host Management feature](https://docs.aws.amazon.com/systems-manager/latest/userguide/managed-instances-default-host-management.html).  To use
  the EC2 instance profile credentials, set this variable to `instance-profile`  The module will attach the `AmazonSSMManagedInstanceCore` IAM managed policy to the EC2 node role.
  EOF
  nullable    = false
  type        = string

  validation {
    condition     = contains(["default-host-management", "instance-profile"], var.ssm_agent_credentials_source)
    error_message = "The SSM agent credential source must be one of `default-host-management` or `instance-profile`."
  }
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

variable "iam_role_mappings" {
  default     = []
  description = <<-EOF
    A list of objects containing the ARN of an IAM role, the k8s groups to assign to the role, and an
    optional prefix to use with the `{{SessionName}}` variable to construct the k8s usernames assigned to the k8s role.
  EOF
  nullable    = false
  type = list(
    object(
      {
        role_arn        = string
        rbac_groups     = optional(set(string), [])
        username_prefix = optional(string)
      }
    )
  )
}

variable "tags" {
  default     = {}
  description = "An optional map of AWS tags to attach to every resource created by the module."
  nullable    = false
  type        = map(string)
}
