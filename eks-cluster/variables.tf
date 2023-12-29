variable "access_analyzer_name" {
  default     = "account"
  description = "The name of the IAM Access Analyzer in the same account and region in which the cluster is deployed."
  nullable    = false
  type        = string
}

variable "additional_security_group_identifiers" {
  default     = []
  description = "An optional set security group identifiers to attach to the cluster's network interfaces."
  nullable    = false
  type        = set(string)
}

variable "administrator_iam_principals" {
  default     = []
  description = "The ARNs of any IAM principals that are allowed to assume the IAM role that creates the cluster."
  nullable    = false
  type        = set(string)
  validation {
    condition     = alltrue([for v in var.administrator_iam_principals : !can(regex("/aws-reserved/sso.amazonaws.com/", v))])
    error_message = "Roles created by AWS SSO are not permitted in the 'administrator_iam_principals' variable.  Use the 'administrator_sso_permission_sets' variable to specify AWS SSO principals."
  }
}

variable "administrator_sso_permission_sets" {
  default     = []
  description = "The names of any AWS SSO permission sets that are allowed to assume the IAM role that creates the cluster."
  nullable    = false
  type        = set(string)
  validation {
    # The regex comes from https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-sso-permissionset.html
    condition     = alltrue([for v in var.administrator_sso_permission_sets : can(regex("^[\\w+=,.@-]+$", v))])
    error_message = "Invalid value specified for the 'administrator_sso_permission_sets' variable."
  }
}

variable "coredns_version" {
  default     = "none"
  description = <<-EOF
    The version of the coredns add-on to use.   Can be set to 'default',
    'latest', 'none', or pinned to a specific version.  Use 'none' as the
    argument if coredns should not be managed by EKS.  If the cluster does
    does not have any nodes, then 'none' must be used because the add-on
    will have the 'DEGRADED' status until nodes are added.  If an add-on
    has the 'DEGRADED' status, Terraform will fail to apply.
  EOF
  nullable    = false
  type        = string
  validation {
    condition     = contains(["default", "latest", "none"], var.coredns_version) || can(regex("^v\\d+\\.\\d+\\.\\d+-eksbuild\\.\\d+$", var.coredns_version))
    error_message = "The 'coredns_version' variable must be 'default', 'latest', 'none', or a specific version."
  }
}

variable "cluster_ipv4_cidr_block" {
  default     = "172.20.0.0/16"
  description = "The CIDR block to assign to the k8s cluster."
  nullable    = false
  type        = string
}

variable "cluster_log_retention" {
  description = "The number of days CloudWatch will retain the cluster's control plane logs."
  default     = 731 # 24 months
  nullable    = false
  type        = number
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.cluster_log_retention)
    error_message = "The 'cluster_log_retention' variable must be one of 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, or 3653."
  }
}

variable "cluster_name" {
  description = "The name of the EKS cluster."
  type        = string
  validation {
    # The naming constraints are defined at https://docs.aws.amazon.com/eks/latest/APIReference/API_CreateCluster.html#API_CreateCluster_RequestBody
    condition     = can(regex("^[0-9A-Za-z][A-Za-z0-9\\-_]{0,99}$", var.cluster_name))
    error_message = "The cluster name must adhere to the EKS cluster name restrictions."
  }
}

variable "cluster_creator_arn" {
  default     = null
  description = "The ARN of the IAM principal that created the cluster outside of Terraform.  This is the principal with implicit system:masters access to the cluster's k8s API.  DO NOT SET THIS VALUE UNLESS YOU ARE IMPORTING THE CLUSTER INTO TERRAFORM."
  nullable    = true
  type        = string
}

variable "deletion_protection" {
  default     = true
  description = <<-EOF
    When set to true, the policy on the IAM role assumed by CloudFormation will not include the `eks:DeleteCluster` action
    nor will the CloudFormation stack policy allow the cluster to be deleted.  Unlike services such as RDS, EKS does not
    have a built-in way to prevent cluster deletion. Removing permission to delete clusters is the only way to implement
    similar functionality.
  EOF
  nullable    = false
  type        = bool
}

variable "endpoint_private_access" {
  default     = true
  description = "Enable or disable access to the k8s API endpoint from within the VPC"
  nullable    = false
  type        = bool
}

variable "endpoint_public_access" {
  default     = false
  description = "Enable or disable access to the k8s API endpoint from the Internet."
  nullable    = false
  type        = bool
}

variable "k8s_version" {
  description = "The version of Kubernetes to use in the cluster."
  type        = string
  validation {
    condition     = contains(["1.23", "1.24", "1.25", "1.26", "1.27", ], var.k8s_version)
    error_message = "Unsupported Kubernetes version specified."
  }
}

variable "kube_proxy_version" {
  description = "The version of the kube-proxy add-on to use.  Can be set to 'default', 'latest', or pinned to a specific version."
  default     = "default"
  nullable    = false
  type        = string
  validation {
    condition     = contains(["default", "latest"], var.kube_proxy_version) || can(regex("^v\\d+\\.\\d+\\.\\d+-eksbuild\\.\\d+$", var.kube_proxy_version))
    error_message = "The 'kube_proxy_version' variable must be 'default', 'latest', or a specific version."
  }
}

variable "predefined_cluster_role_name" {
  default     = null
  description = "The name of an existing IAM role the EKS cluster should assume instead of creating a dedicated role.  Do not use this argument for new clusters.  It is intended to be used when importing a cluster created outside of Terraform"
  type        = string
}

variable "subnet_ids" {
  description = "The subnets where the cluster will create its network interfaces."
  nullable    = false
  type        = list(string)
  validation {
    condition     = 1 < length(toset(var.subnet_ids))
    error_message = "At least two unique subnets must be specified."
  }
}

variable "tags" {
  default     = {}
  description = "An optional map of AWS tags to attach to every resource created by the module."
  nullable    = false
  type        = map(string)
}

variable "vpc_cni_version" {
  description = "The version of the vpc-cni add-on to use.  Can be set to 'default', 'latest', or pinned to a specific version."
  default     = "default"
  nullable    = false
  type        = string
  validation {
    condition     = contains(["default", "latest"], var.vpc_cni_version) || can(regex("^v\\d+\\.\\d+\\.\\d+-eksbuild\\.\\d+$", var.vpc_cni_version))
    error_message = "The 'vpc_cni_version' variable must be 'default', 'latest', or a specific version."
  }
}

