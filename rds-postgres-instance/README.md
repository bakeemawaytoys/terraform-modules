# RDS PosgreSQL Instance

## Overview

A module to manage RDS database instances running the PostgreSQL engine.  The module also manages related resources that, together with the instance, constitute the logical model of an RDS database.  The related resources include a security group, a parameter group, and CloudWatch log groups.  The module is designed to enforce best-practices, catch invalid RDS configuration combinations, and limit the configuration variation among RDS instances.

The module enforces the following standards.

* Storage is encrypted.
* Performance Insights is always enabled.
* Enhanced metrics are always enabled.
* The instance has its own security group.
* The instance has its own IAM role.
* The instance has its own parameter group.
* The instance runs the PostgreSQL engine.
* The instance will create a final snapshot when it is deleted.
* Deletion protection is enabled by default.
* The instance has a standard set of CloudWatch alarms.
* The master user's password is managed by RDS in Secrets Manager.
* Storage autoscaling is enabled by default.
* The instance uses EBS volumes for storage.

## Usage

### Configuration

#### PostgreSQL Engine

The instance uses the version of of the PostgreSQL engine specified in the `engine_version` variable.  The variable accepts either a specific major-minor version or just a major version.  If a major-minor version is set, then automatic minor version upgrades are disabled on the instance.  This allows the version to be pinned to a specific version while avoiding drift that would occur after an automatic upgrade.  The module supports major versions 13, 14, and 15.

#### Storage

The `storage` variable controls the size and type of the instance's EBS volume.  The default type is the newer `gp3`.  The older `gp2` can be specified to support importing existing instances into Terraform.  The module does not set a default value for the maximum storage capacity.  Instead, it set the maximum storage capacity to double the allocated storage to [enable storage autoscaling](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PIOPS.StorageTypes.html#USER_PIOPS.Autoscaling) by default.  Autoscaling can be disabled by specifying the maximum storage equal to the allocated storage.  Storage encryption is enforced by the module.  The storage encryption key is specified using the `kms_encryption_key_alias` variable.

#### Networking

A VPC security group is created by the module and attached to the instance.  The intent is that the security group is only used by the instance and, ideally, the only security group attached to the instance.  The rationale behind this is to reduce accidentally opening connectivity to the instance by sharing security groups.  However, to support migrating existing instances to this module, the `additional_security_group_ids` variable is provided for attaching additional security groups.  The module's security group ingress rules are defined by the `ipv4_cidr_block_ingress_rules`, `prefix_list_ingress_rules`, and `source_security_group_ingress_rules` variables.  Egress rules are only added to the security group by the module when certain RDS features are enabled.

##### Master User

The module requires that the master user's password for new database instances is [managed by RDS](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-secrets-manager.html).  It does not provide a way to set the password when an instance is created so that the password is never in the Terraform state file.  The password management feature can be disabled in the following scenarios.

1. The instance has been imported into Terraform because it was created outside of Terraform.  The password is already set prior to the induction of Terraform.
1. The instance is [restored from a snapshot](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_RestoreFromSnapshot.html).  The password is already set in the snapshot.

##### Lambda Integration

[Lambda integration](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/PostgreSQL-Lambda.html) is configured with the `lambda_integration` variable.  If the `function_arns` attribute of the variable is non-empty, the module makes the following changes [as described in the RDS documentation](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/PostgreSQL-Lambda.html).

