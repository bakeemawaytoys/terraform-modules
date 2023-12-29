variable "additional_security_group_ids" {
  default     = []
  description = "The identifiers of security groups to attach to the instance in addition to the security group managed by this module."
  nullable    = false
  type        = set(string)

  validation {
    condition     = alltrue([for id in var.additional_security_group_ids : can(regex("^sg-[0-9a-f]+$", id))])
    error_message = "One or more of the values is not a syntactically valid security group ID."
  }
}

variable "global_alarm_actions" {
  default     = {}
  description = <<-EOF
  An object whose attributes are sets of ARNs for the resources that are used as the actions on all
  CloudWatch alarms.  The `all_actions` attribute contains actions used on all types of actions
  supported by alarms.  The `enabled` attribute enables or disables actions on all alarms in the
  module unless the `enabled` attribute on the alarm's corresponding variable is set.
  EOF
  nullable    = false
  type = object({
    alarm_actions             = optional(set(string), [])
    all_actions               = optional(set(string), [])
    enabled                   = optional(bool, true)
    insufficient_data_actions = optional(set(string), [])
    ok_actions                = optional(set(string), [])
  })
}

variable "backup_retention_period" {
  default     = 7
  description = "The number of days an automatic backup will be retained"
  nullable    = false
  type        = number
  validation {
    condition     = 0 < var.backup_retention_period
    error_message = "The backup retention period must be an integer greater than zero."
  }

  validation {
    condition     = var.backup_retention_period <= 35
    error_message = "The backup retention period must be an integer less than or equal to 35."
  }
}

variable "backup_window" {
  default     = "08:00-09:00"
  description = "Configures the preferred window for the creation of automated snapshots."
  nullable    = false
  type        = string
}

variable "ca_cert_identifier" {
  default     = "rds-ca-rsa4096-g1"
  description = <<-EOF
  The identifier of the RDS certificate authority certificate to use to sign the instance's certificate.
  EOF
  nullable    = false
  type        = string

  validation {
    condition     = contains(["rds-ca-ecc384-g1", "rds-ca-rsa4096-g1", "rds-ca-rsa2048-g1", "rds-ca-2019", ], var.ca_cert_identifier)
    error_message = "The CA certificate identifier is invalid.  It must be one of rds-ca-ecc384-g1, rds-ca-rsa4096-g1, rds-ca-rsa2048-g1, or rds-ca-2019."
  }
}

variable "cloudwatch_log_retention_period" {
  default     = 365
  description = "The number of days to retain log events in the CloudWatch log groups.  Defaults to one year."
  nullable    = false
  type        = number
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.cloudwatch_log_retention_period)
    error_message = "The 'cluster_log_retention' variable must be one of 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, or 3653."
  }
}

variable "cpu_utilization_alarm" {
  default     = {}
  description = "An object whose attributes customize the CloudWatch alarm monitoring the instance's CPUUtilization metric.  The threshold is a percentage of the CPU utilization."
  nullable    = false
  type = object({
    alarm_actions             = optional(set(string), [])
    all_actions               = optional(set(string), [])
    enabled                   = optional(bool)
    evaluation_periods        = optional(number, 4),
    insufficient_data_actions = optional(set(string), [])
    ok_actions                = optional(set(string), [])
    period                    = optional(number, 30)
    threshold                 = optional(number, 90)
  })

  validation {
    condition     = 0 < var.cpu_utilization_alarm.threshold && var.cpu_utilization_alarm.threshold <= 100
    error_message = "The threshold must be greater than zero and less than or equal to 100."
  }
}

variable "db_name" {
  default     = null
  description = "The name of the database to create when the DB instance is created. If this parameter is not null, no database is created in the DB instance."
  nullable    = true
  type        = string
}

variable "deletion_protection" {
  default     = true
  description = "Enables or disables deletion protection on the instance.  Defaults to enabled."
  nullable    = false
  type        = bool
}

