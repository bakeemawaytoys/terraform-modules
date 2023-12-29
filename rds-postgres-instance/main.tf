terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.63"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
  required_version = ">= 1.4"
}

locals {
  port                      = 5432
  is_restored_from_snapshot = var.source_snapshot != null
  # Convert the list of parameters to a simplify expressions that interrogate specific parameters.
  lambda_integration_resource_count = min(length(var.lambda_integration.function_arns), 1)
  is_lambda_integration_enabled     = 0 < local.lambda_integration_resource_count

  # As of version 4.63.0 of the AWS provider, there is a bug that results in constant drift if the
  # tags argument on the aws_vpc_security_group_egress_rule and aws_vpc_security_group_ingress_rule
  # resources is an empty map.  To avoid this, set it to null instead.
  security_group_rule_tags = length(var.tags) == 0 ? null : var.tags
}

####################################
# IAM Role
####################################
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_iam_policy_document" "trust_policy" {
  statement {
    principals {
      identifiers = [
        # Assumed by the instance for Lambda integration
        "rds.amazonaws.com",
        # Enhanced monitoring
        "monitoring.rds.amazonaws.com"
      ]
      type = "Service"
    }
    actions = ["sts:AssumeRole"]
    # Add conditions to prevent confused deputy problems
    # https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/cross-service-confused-deputy-prevention.html
    condition {
      test     = "StringEquals"
      values   = ["arn:aws:rds:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:db:${var.identifier}"]
      variable = "aws:SourceArn"
    }
    condition {
      test     = "StringEquals"
      values   = [data.aws_caller_identity.current.account_id]
      variable = "aws:SourceAccount"
    }
  }
}

data "aws_iam_policy_document" "lambda_integration" {
  count = local.lambda_integration_resource_count

  statement {
    sid = "LambdaFunction"
    actions = [
      "lambda:InvokeFunction"
    ]
    resources = var.lambda_integration.function_arns
  }
}

resource "aws_iam_role" "this" {
  assume_role_policy = data.aws_iam_policy_document.trust_policy.json
  description        = "Assumed by the ${var.identifier} RDS instance"
  # Due to the 64 character length limit of role names, the instance identifier is included in the path instead of the name
  path        = "/rds/${data.aws_region.current.name}/instances/${var.identifier}/"
  name_prefix = "rds-db-instance-"

  dynamic "inline_policy" {
    for_each = data.aws_iam_policy_document.lambda_integration
    content {
      name   = "lambda-access"
      policy = inline_policy.value.json
    }
  }

  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"]

  lifecycle {
    create_before_destroy = true
  }
}

####################################
# Data Resources
####################################
data "aws_kms_alias" "rds" {
  name = var.kms_encryption_key_alias
}

data "aws_db_subnet_group" "this" {
  name = var.subnet_group_name
}

data "aws_rds_engine_version" "this" {
  default_only = length(split(".", var.engine_version)) < 2
  version      = var.engine_version
  engine       = "postgres"
}

# Look-up the instance class to validate it
data "aws_rds_orderable_db_instance" "this" {
  engine                               = data.aws_rds_engine_version.this.engine
  engine_version                       = data.aws_rds_engine_version.this.version
  instance_class                       = var.instance_class
  storage_type                         = var.storage.type
  supports_enhanced_monitoring         = true
  supports_iam_database_authentication = true
  supports_performance_insights        = true
  supports_storage_encryption          = true

  lifecycle {
    postcondition {
      condition     = self.min_storage_size <= var.storage.allocated
      error_message = "The allocated storage must be greater than or equal to the minimum supported by the instance class."
    }

    postcondition {
      condition     = var.storage.allocated <= self.max_storage_size
      error_message = "The allocated storage must be less than or equal to the maximum value supported by the instanace class."
    }

    postcondition {
      condition     = try(var.storage.maximum <= self.max_storage_size, var.storage.maximum == null)
      error_message = "The maximum storage must be less than or equal to the maximum value supported by the instanace class."
    }
  }
}

locals {
  # Calculate the maximum allocated storage if it isn't set in the variable.  It is set to the smaller of double the allocated storage or the maximum allowed by the storage class.
  maximum_allocated_storage = var.storage.maximum == null ? min(2 * var.storage.allocated, data.aws_rds_orderable_db_instance.this.max_storage_size) : var.storage.maximum
}