* It enables the [custom DNS option](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Appendix.PostgreSQL.CommonDBATasks.CustomDNS.html) in the parameter group.
* Egress rules are added to the instance's security group to allow DNS queries using the VPC's [the Amazon DNS server](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-dns.html#AmazonDNS).
* It adds an HTTPS egress rule for the security group specified in the variable's `vpc_endpoint_security_group_id` attribute.  The security group must be attached to [an interface VPC endpoint for the Lambda API](https://docs.aws.amazon.com/lambda/latest/dg/configuration-vpc-endpoints.html).
* An inline policy is attached to the instance's IAM granting it permission to execute the functions.

The changes will be undone if the `function_arns` is set to empty list.  The module does not install the `aws_lambda` PostgreSQL extension.

##### Monitoring

Enhanced monitoring and Performance Insights are both enabled by the module.  The Performance Insights are encrypted with either the KMS key specified in the `performance_insights` variable or, by default, the `kms_encryption_key_alias` variable.  The `performance_insights` variable also supports customization of the retention period.  Six CloudWatch alarms are included in the module to ensure instances have a consistent set of alarms.  The alarms monitor the CPUUtilization, DiskQueueDepth, FreeableMemory, FreeStorageSpace, ReadIOPS, and WriteIOPS metrics.  Alarm actions are configured for all of the alarms using the `global_alarm_actions`.  Additional actions can be set for individual alarms using the alarm's corresponding variable.  The actions can also be enabled or disabled using the same variables.

Log exports are automatically enabled for all exportable log types supported by the PostgreSQL engine.  The target CloudWatch log groups are managed by the module.  They are created prior to the instance to ensure RDS doesn't create them.

### Restoring From a Snapshot

To use the module when restoring from an RDS snapshot, use the `source_snapshot_identifier` to specify the name of the snapshot.  When restoring from a snapshot, the `master_user.username`, `engine_version`, `kms_encryption_key_alias`, and `allocated_storage` variables must all have the same values as those of the snapshot.  These are all requirements of RDS.  The module uses [Terraform post-conditions](https://developer.hashicorp.com/terraform/language/expressions/custom-conditions#preconditions-and-postconditions) to enforce as many of these requirements as possible at plan time.  Ideally, the `instance_parameters` are also contains the same customizations as the snapshot's parameter group but that is not currently possible to do with Terraform.  Once the instance has been created, the `source_snapshot_identifier` can be set to null.  The restoration requirements will no longer be enforced by the module and variables, such as the `allocated_storage`, can be customized.

## Future Improvements

* Enforcing TLS connections
* Enforcing instance identifier naming conventions
* Adding support for S3 imports and exports
* Support for IPv6
* Dynamic configuration of the CloudWatch thresholds
* Standardizing additional parameter group settings.

## Limitations and Assumptions

* The module does not support multi-AZ deployments.  Use an Aurora cluster for multi-AZ deployments.
* All resources, including KMS keys and snapshots are assumed to be in the same region and in the same account.
* The module enforces storage encryption and, therefore, cannot be used to manage existing instances that are unencrypted.
* EBS is the only type of volume supported.
* The module does not manage any resources within the PostgreSQL engine.
* Read-only replicas cannot be created with this module.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.4 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.63 |
| <a name="requirement_time"></a> [time](#requirement\_time) | ~> 0.9 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.63 |
| <a name="provider_time"></a> [time](#provider\_time) | ~> 0.9 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.database](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_metric_alarm.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_db_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance) | resource |
| [aws_db_instance_role_association.lambda_integration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance_role_association) | resource |
| [aws_db_parameter_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_parameter_group) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_route53_record.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.dns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.foreign_data_wrapper](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.lambda_integration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.ipv4_cidr_block](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.prefix_list](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [time_static.final_snapshot_suffix](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/static) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_db_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/db_subnet_group) | data source |
| [aws_ec2_instance_type.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ec2_instance_type) | data source |
| [aws_iam_policy_document.lambda_integration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.trust_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_kms_alias.rds](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/kms_alias) | data source |
| [aws_rds_engine_version.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/rds_engine_version) | data source |
| [aws_rds_orderable_db_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/rds_orderable_db_instance) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_security_group_ids"></a> [additional\_security\_group\_ids](#input\_additional\_security\_group\_ids) | The identifiers of security groups to attach to the instance in addition to the security group managed by this module. | `set(string)` | `[]` | no |
| <a name="input_backup_retention_period"></a> [backup\_retention\_period](#input\_backup\_retention\_period) | The number of days an automatic backup will be retained | `number` | `7` | no |
| <a name="input_backup_window"></a> [backup\_window](#input\_backup\_window) | Configures the preferred window for the creation of automated snapshots. | `string` | `"08:00-09:00"` | no |
| <a name="input_ca_cert_identifier"></a> [ca\_cert\_identifier](#input\_ca\_cert\_identifier) | The identifier of the RDS certificate authority certificate to use to sign the instance's certificate. | `string` | `"rds-ca-rsa4096-g1"` | no |
| <a name="input_cloudwatch_log_retention_period"></a> [cloudwatch\_log\_retention\_period](#input\_cloudwatch\_log\_retention\_period) | The number of days to retain log events in the CloudWatch log groups.  Defaults to one year. | `number` | `365` | no |
| <a name="input_cpu_utilization_alarm"></a> [cpu\_utilization\_alarm](#input\_cpu\_utilization\_alarm) | An object whose attributes customize the CloudWatch alarm monitoring the instance's CPUUtilization metric.  The threshold is a percentage of the CPU utilization. | <pre>object({<br>    alarm_actions             = optional(set(string), [])<br>    all_actions               = optional(set(string), [])<br>    enabled                   = optional(bool)<br>    evaluation_periods        = optional(number, 4),<br>    insufficient_data_actions = optional(set(string), [])<br>    ok_actions                = optional(set(string), [])<br>    period                    = optional(number, 30)<br>    threshold                 = optional(number, 90)<br>  })</pre> | `{}` | no |
| <a name="input_db_name"></a> [db\_name](#input\_db\_name) | The name of the database to create when the DB instance is created. If this parameter is not null, no database is created in the DB instance. | `string` | `null` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Enables or disables deletion protection on the instance.  Defaults to enabled. | `bool` | `true` | no |
| <a name="input_disk_queue_depth_alarm"></a> [disk\_queue\_depth\_alarm](#input\_disk\_queue\_depth\_alarm) | An object whose attributes customize the CloudWatch alarm monitoring the instance's DiskQueueDepth metric. | <pre>object({<br>    alarm_actions             = optional(set(string), [])<br>    all_actions               = optional(set(string), [])<br>    enabled                   = optional(bool)<br>    evaluation_periods        = optional(number, 2),<br>    insufficient_data_actions = optional(set(string), [])<br>    ok_actions                = optional(set(string), [])<br>    period                    = optional(number, 30)<br>    threshold                 = optional(number, 1)<br>  })</pre> | `{}` | no |
| <a name="input_engine_version"></a> [engine\_version](#input\_engine\_version) | The version of the PostgreSQL engine running in the instance.  The major version must be specified.  The minor version<br>is optional.  If the minor version is set, automatic minor upgrades will be disabled to pin the instance to that version.<br>The major version must be set to 13, 14, or 15.  The default is 14. | `string` | `"14"` | no |
| <a name="input_foreign_data_wrapper_security_group_egress_rules"></a> [foreign\_data\_wrapper\_security\_group\_egress\_rules](#input\_foreign\_data\_wrapper\_security\_group\_egress\_rules) | A map of whose entries define the port 5432 security group egress rules on the instance's security group.  The referenced security groups<br>are attached to other RDS PostgreSQL instances that are configured as targets for Postgres foreign data wrappers in this instance.<br>The keys in the map are the target instances' security group IDs and the entries are the rule's description. | `map(string)` | `{}` | no |
| <a name="input_freeable_memory_alarm"></a> [freeable\_memory\_alarm](#input\_freeable\_memory\_alarm) | An object whose attributes customize the CloudWatch alarm monitoring the instance's FreeableMemory metric.  The threshold is a percentage of the instance's total memory. | <pre>object({<br>    alarm_actions             = optional(set(string), [])<br>    all_actions               = optional(set(string), [])<br>    enabled                   = optional(bool)<br>    evaluation_periods        = optional(number, 10),<br>    insufficient_data_actions = optional(set(string), [])<br>    ok_actions                = optional(set(string), [])<br>    period                    = optional(number, 30)<br>    threshold                 = optional(number, 10)<br>  })</pre> | `{}` | no |
| <a name="input_freeable_storage_alarm"></a> [freeable\_storage\_alarm](#input\_freeable\_storage\_alarm) | An object whose attributes customize the CloudWatch alarm monitoring the instance's FreeableStorage metric.  The threshold is a percentage of the instance's maximum allocatable storage space. | <pre>object({<br>    alarm_actions             = optional(set(string), [])<br>    all_actions               = optional(set(string), [])<br>    enabled                   = optional(bool)<br>    evaluation_periods        = optional(number, 10),<br>    insufficient_data_actions = optional(set(string), [])<br>    ok_actions                = optional(set(string), [])<br>    period                    = optional(number, 60)<br>    threshold                 = optional(number, 10)<br>  })</pre> | `{}` | no |
| <a name="input_global_alarm_actions"></a> [global\_alarm\_actions](#input\_global\_alarm\_actions) | An object whose attributes are sets of ARNs for the resources that are used as the actions on all<br>CloudWatch alarms.  The `all_actions` attribute contains actions used on all types of actions<br>supported by alarms.  The `enabled` attribute enables or disables actions on all alarms in the<br>module unless the `enabled` attribute on the alarm's corresponding variable is set. | <pre>object({<br>    alarm_actions             = optional(set(string), [])<br>    all_actions               = optional(set(string), [])<br>    enabled                   = optional(bool, true)<br>    insufficient_data_actions = optional(set(string), [])<br>    ok_actions                = optional(set(string), [])<br>  })</pre> | `{}` | no |
| <a name="input_identifier"></a> [identifier](#input\_identifier) | The identifier (name) of the instance. | `string` | n/a | yes |
| <a name="input_instance_class"></a> [instance\_class](#input\_instance\_class) | The type of instance the database engine will run on. | `string` | `"db.t3.micro"` | no |
| <a name="input_instance_parameters"></a> [instance\_parameters](#input\_instance\_parameters) | Customizes parameters in the instances parameters group. | <pre>list(<br>    object({<br>      apply_method = optional(string, "immediate")<br>      name         = string<br>      value        = string<br>      }<br>  ))</pre> | `[]` | no |
| <a name="input_ipv4_cidr_block_ingress_rules"></a> [ipv4\_cidr\_block\_ingress\_rules](#input\_ipv4\_cidr\_block\_ingress\_rules) | A map of whose entries define the IPv4 CIDR block ingress rules on the instance's security group.  The keys are the CIDR blocks and the entries are the rule's description. | `map(string)` | `{}` | no |
| <a name="input_kms_encryption_key_alias"></a> [kms\_encryption\_key\_alias](#input\_kms\_encryption\_key\_alias) | The alias of the KMS key to use for encryption of both the instance and, unless one is specified in the performance\_insights varible, the instance's Performance Insights data. | `string` | `"alias/aws/rds"` | no |
| <a name="input_lambda_integration"></a> [lambda\_integration](#input\_lambda\_integration) | An optional object to configure the IAM role and security group permissions required to allow the instance to invoke Lambda functions. | <pre>object({<br>    function_arns                  = optional(set(string), [])<br>    vpc_endpoint_security_group_id = optional(string)<br>  })</pre> | `{}` | no |
| <a name="input_maintenance_window"></a> [maintenance\_window](#input\_maintenance\_window) | The window when RDS will perform automated maintenance. | `string` | `"mon:10:00-mon:11:00"` | no |
| <a name="input_master_user"></a> [master\_user](#input\_master\_user) | Configures the master user created in the database by RDS. | <pre>object({<br>    username        = optional(string, "rdsadministrator")<br>    manage_password = optional(bool, true)<br>  })</pre> | `{}` | no |
| <a name="input_multi_az_enabled"></a> [multi\_az\_enabled](#input\_multi\_az\_enabled) | Determines if AWS creates a hot-standby replica in a separate availabilty zone. | `bool` | `false` | no |
| <a name="input_performance_insights"></a> [performance\_insights](#input\_performance\_insights) | Configures the Performance Insights data retention period and, optionally, its encryption key.  If the kms\_key\_arn attribute is null, the key provided in the kms\_encryption\_key\_alias variable is used to encrypt the Performance Insights data. | <pre>object({<br>    retention_period = optional(number, 7)<br>    kms_key_arn      = optional(string)<br>  })</pre> | `{}` | no |
| <a name="input_prefix_list_ingress_rules"></a> [prefix\_list\_ingress\_rules](#input\_prefix\_list\_ingress\_rules) | A map of whose entries define the prefix list ingress rules on the instance's security group.  The keys are the prefix list IDs and the entries are the rule's description. | `map(string)` | `{}` | no |
| <a name="input_read_iops_alarm"></a> [read\_iops\_alarm](#input\_read\_iops\_alarm) | An object whose attributes customize the CloudWatch alarm monitoring the instance's  ReadIOPS metric.  The threshold is the percentage of the instance's baseline IOPS the read IOPS are consuming. | <pre>object({<br>    alarm_actions             = optional(set(string), [])<br>    all_actions               = optional(set(string), [])<br>    enabled                   = optional(bool)<br>    evaluation_periods        = optional(number, 10),<br>    insufficient_data_actions = optional(set(string), [])<br>    ok_actions                = optional(set(string), [])<br>    period                    = optional(number, 30)<br>    threshold                 = optional(number, 75)<br>  })</pre> | `{}` | no |
| <a name="input_route53_records"></a> [route53\_records](#input\_route53\_records) | An optional variable to create CNAME records for the instance's hostname in the specified Route53 zone. | <pre>object({<br>    zone_id = optional(string)<br>    names   = optional(set(string), [])<br>  })</pre> | `{}` | no |
| <a name="input_source_security_group_ingress_rules"></a> [source\_security\_group\_ingress\_rules](#input\_source\_security\_group\_ingress\_rules) | A map of whose entries define the source security group ingress rules on the instance's security group.  The keys are the security group IDs and the entries are the rule's description. | `map(string)` | `{}` | no |
| <a name="input_source_snapshot"></a> [source\_snapshot](#input\_source\_snapshot) | An object containing the attributes of an RDS snaphot to use as the starting point of the instance's storage. | <pre>object({<br>    allocated_storage      = number<br>    db_snapshot_identifier = string<br>    engine                 = string<br>    engine_version         = string<br>    kms_key_id             = string<br>  })</pre> | `null` | no |
| <a name="input_storage"></a> [storage](#input\_storage) | Configures the volume of the instance.  Only EBS storage is supported.<br><br>The allocated attribute is the minimum storage of the volume.  Defaults to 20GB.<br>The maximum attribute is the maximum allocatable storage allowed.  If unset, the instance's maximum will be double the value of the allocated attribute to enable auto scaling.<br>The type attribute configures the EBS volume type.  It must be either gp2 or gp3 (the default). | <pre>object({<br>    allocated = optional(number, 20)<br>    maximum   = optional(number)<br>    type      = optional(string, "gp3")<br>  })</pre> | `{}` | no |
| <a name="input_subnet_group_name"></a> [subnet\_group\_name](#input\_subnet\_group\_name) | The name of the RDS subnet group where the instance will run. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A set of AWS tags to apply to every resource in the module | `map(string)` | `{}` | no |
| <a name="input_write_iops_alarm"></a> [write\_iops\_alarm](#input\_write\_iops\_alarm) | An object whose attributes customize the CloudWatch alarm monitoring the instance's  WriteIOPS metric.  The threshold is the percentage of the instance's baseline IOPS the write IOPS are consuming. | <pre>object({<br>    alarm_actions             = optional(set(string), [])<br>    all_actions               = optional(set(string), [])<br>    enabled                   = optional(bool)<br>    evaluation_periods        = optional(number, 10),<br>    insufficient_data_actions = optional(set(string), [])<br>    ok_actions                = optional(set(string), [])<br>    period                    = optional(number, 30)<br>    threshold                 = optional(number, 75)<br>  })</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_address"></a> [address](#output\_address) | The generated hostname of the instance |
| <a name="output_allocated_storage"></a> [allocated\_storage](#output\_allocated\_storage) | The instance's allocated storage. |
| <a name="output_backup_retention_period"></a> [backup\_retention\_period](#output\_backup\_retention\_period) | The instance's backup retention period. |
| <a name="output_ca_cert_identifier"></a> [ca\_cert\_identifier](#output\_ca\_cert\_identifier) | The identifer of the certificate authority's root certificate used to generate the instance's certificate. |
| <a name="output_cpu_utilization_alarm_arn"></a> [cpu\_utilization\_alarm\_arn](#output\_cpu\_utilization\_alarm\_arn) | The ARN of the CloudWatch alarm that monitors the instance's CPUUtilization metric. |
| <a name="output_db_instance_identifier"></a> [db\_instance\_identifier](#output\_db\_instance\_identifier) | The instance's identifier.  An alias of the identifier output. |
| <a name="output_disk_queue_depth_alarm_arn"></a> [disk\_queue\_depth\_alarm\_arn](#output\_disk\_queue\_depth\_alarm\_arn) | The ARN of the CloudWatch alarm that monitors the instance's DiskQueueDepth metric. |
| <a name="output_engine"></a> [engine](#output\_engine) | The database engine running in the instance. |
| <a name="output_engine_version"></a> [engine\_version](#output\_engine\_version) | The verison of the database engine running in the instance. |
| <a name="output_final_snapshot_identifier"></a> [final\_snapshot\_identifier](#output\_final\_snapshot\_identifier) | The name of the final snapshot created when the instance is destroyed. |
| <a name="output_freeable_memory_alarm_arn"></a> [freeable\_memory\_alarm\_arn](#output\_freeable\_memory\_alarm\_arn) | The ARN of the CloudWatch alarm that monitors the instance's FreeableMemory metric. |
| <a name="output_freeable_storage_alarm_arn"></a> [freeable\_storage\_alarm\_arn](#output\_freeable\_storage\_alarm\_arn) | The ARN of the CloudWatch alarm that monitors the instance's FreeStorageSpace metric. |
| <a name="output_iam_role_arn"></a> [iam\_role\_arn](#output\_iam\_role\_arn) | The ARN of the IAM role assumed by the instance. |
| <a name="output_iam_role_name"></a> [iam\_role\_name](#output\_iam\_role\_name) | The name of the IAM role assumed by the instance. |
| <a name="output_identifier"></a> [identifier](#output\_identifier) | The identifier of the instance. |
| <a name="output_kms_key_id"></a> [kms\_key\_id](#output\_kms\_key\_id) | The ARN of the KMS key used to encrypt the instance's storage. |
| <a name="output_master_user_secret_arn"></a> [master\_user\_secret\_arn](#output\_master\_user\_secret\_arn) | The ARN of the Secrets Manager secret that contains the master user's password or null if RDS does not manage the password. |
| <a name="output_master_username"></a> [master\_username](#output\_master\_username) | The username of the database engine's master user. |
| <a name="output_port"></a> [port](#output\_port) | The port number the instance listens on for client connections. |
| <a name="output_preferred_backup_window"></a> [preferred\_backup\_window](#output\_preferred\_backup\_window) | The window of time when RDS takes automated snapshots of the instance. |
| <a name="output_read_iops_alarm_arn"></a> [read\_iops\_alarm\_arn](#output\_read\_iops\_alarm\_arn) | The ARN of the CloudWatch alarm that monitors the instance's ReadIOPS metric. |
| <a name="output_resource_id"></a> [resource\_id](#output\_resource\_id) | The unique resource identifier of the instance. |
| <a name="output_security_group_arn"></a> [security\_group\_arn](#output\_security\_group\_arn) | The ARN of the security group managed by this module. |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | The identifier of the security group managed by this module. |
| <a name="output_write_iops_alarm_arn"></a> [write\_iops\_alarm\_arn](#output\_write\_iops\_alarm\_arn) | The ARN of the CloudWatch alarm that monitors the instance's WriteIOPS metric. |
<!-- END_TF_DOCS -->