variable "engine_version" {
  default     = "14"
  description = <<-EOF
  The version of the PostgreSQL engine running in the instance.  The major version must be specified.  The minor version
  is optional.  If the minor version is set, automatic minor upgrades will be disabled to pin the instance to that version.
  The major version must be set to 13, 14, or 15.  The default is 14.
  EOF
  type        = string
  validation {
    condition     = can(regex("^1[345](\\.[0-9]+)?$", var.engine_version))
    error_message = "The engine version must be major version 13, 14, or 15 with an optional minor version."
  }
}

variable "disk_queue_depth_alarm" {
  default     = {}
  description = "An object whose attributes customize the CloudWatch alarm monitoring the instance's DiskQueueDepth metric."
  nullable    = false
  type = object({
    alarm_actions             = optional(set(string), [])
    all_actions               = optional(set(string), [])
    enabled                   = optional(bool)
    evaluation_periods        = optional(number, 2),
    insufficient_data_actions = optional(set(string), [])
    ok_actions                = optional(set(string), [])
    period                    = optional(number, 30)
    threshold                 = optional(number, 1)
  })

  validation {
    condition     = 0 < var.disk_queue_depth_alarm.threshold
    error_message = "The threshold must be greater than zero."
  }
}

variable "foreign_data_wrapper_security_group_egress_rules" {
  default     = {}
  description = <<-EOF
  A map of whose entries define the port 5432 security group egress rules on the instance's security group.  The referenced security groups
  are attached to other RDS PostgreSQL instances that are configured as targets for Postgres foreign data wrappers in this instance.
  The keys in the map are the target instances' security group IDs and the entries are the rule's description.
  EOF
  nullable    = false
  type        = map(string)

  validation {
    condition     = alltrue([for id in keys(var.foreign_data_wrapper_security_group_egress_rules) : can(regex("^sg-[0-9a-f]+$", id))])
    error_message = "One or more of the keys is not a syntactically valid security group ID."
  }

  validation {
    condition     = alltrue([for description in values(var.foreign_data_wrapper_security_group_egress_rules) : length(description) <= 255])
    error_message = "One or more of the values exceeds the maximum description length of 255 characters."
  }

  validation {
    condition     = alltrue([for description in values(var.foreign_data_wrapper_security_group_egress_rules) : can(regex("^[a-zA-Z0-9 ._\\-:/()#,@\\[\\]+=;{}!$]*$", description))])
    error_message = "One or more of the values contains characters disallowed in security group descriptions.  For details, see https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/security-group-rules.html"
  }
}


variable "freeable_memory_alarm" {
  default     = {}
  description = "An object whose attributes customize the CloudWatch alarm monitoring the instance's FreeableMemory metric.  The threshold is a percentage of the instance's total memory."
  nullable    = false
  type = object({
    alarm_actions             = optional(set(string), [])
    all_actions               = optional(set(string), [])
    enabled                   = optional(bool)
    evaluation_periods        = optional(number, 10),
    insufficient_data_actions = optional(set(string), [])
    ok_actions                = optional(set(string), [])
    period                    = optional(number, 30)
    threshold                 = optional(number, 10)
  })

  validation {
    condition     = 0 < var.freeable_memory_alarm.threshold && var.freeable_memory_alarm.threshold <= 100
    error_message = "The threshold must be greater than zero and less than or equal to 100."
  }
}

variable "freeable_storage_alarm" {
  default     = {}
  description = "An object whose attributes customize the CloudWatch alarm monitoring the instance's FreeableStorage metric.  The threshold is a percentage of the instance's maximum allocatable storage space."
  nullable    = false
  type = object({
    alarm_actions             = optional(set(string), [])
    all_actions               = optional(set(string), [])
    enabled                   = optional(bool)
    evaluation_periods        = optional(number, 10),
    insufficient_data_actions = optional(set(string), [])
    ok_actions                = optional(set(string), [])
    period                    = optional(number, 60)
    threshold                 = optional(number, 10)
  })

  validation {
    condition     = 0 < var.freeable_storage_alarm.threshold && var.freeable_storage_alarm.threshold <= 100
    error_message = "The threshold must be greater than zero and less than or equal to 100."
  }
}