####################################
# Parameter Group
####################################
resource "aws_db_parameter_group" "this" {
  description = "Configures the ${var.identifier} instance"
  family      = data.aws_rds_engine_version.this.parameter_group_family
  name_prefix = "${var.identifier}-"

  dynamic "parameter" {
    for_each = var.instance_parameters
    content {
      apply_method = parameter.value.apply_method
      name         = parameter.value.name
      value        = parameter.value.value
    }
  }


  # Automatically enable custom DNS resolution
  dynamic "parameter" {
    for_each = local.is_lambda_integration_enabled ? ["1"] : ["0"]
    content {
      apply_method = "pending-reboot"
      name         = "rds.custom_dns_resolution"
      value        = parameter.value
    }
  }

  # Define parameters for slow query logging
  parameter {
    apply_method = "immediate"
    name         = "log_min_duration_statement"
    value        = "1000" # this value is in milliseconds
  }
  # Set the track_activity_query_size parameter to its maximum value to avoid truncated SQL statements in Performance Insights.
  # https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PerfInsights.UsingDashboard.SQLTextSize.html
  parameter {
    apply_method = "pending-reboot"
    name         = "track_activity_query_size"
    value        = "1048576"
  }

  tags = merge(
    var.tags,
    {
      db_instance_identifier = var.identifier
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}



#############################################
# Security Group
############################################
data "aws_vpc" "this" {
  id = data.aws_db_subnet_group.this.vpc_id
}

resource "aws_security_group" "this" {
  description = "The security group attached to the ${var.identifier} RDS instance."
  name_prefix = "rds-db-${var.identifier}-"

  tags = merge(
    var.tags,
    {
      Name                   = "${var.identifier} RDS instance"
      db_instance_identifier = var.identifier
    }
  )

  vpc_id = data.aws_db_subnet_group.this.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "ipv4_cidr_block" {
  for_each          = var.ipv4_cidr_block_ingress_rules
  cidr_ipv4         = each.key
  description       = each.value
  from_port         = local.port
  ip_protocol       = "tcp"
  to_port           = local.port
  security_group_id = aws_security_group.this.id
  tags              = local.security_group_rule_tags
}

resource "aws_vpc_security_group_ingress_rule" "security_group" {
  for_each                     = var.source_security_group_ingress_rules
  description                  = each.value
  from_port                    = local.port
  ip_protocol                  = "tcp"
  to_port                      = local.port
  referenced_security_group_id = each.key
  security_group_id            = aws_security_group.this.id
  tags                         = local.security_group_rule_tags
}

resource "aws_vpc_security_group_ingress_rule" "prefix_list" {
  for_each          = var.prefix_list_ingress_rules
  description       = each.value
  from_port         = local.port
  ip_protocol       = "tcp"
  to_port           = local.port
  prefix_list_id    = each.key
  security_group_id = aws_security_group.this.id
  tags              = local.security_group_rule_tags
}

resource "aws_vpc_security_group_egress_rule" "foreign_data_wrapper" {
  for_each                     = var.foreign_data_wrapper_security_group_egress_rules
  description                  = each.value
  from_port                    = local.port
  ip_protocol                  = "tcp"
  to_port                      = local.port
  referenced_security_group_id = each.key
  security_group_id            = aws_security_group.this.id
  tags                         = local.security_group_rule_tags
}

resource "aws_cloudwatch_log_group" "database" {
  for_each          = data.aws_rds_engine_version.this.exportable_log_types
  name              = "/aws/rds/instance/${var.identifier}/${each.key}"
  retention_in_days = var.cloudwatch_log_retention_period
  tags              = var.tags
}

# Use instance's creation timestamp as the suffix of the final snapshot to ensure the snapshot has a unique name
# if the instance's identifier is reused.  The triggers are the values that cannot be changed without recreating the instance.
resource "time_static" "final_snapshot_suffix" {
  triggers = {
    db_name                         = coalesce(var.db_name, "not specified")
    instance_identifier             = var.identifier
    kms_encryption_key_alias        = var.kms_encryption_key_alias
    performance_insights_kms_key_id = coalesce(var.performance_insights.kms_key_arn, data.aws_kms_alias.rds.target_key_arn)
    source_snapshot_identifier      = try(var.source_snapshot.db_snapshot_identifier, "not specified")
    username                        = var.master_user.username
  }
}

resource "aws_db_instance" "this" {
  allocated_storage           = local.is_restored_from_snapshot ? null : var.storage.allocated
  allow_major_version_upgrade = true
  apply_immediately           = true

  # Enable automatic minor version upgrades if the minor version was not included in the engine version.
  auto_minor_version_upgrade      = length(split(".", var.engine_version)) < 2
  backup_retention_period         = var.backup_retention_period
  backup_window                   = var.backup_window
  ca_cert_identifier              = var.ca_cert_identifier
  copy_tags_to_snapshot           = true
  db_name                         = local.is_restored_from_snapshot ? null : var.db_name
  db_subnet_group_name            = data.aws_db_subnet_group.this.name
  deletion_protection             = var.deletion_protection
  enabled_cloudwatch_logs_exports = keys(aws_cloudwatch_log_group.database)
  engine                          = data.aws_rds_engine_version.this.engine
  # Use the engine_version variable instead of referencing the aws_rds_engine_version data resource's version attribute so that
  # automatic minor version upgrades don't cause drift when the variable only contains the major version.
  engine_version                        = var.engine_version
  final_snapshot_identifier             = join("-", [var.identifier, "final", time_static.final_snapshot_suffix.unix])
  iam_database_authentication_enabled   = true
  identifier                            = var.identifier
  instance_class                        = data.aws_rds_orderable_db_instance.this.instance_class
  kms_key_id                            = data.aws_kms_alias.rds.target_key_arn
  maintenance_window                    = var.maintenance_window
  manage_master_user_password           = var.master_user.manage_password
  max_allocated_storage                 = local.maximum_allocated_storage
  monitoring_interval                   = 15
  monitoring_role_arn                   = aws_iam_role.this.arn
  multi_az                              = var.multi_az_enabled
  parameter_group_name                  = one(aws_db_parameter_group.this[*].name)
  performance_insights_enabled          = true
  performance_insights_retention_period = var.performance_insights.retention_period
  performance_insights_kms_key_id       = coalesce(var.performance_insights.kms_key_arn, data.aws_kms_alias.rds.target_key_arn)
  port                                  = local.port
  skip_final_snapshot                   = false
  snapshot_identifier                   = try(var.source_snapshot.db_snapshot_identifier, null)
  storage_type                          = var.storage.type
  storage_encrypted                     = true
  tags                                  = var.tags
  username                              = local.is_restored_from_snapshot ? null : var.master_user.username

  vpc_security_group_ids = setunion(
    [
      aws_security_group.this.id,
    ],
    var.additional_security_group_ids,
  )

  lifecycle {
    ignore_changes = [
      # Ignore changes to password
      password,
      snapshot_identifier,
    ]


    precondition {
      condition     = try(var.source_snapshot.engine == data.aws_rds_engine_version.this.engine, var.source_snapshot == null)
      error_message = "The instance's engine must match the snapshot's engine."
    }

    precondition {
      condition     = try(var.source_snapshot.engine_version == data.aws_rds_engine_version.this.version, var.source_snapshot == null)
      error_message = "The instance's engine version must match the snapshot's engine version."
    }

    precondition {
      condition     = try(var.source_snapshot.allocated_storage == var.storage.allocated, var.source_snapshot == null)
      error_message = "The instance's allocated storage must be equal to the snapshot's allocated storage."
    }

    precondition {
      condition     = try(var.source_snapshot.kms_key_id == data.aws_kms_alias.rds.target_key_arn, var.source_snapshot == null)
      error_message = "The instance's KMS encryption key must match the snapshot's KMS encryption key."
    }
  }
}

##########################################################################################################
# Lambda integration
# https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/PostgreSQL-Lambda.html#PostgreSQL-Lambda-network
##########################################################################################################
resource "aws_db_instance_role_association" "lambda_integration" {
  count                  = local.lambda_integration_resource_count
  db_instance_identifier = aws_db_instance.this.identifier
  feature_name           = "Lambda"
  role_arn               = aws_iam_role.this.arn
}

resource "aws_vpc_security_group_egress_rule" "lambda_integration" {
  count = local.lambda_integration_resource_count

  description                  = "Access to the Lambda API to invoke functions"
  from_port                    = 443
  ip_protocol                  = "tcp"
  referenced_security_group_id = var.lambda_integration.vpc_endpoint_security_group_id
  security_group_id            = aws_security_group.this.id
  to_port                      = 443
  tags                         = local.security_group_rule_tags
}

# Allow the instance to send DNS queries to the VPC's DNS resolver.
# https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Appendix.PostgreSQL.CommonDBATasks.CustomDNS.html
resource "aws_vpc_security_group_egress_rule" "dns" {
  for_each = toset(local.is_lambda_integration_enabled ? ["tcp", "udp"] : [])
  # Use the IP address of the VPC's DNS resolver.  https://docs.aws.amazon.com/vpc/latest/userguide/vpc-dns.html#AmazonDNS
  cidr_ipv4         = "${cidrhost(data.aws_vpc.this.cidr_block, 2)}/32"
  description       = "RDS custom DNS resolution over ${upper(each.value)}"
  from_port         = 53
  ip_protocol       = each.value
  to_port           = 53
  security_group_id = aws_security_group.this.id
  tags              = local.security_group_rule_tags
}

#####################
# CloudWatch alarms
####################

# Read the attributes of the instance type so that they can be used to configure the alarm thresholds.
data "aws_ec2_instance_type" "this" {
  instance_type = split("db.", var.instance_class)[1]
}

locals {

  bytes_in_megabytes = pow(2, 20)
  bytes_in_gigabytes = pow(2, 30)

  # The baseline for gp2 IOPS is based on the size of the volume.  This calculation can become out-of-date
  # when storage auto scaling is enabled but it won't matter once all DB instances have
  # been migrated to gp3.
  # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/general-purpose.html#EBSVolumeTypes_gp2
  gp2_baseline_iops = min(max(aws_db_instance.this.allocated_storage * 3, 100), 16000)

  # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/general-purpose.html#gp3-ebs-volume-type
  gp3_baseline_iops = aws_db_instance.this.allocated_storage < 4000 ? 3000 : 12000
  max_iops          = var.storage.type == "gp3" ? local.gp3_baseline_iops : local.gp2_baseline_iops

  common_alarm_actions             = setunion(var.global_alarm_actions.alarm_actions, var.global_alarm_actions.all_actions)
  common_ok_actions                = setunion(var.global_alarm_actions.ok_actions, var.global_alarm_actions.all_actions)
  common_insufficient_data_actions = setunion(var.global_alarm_actions.insufficient_data_actions, var.global_alarm_actions.all_actions)
}

resource "aws_cloudwatch_metric_alarm" "this" {
  for_each = {
    cpu-utilization = {
      actions_enabled           = coalesce(var.cpu_utilization_alarm.enabled, var.global_alarm_actions.enabled)
      alarm_actions             = setunion(var.cpu_utilization_alarm.all_actions, var.cpu_utilization_alarm.alarm_actions)
      comparison_operator       = "GreaterThanThreshold"
      description               = "Alarm when the ${aws_db_instance.this.identifier} RDS instance's CPU utilization exceeds ${var.cpu_utilization_alarm.threshold} percent."
      evaluation_periods        = var.cpu_utilization_alarm.evaluation_periods
      insufficient_data_actions = setunion(var.cpu_utilization_alarm.all_actions, var.cpu_utilization_alarm.insufficient_data_actions)
      metric_name               = "CPUUtilization"
      ok_actions                = setunion(var.cpu_utilization_alarm.all_actions, var.cpu_utilization_alarm.ok_actions)
      period                    = var.cpu_utilization_alarm.period
      threshold                 = var.cpu_utilization_alarm.threshold
    }
    disk-queue-depth = {
      actions_enabled           = coalesce(var.disk_queue_depth_alarm.enabled, var.global_alarm_actions.enabled)
      alarm_actions             = setunion(var.disk_queue_depth_alarm.all_actions, var.disk_queue_depth_alarm.alarm_actions)
      comparison_operator       = "GreaterThanThreshold"
      description               = "Alarm when the number of outstanding I/Os (read/write requests) waiting to access the disk exceeds ${var.disk_queue_depth_alarm.threshold} on the ${aws_db_instance.this.identifier} RDS instance."
      evaluation_periods        = var.disk_queue_depth_alarm.evaluation_periods
      insufficient_data_actions = setunion(var.disk_queue_depth_alarm.all_actions, var.disk_queue_depth_alarm.insufficient_data_actions)
      metric_name               = "DiskQueueDepth"
      ok_actions                = setunion(var.disk_queue_depth_alarm.all_actions, var.disk_queue_depth_alarm.ok_actions)
      period                    = var.disk_queue_depth_alarm.period
      threshold                 = var.disk_queue_depth_alarm.threshold
    }
    freeable-memory = {
      actions_enabled           = coalesce(var.freeable_memory_alarm.enabled, var.global_alarm_actions.enabled)
      alarm_actions             = setunion(var.freeable_memory_alarm.all_actions, var.freeable_memory_alarm.alarm_actions)
      comparison_operator       = "LessThanThreshold"
      description               = "Alarm when freeable memory falls below ${var.freeable_memory_alarm.threshold} percent of the ${aws_db_instance.this.identifier} RDS instance's memory."
      evaluation_periods        = var.freeable_memory_alarm.evaluation_periods
      insufficient_data_actions = setunion(var.freeable_memory_alarm.all_actions, var.freeable_memory_alarm.insufficient_data_actions)
      metric_name               = "FreeableMemory"
      ok_actions                = setunion(var.freeable_memory_alarm.all_actions, var.freeable_memory_alarm.ok_actions)
      period                    = var.freeable_memory_alarm.period
      threshold                 = floor((var.freeable_memory_alarm.threshold / 100) * data.aws_ec2_instance_type.this.memory_size * local.bytes_in_megabytes)
    }
    freeable-storage = {
      actions_enabled           = coalesce(var.freeable_storage_alarm.enabled, var.global_alarm_actions.enabled)
      alarm_actions             = setunion(var.freeable_storage_alarm.all_actions, var.freeable_storage_alarm.alarm_actions)
      comparison_operator       = "LessThanThreshold"
      description               = "Alarm when freeable storage falls below ${var.freeable_storage_alarm.threshold} percent of the ${aws_db_instance.this.identifier} RDS instance's maximum allocatable storage."
      evaluation_periods        = var.freeable_storage_alarm.evaluation_periods
      insufficient_data_actions = setunion(var.freeable_storage_alarm.all_actions, var.freeable_storage_alarm.insufficient_data_actions)
      metric_name               = "FreeStorageSpace"
      ok_actions                = setunion(var.freeable_storage_alarm.all_actions, var.freeable_storage_alarm.ok_actions)
      period                    = var.freeable_storage_alarm.period
      threshold                 = floor((var.freeable_storage_alarm.threshold / 100) * aws_db_instance.this.max_allocated_storage * local.bytes_in_gigabytes)
    }
    read-iops = {
      actions_enabled           = coalesce(var.read_iops_alarm.enabled, var.global_alarm_actions.enabled)
      alarm_actions             = setunion(var.read_iops_alarm.all_actions, var.read_iops_alarm.alarm_actions)
      comparison_operator       = "GreaterThanThreshold"
      description               = "Alarm when the average number of disk read I/O operations per second on the ${aws_db_instance.this.identifier} RDS instance exceeds ${var.read_iops_alarm.threshold} percent of the instance volume's baseline IOPS."
      evaluation_periods        = var.read_iops_alarm.evaluation_periods
      insufficient_data_actions = setunion(var.read_iops_alarm.all_actions, var.read_iops_alarm.insufficient_data_actions)
      metric_name               = "ReadIOPS"
      ok_actions                = setunion(var.read_iops_alarm.all_actions, var.read_iops_alarm.ok_actions)
      period                    = var.read_iops_alarm.period
      threshold                 = floor((var.read_iops_alarm.threshold / 100) * local.max_iops)
    }
    write-iops = {
      actions_enabled           = coalesce(var.write_iops_alarm.enabled, var.global_alarm_actions.enabled)
      alarm_actions             = setunion(var.write_iops_alarm.all_actions, var.write_iops_alarm.alarm_actions)
      comparison_operator       = "GreaterThanThreshold"
      description               = "Alarm when the average number of disk write I/O operations per second on the ${aws_db_instance.this.identifier} RDS instance exceeds ${var.write_iops_alarm.threshold} percent of the instance volume's baseline IOPS."
      evaluation_periods        = var.write_iops_alarm.evaluation_periods
      insufficient_data_actions = setunion(var.write_iops_alarm.all_actions, var.write_iops_alarm.insufficient_data_actions)
      metric_name               = "WriteIOPS"
      ok_actions                = setunion(var.write_iops_alarm.all_actions, var.write_iops_alarm.ok_actions)
      period                    = var.write_iops_alarm.period
      threshold                 = floor((var.write_iops_alarm.threshold / 100) * local.max_iops)
    }
  }

  actions_enabled     = each.value.actions_enabled
  alarm_actions       = setunion(local.common_alarm_actions, each.value.alarm_actions)
  alarm_description   = each.value.description
  alarm_name          = "rds-monitoring-${aws_db_instance.this.identifier}-${each.key}"
  comparison_operator = each.value.comparison_operator
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.this.identifier
  }
  evaluation_periods        = each.value.evaluation_periods
  insufficient_data_actions = setunion(local.common_insufficient_data_actions, each.value.insufficient_data_actions)
  metric_name               = each.value.metric_name
  namespace                 = "AWS/RDS"
  ok_actions                = setunion(local.common_ok_actions, each.value.ok_actions)
  period                    = each.value.period
  statistic                 = "Average"
  threshold                 = each.value.threshold

  tags = merge(
    var.tags,
    {
      db_instance_identifier = var.identifier
    }
  )
}

############################################
# Route53 Records
############################################
resource "aws_route53_record" "this" {
  for_each = var.route53_records.names

  name = each.key
  records = [
    aws_db_instance.this.address
  ]
  # Set this to a log value to allow for quick recovery if the instance is recreated.
  ttl     = 20
  type    = "CNAME"
  zone_id = var.route53_records.zone_id
}
