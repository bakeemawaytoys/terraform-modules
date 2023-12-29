variable "availability_zones" {
  description = "The names of the availability zones to use for the VPC's subnets."
  nullable    = false
  type        = list(string)
}

variable "cidr_block" {
  description = "The primary IPv4 CIDR block of the VPC."
  nullable    = false
  type        = string
}

variable "eks_cluster_names" {
  description = "The names of the EKS clusters deployed to the VPC."
  nullable    = false
  type        = set(string)
}

variable "nat_subnet_cidr_blocks" {
  description = "A list of CIDR blocks to use for the subnets dedicated to NAT gateways.  One gateway is created in each of the CIDR blocks."
  nullable    = false
  type        = list(string)
}

variable "public_subnet_cidr_blocks" {
  default     = []
  description = "An optional list of CIDR blocks to use for public subnets.  Public subnets are tagged with the 'kubernetes.io/role/elb' tag."
  nullable    = false
  type        = list(string)
}

variable "node_subnet_cidr_blocks" {
  description = "A list of CIDR block to use for subnets where EKS nodes run."
  nullable    = false
  type        = list(string)
}

variable "pod_subnet_cidr_blocks" {
  description = "A list of CIDR block to use for subnets where EKS pod ENIs are created."
  nullable    = false
  type        = list(string)
}

variable "private_subnet_cidr_blocks" {
  default     = []
  description = "An optional list of CIDR blocks to use for private subnets with Internet access through the NAT gateways. Private subnets are tagged with the 'kubernetes.io/role/internal-elb' tag."
  nullable    = false
  type        = list(string)
}

variable "internal_subnet_cidr_blocks" {
  description = "An optional list of CIDR blocks to use for private subnets with no access outside of the VPC.  Primarily intendend to be used with VPC-enabled AWS services."
  default     = []
  nullable    = false
  type        = list(string)
}

variable "route53_firewall_rule_group_ids" {
  default     = []
  description = "An optional list of identifiers of Route53 firewall rule groups to associate with the VPC.  The priorities assigned to the rule groups is based on the ordering of the list, from highest to lowest."
  nullable    = false
  type        = list(string)

  validation {
    condition     = alltrue([for v in var.route53_firewall_rule_group_ids : can(regex("^rslvr-frg-[a-f0-9]+$", v))])
    error_message = "One or more of the Route53 firewall rule group identifiers are syntactically incorrect."
  }
}

variable "route53_query_log_config_ids" {
  default     = []
  description = "An optional list of identifiers of Rout53 query log configurations to associate with the VPC."
  nullable    = false
  type        = set(string)

  validation {
    condition     = alltrue([for v in var.route53_query_log_config_ids : can(regex("^rqlc-[a-f0-9]+$", v))])
    error_message = "One or more of the Route53 query log config identifiers are syntactically incorrect."
  }
}

variable "tags" {
  default     = {}
  description = "An optional map of AWS tags to apply to every resource created by the module."
  nullable    = false
  type        = map(string)
}

variable "vpc_name" {
  description = "The value to use for the Name tag on the VPC."
  nullable    = false
  type        = string
}