variable "identifier" {
  description = "The identifier (name) of the instance."
  nullable    = false
  type        = string

  validation {
    condition     = length(var.identifier) <= 63
    error_message = "Instance identifiers must be less or equal to 63 characters.  For details see https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Limits.html#RDS_Limits.Constraints."
  }

  validation {
    condition     = can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", var.identifier))
    error_message = "The identifier must conform to the RDS naming restrictions.  For details see https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Limits.html#RDS_Limits.Constraints."
  }
}

variable "instance_class" {
  default     = "db.t3.micro"
  description = "The type of instance the database engine will run on. "
  nullable    = false
  type        = string

  validation {
    condition     = startswith(var.instance_class, "db.")
    error_message = "The instance class must have the 'db.' prefix."
  }
}

variable "instance_parameters" {
  default     = []
  description = "Customizes parameters in the instances parameters group."
  nullable    = false
  type = list(
    object({
      apply_method = optional(string, "immediate")
      name         = string
      value        = string
      }
  ))

  validation {
    condition     = alltrue([for param in var.instance_parameters : contains(["immediate", "pending-reboot"], param.apply_method)])
    error_message = "One or more of the apply methods is set to an invalid value.  Valid values are immediate and pending-reboot."
  }

  validation {
    condition     = alltrue([for param in var.instance_parameters : param.name != null])
    error_message = "Parameter names cannot be null."
  }

  validation {
    condition     = alltrue([for param in var.instance_parameters : param.name != "rds.custom_dns_resolution"])
    error_message = "The rds.custom_dns_resolution  Cannot be specified in this variable.  It is implicitly enabled when Lambda functions are set in the lambda_integration variable."
  }

  validation {
    condition     = alltrue([for param in var.instance_parameters : param.value != null])
    error_message = "Parameter values cannot be null."
  }
}

variable "ipv4_cidr_block_ingress_rules" {
  default     = {}
  description = "A map of whose entries define the IPv4 CIDR block ingress rules on the instance's security group.  The keys are the CIDR blocks and the entries are the rule's description."
  nullable    = false
  type        = map(string)

  validation {
    condition     = alltrue([for cidr_block in keys(var.ipv4_cidr_block_ingress_rules) : can(cidrnetmask(cidr_block))])
    error_message = "One or more of the keys is not a syntactically valid IPv4 CIDR block."
  }

  validation {
    condition     = alltrue([for description in values(var.ipv4_cidr_block_ingress_rules) : length(description) <= 255])
    error_message = "One or more of the values exceeds the maximum description length of 255 characters."
  }

  validation {
    condition     = alltrue([for description in values(var.ipv4_cidr_block_ingress_rules) : can(regex("^[a-zA-Z0-9 ._\\-:/()#,@\\[\\]+=;{}!$]*$", description))])
    error_message = "One or more of the values contains characters disallowed in security group descriptions.  For details, see https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/security-group-rules.html"
  }
}

variable "multi_az_enabled" {
  default     = false
  description = "Determines if AWS creates a hot-standby replica in a separate availabilty zone."
  nullable    = false
  type        = bool
}

variable "lambda_integration" {
  default     = {}
  description = "An optional object to configure the IAM role and security group permissions required to allow the instance to invoke Lambda functions."
  nullable    = false
  type = object({
    function_arns                  = optional(set(string), [])
    vpc_endpoint_security_group_id = optional(string)
  })

  validation {
    condition     = !(var.lambda_integration.vpc_endpoint_security_group_id == null && 0 < length(var.lambda_integration.function_arns))
    error_message = "The VPC endpoint security group ID must be specified if function ARNs are specified."
  }
}

variable "kms_encryption_key_alias" {
  default     = "alias/aws/rds"
  description = "The alias of the KMS key to use for encryption of both the instance and, unless one is specified in the performance_insights varible, the instance's Performance Insights data."
  nullable    = false
  type        = string

  validation {
    condition     = startswith(var.kms_encryption_key_alias, "alias/")
    error_message = "The encryption key alias must start with 'alias/'."
  }
}

variable "maintenance_window" {
  default     = "mon:10:00-mon:11:00"
  description = "The window when RDS will perform automated maintenance."
  nullable    = true
  type        = string
}

variable "master_user" {
  default     = {}
  description = "Configures the master user created in the database by RDS."
  nullable    = false
  type = object({
    username        = optional(string, "rdsadministrator")
    manage_password = optional(bool, true)
  })

  validation {
    condition     = var.master_user.username != "rdsadmin"
    error_message = "The username cannot be 'rdsadmin'.  It is a reserved word used by the PostgreSQL engine."
  }

  validation {
    condition     = can(regex("^[a-zA-Z][_a-zA-Z0-9]+$", var.master_user.username))
    error_message = "The username must be at least one character and the first character must be a letter.  The remaining characters must be letters, numbers, or underscores."
  }
}

variable "performance_insights" {
  default     = {}
  description = "Configures the Performance Insights data retention period and, optionally, its encryption key.  If the kms_key_arn attribute is null, the key provided in the kms_encryption_key_alias variable is used to encrypt the Performance Insights data."
  nullable    = false
  type = object({
    retention_period = optional(number, 7)
    kms_key_arn      = optional(string)
  })

  validation {
    condition     = var.performance_insights.retention_period == 7 || (var.performance_insights.retention_period % 31) == 0
    error_message = "The Performance Insights retention period must be equal to 7 or a multiple of 31."
  }

  validation {
    condition     = 0 < var.performance_insights.retention_period
    error_message = "The Performance Insights retention period must be greater than zero."
  }

  validation {
    condition     = var.performance_insights.retention_period <= (23 * 31)
    error_message = "The Performance Insights retention period must be less than or equal to 731 days."
  }
}

variable "prefix_list_ingress_rules" {
  default     = {}
  description = "A map of whose entries define the prefix list ingress rules on the instance's security group.  The keys are the prefix list IDs and the entries are the rule's description."
  nullable    = false
  type        = map(string)

  validation {
    condition     = alltrue([for description in values(var.prefix_list_ingress_rules) : length(description) <= 255])
    error_message = "One or more of the values exceeds the maximum description length of 255 characters."
  }

  validation {
    condition     = alltrue([for description in values(var.prefix_list_ingress_rules) : can(regex("^[a-zA-Z0-9 ._\\-:/()#,@\\[\\]+=;{}!$]*$", description))])
    error_message = "One or more of the values contains characters disallowed in security group descriptions.  For details, see https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/security-group-rules.html"
  }
}

variable "read_iops_alarm" {
  default     = {}
  description = "An object whose attributes customize the CloudWatch alarm monitoring the instance's  ReadIOPS metric.  The threshold is the percentage of the instance's baseline IOPS the read IOPS are consuming."
  nullable    = false
  type = object({
    alarm_actions             = optional(set(string), [])
    all_actions               = optional(set(string), [])
    enabled                   = optional(bool)
    evaluation_periods        = optional(number, 10),
    insufficient_data_actions = optional(set(string), [])
    ok_actions                = optional(set(string), [])
    period                    = optional(number, 30)
    threshold                 = optional(number, 75)
  })

  validation {
    condition     = 0 < var.read_iops_alarm.threshold && var.read_iops_alarm.threshold <= 100
    error_message = "The threshold must be greater than zero and less than or equal to 100."
  }
}

variable "route53_records" {
  default     = {}
  description = "An optional variable to create CNAME records for the instance's hostname in the specified Route53 zone."
  nullable    = false
  type = object({
    zone_id = optional(string)
    names   = optional(set(string), [])
  })

  validation {
    condition     = 0 < length(var.route53_records.names) ? can(regex("^[A-Z0-9]+$", var.route53_records.zone_id)) : var.route53_records.zone_id == null
    error_message = "A Route53 zone ID is required if the set of names contains values."
  }
}

variable "source_snapshot" {
  default     = null
  description = "An object containing the attributes of an RDS snaphot to use as the starting point of the instance's storage."
  nullable    = true
  type = object({
    allocated_storage      = number
    db_snapshot_identifier = string
    engine                 = string
    engine_version         = string
    kms_key_id             = string
  })
}

variable "subnet_group_name" {
  description = "The name of the RDS subnet group where the instance will run."
  nullable    = false
  type        = string
}

variable "source_security_group_ingress_rules" {
  default     = {}
  description = "A map of whose entries define the source security group ingress rules on the instance's security group.  The keys are the security group IDs and the entries are the rule's description."
  nullable    = false
  type        = map(string)

  validation {
    condition     = alltrue([for id in keys(var.source_security_group_ingress_rules) : can(regex("^sg-[0-9a-f]+$", id))])
    error_message = "One or more of the keys is not a syntactically valid security group ID."
  }


  validation {
    condition     = alltrue([for description in values(var.source_security_group_ingress_rules) : length(description) <= 255])
    error_message = "One or more of the values exceeds the maximum description length of 255 characters."
  }

  validation {
    condition     = alltrue([for description in values(var.source_security_group_ingress_rules) : can(regex("^[a-zA-Z0-9 ._\\-:/()#,@\\[\\]+=;{}!$]*$", description))])
    error_message = "One or more of the values contains characters disallowed in security group descriptions.  For details, see https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/security-group-rules.html"
  }
}

variable "storage" {
  default     = {}
  description = <<-EOF
  Configures the volume of the instance.  Only EBS storage is supported.

  The allocated attribute is the minimum storage of the volume.  Defaults to 20GB.
  The maximum attribute is the maximum allocatable storage allowed.  If unset, the instance's maximum will be double the value of the allocated attribute to enable auto scaling.
  The type attribute configures the EBS volume type.  It must be either gp2 or gp3 (the default).
  EOF
  nullable    = false
  type = object({
    allocated = optional(number, 20)
    maximum   = optional(number)
    type      = optional(string, "gp3")
  })

  validation {
    condition     = 20 <= var.storage.allocated
    error_message = "The allocated storage must be greater than or equal to 20."
  }

  validation {
    condition     = var.storage.allocated <= 65536
    error_message = "The allocated storage must be less than or equal to 65,536."
  }

  validation {
    condition     = try(20 <= var.storage.maximum, var.storage.maximum == null)
    error_message = "The maximum storage, if specified, must be greater than or equal to 20."
  }

  validation {
    condition     = try(var.storage.maximum <= 65536, var.storage.maximum == null)
    error_message = "The maximum storage, if specified, must be less than or equal to 65,536."
  }

  validation {
    condition     = try(var.storage.allocated <= var.storage.maximum, var.storage.maximum == null)
    error_message = "The maximum storage must be greater than or equal to the allocated storage if it is specified."
  }

  validation {
    condition     = contains(["gp3", "gp2"], var.storage.type)
    error_message = "The storage type must be either gp2 or gp3"
  }
}

variable "tags" {
  default     = {}
  description = "A set of AWS tags to apply to every resource in the module"
  nullable    = false
  type        = map(string)
}

variable "write_iops_alarm" {
  default     = {}
  description = "An object whose attributes customize the CloudWatch alarm monitoring the instance's  WriteIOPS metric.  The threshold is the percentage of the instance's baseline IOPS the write IOPS are consuming."
  nullable    = false
  type = object({
    alarm_actions             = optional(set(string), [])
    all_actions               = optional(set(string), [])
    enabled                   = optional(bool)
    evaluation_periods        = optional(number, 10),
    insufficient_data_actions = optional(set(string), [])
    ok_actions                = optional(set(string), [])
    period                    = optional(number, 30)
    threshold                 = optional(number, 75)
  })

  validation {
    condition     = 0 < var.write_iops_alarm.threshold && var.write_iops_alarm.threshold <= 100
    error_message = "The threshold must be greater than zero and less than or equal to 100."
  }
}
