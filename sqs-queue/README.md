# AWS SQS Queue

## Overview

A Terraform module for standardizing and simplifying the management of AWS SQS queues.  In addition to creating a queue, the module creates a dead-letter queue and CloudWatch alarms for both queues.  The dead-letter queue is optional and its creation can be controlled with the `dead_letter_queue` variable.  Both standard and FIFO queues are supported by the module.  The default behavior is to create a standard queue.  The CloudWatch alarms monitor the queue depth using the `ApproximateNumberOfMessagesVisible` metric and the age of the oldest message using the `ApproximateAgeOfOldestMessage` metric.  The alarm settings can be tuned with the `cloudwatch_alarms` variable.  If the dead-letter queue is created, its alarms share the settings of the primary queue's alarms.

## Naming Conventions

By default, the module assumes that one AWS account corresponds to one deployment environment.  To support AWS accounts that contain multiple deployment environments, the optional `environment` variable can be used to include the environment short name the suffix of the queue name(s).  The variable does not support the production short name (prod) to minimize the use of environment-scoped names as well as to establish that when moving to a multi-account setup, the production configuration of an application is the one that should be used for lower environments as well.   To allow the module to be used with existing queues that don't follow the naming convention established by this module, the validation on the `name` variable does not enforce the the use of the `environment` variable.

The name of the dead-letter queue is the name of the primary queue with the `-dlq` suffix.  When the environment short name is included in the primary queue's name, the `-dlq` suffix appears after the short name.

## Limitations and Assumptions

* The module does not support server-side encryption using a KMS CMK.
* The module does not currently support configuring all available attributes on the dead-letter queue.
* The dead-letter queue's CloudWatch alarms cannot be configured independently of the primary queue's alarm.
* The only AWS services that can be granted permission to write to the queue are S3, SNS, and EventBridge.
* The module does not support limiting access to the queue by using deny statements on the queue's policy.
* The primary queue cannot be used as a dead-letter queue.
* The primary queue can only use the dead-letter queue created by this module as its dead-letter queue.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.9 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.50 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.50 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_alarms"></a> [alarms](#module\_alarms) | ./modules/alarms | n/a |
| <a name="module_dlq_alarms"></a> [dlq\_alarms](#module\_dlq\_alarms) | ./modules/alarms | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_sqs_queue.dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue_policy.dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_policy) | resource |
| [aws_sqs_queue_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_policy) | resource |
| [aws_sqs_queue_redrive_allow_policy.dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_redrive_allow_policy) | resource |
| [aws_sqs_queue_redrive_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_redrive_policy) | resource |
| [aws_iam_policy_document.dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_service_message_producers"></a> [aws\_service\_message\_producers](#input\_aws\_service\_message\_producers) | An object whose attributes defines the AWS services (and their corresponding resources) that are granted permission to write to the queue.<br><br>The 'events' attributes defines the EventBridge rules that are permitted to use the queue as a target.<br>The 'sns' attribute defines the SNS topics whose subscriptions can include the queue. | <pre>object({<br>    events = optional(set(string), [])<br>    s3     = optional(set(string), [])<br>    sns    = optional(set(string), [])<br>  })</pre> | `{}` | no |
| <a name="input_cloudwatch_alarms"></a> [cloudwatch\_alarms](#input\_cloudwatch\_alarms) | Configures the CloudWatch alarms managed by the module.<br>The 'actions' attribute is an optional list of ARNs for all alarm actions.<br>The 'queue\_depth\_alarm' configures the alarm that triggers if messages aren't being consumed from the queue.<br>The `message_age_alarm` configures the alarm that triggers if the oldest message is older than the threshold.  The alarm is required by Vanta. | <pre>object(<br>    {<br>      actions = optional(list(string), [])<br>      queue_depth_alarm = optional(object({<br>        actions_enabled    = optional(bool, true)<br>        evaluation_periods = optional(number, 2)<br>        period             = optional(number, 60)<br>        threshold          = optional(number, 1)<br>      }), {})<br>      message_age_alarm = optional(object({<br>        actions_enabled    = optional(bool, true)<br>        evaluation_periods = optional(number, 5)<br>        period             = optional(number, 60)<br>        threshold          = optional(number, 5 * 60)<br>      }), {})<br>    }<br>  )</pre> | `{}` | no |
| <a name="input_consumer_role_arns"></a> [consumer\_role\_arns](#input\_consumer\_role\_arns) | A set of ARNs of the IAM roles to include in the queue's policy to grant permission to consume messages from the queue. | `set(string)` | `[]` | no |
| <a name="input_dead_letter_queue"></a> [dead\_letter\_queue](#input\_dead\_letter\_queue) | Configures the attributes of the dead-letter queue. | <pre>object({<br>    enabled            = optional(bool, true)<br>    consumer_role_arns = optional(set(string), [])<br>  })</pre> | `{}` | no |
| <a name="input_delay_seconds"></a> [delay\_seconds](#input\_delay\_seconds) | The time in seconds that the delivery of all messages in the queue will be delayed. | `number` | `0` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | The short name of the environment in which the queue is deployed.  It is optional and should only be set when an AWS account is used for multiple environments.<br>If it is set, the value is included in the name of the queue.  Valid values are 'dev', 'stage', 'uat', or an empty string (the default).  Production (prod) is<br>not included in the valid values to discourage scoping the names of production resources. | `string` | `""` | no |
| <a name="input_fifo_settings"></a> [fifo\_settings](#input\_fifo\_settings) | An object for configuring the queue attributes that only appy to FIFO queues.  The settings are ignored unless the value of the 'type' variable is'fifo'. | <pre>object({<br>    content_based_deduplication = optional(bool, false)<br>    deduplication_scope         = optional(string, "queue")<br>    fifo_throughput_limit       = optional(string, "perQueue")<br>  })</pre> | `{}` | no |
| <a name="input_max_message_size"></a> [max\_message\_size](#input\_max\_message\_size) | The limit of how many kilobytes a message can contain before Amazon SQS rejects it.  The limit is applied to both the queue and its dead-letter queue. | `number` | `256` | no |
| <a name="input_max_receive_count"></a> [max\_receive\_count](#input\_max\_receive\_count) | The maximum number of times a consumer tries receiving a message from a queue without deleting it before being moved to the dead-letter queue. | `number` | `5` | no |
| <a name="input_message_retention_seconds"></a> [message\_retention\_seconds](#input\_message\_retention\_seconds) | The number of seconds messages are retained in the queue. | `number` | `345600` | no |
| <a name="input_name"></a> [name](#input\_name) | The name the queue and the prefix of the dead-letter queue.  The name must be under 65 characters instead of the AWS limit of 80 to account for suffixes appended by the module. | `string` | n/a | yes |
| <a name="input_producer_role_arns"></a> [producer\_role\_arns](#input\_producer\_role\_arns) | A set of ARNs of the IAM roles to include in the queue's policy to grant permission to consume messages from the queue. | `set(string)` | `[]` | no |
| <a name="input_receive_wait_time_seconds"></a> [receive\_wait\_time\_seconds](#input\_receive\_wait\_time\_seconds) | The time for which a ReceiveMessage call will wait for a message to arrive (long polling) before returning | `number` | `0` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | An optional map of AWS tags to attach to every resource created by the module. | `map(string)` | `{}` | no |
| <a name="input_type"></a> [type](#input\_type) | Specifies if the queue is a standard queue or a FIFO queue. | `string` | `"standard"` | no |
| <a name="input_visibility_timeout_seconds"></a> [visibility\_timeout\_seconds](#input\_visibility\_timeout\_seconds) | The period of time during which Amazon SQS prevents other consumers from receiving and processing the message | `number` | `30` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arn"></a> [arn](#output\_arn) | The ARN of the queue. |
| <a name="output_dead_letter_queue"></a> [dead\_letter\_queue](#output\_dead\_letter\_queue) | An object containing the attributes of the dead letter queue resource. |
| <a name="output_dead_letter_queue_arn"></a> [dead\_letter\_queue\_arn](#output\_dead\_letter\_queue\_arn) | The ARN of the dead letter queue. |
| <a name="output_dead_letter_queue_name"></a> [dead\_letter\_queue\_name](#output\_dead\_letter\_queue\_name) | The name of the dead letter queue. |
| <a name="output_dead_letter_queue_url"></a> [dead\_letter\_queue\_url](#output\_dead\_letter\_queue\_url) | The URL of the dead letter queue. |
| <a name="output_message_age_alarm"></a> [message\_age\_alarm](#output\_message\_age\_alarm) | An object containing the attributes of the alarm that triggers when the age of the oldest message breaches the configured threshold. |
| <a name="output_message_age_alarm_arn"></a> [message\_age\_alarm\_arn](#output\_message\_age\_alarm\_arn) | The ARN of the alarm that triggers when the age of the oldest message depth breaches the configured threshold. |
| <a name="output_message_age_alarm_event_pattern"></a> [message\_age\_alarm\_event\_pattern](#output\_message\_age\_alarm\_event\_pattern) | The pattern to use for EventBridge rules that trigger off of the message age alarm. |
| <a name="output_message_age_alarm_name"></a> [message\_age\_alarm\_name](#output\_message\_age\_alarm\_name) | The name of the alarm that triggers when the age of the oldest message breaches the configured threshold. |
| <a name="output_name"></a> [name](#output\_name) | The name of the queue. |
| <a name="output_queue"></a> [queue](#output\_queue) | An object containing the attributes of the queue resource. |
| <a name="output_queue_depth_alarm"></a> [queue\_depth\_alarm](#output\_queue\_depth\_alarm) | An object containing the attributes of the alarm that triggers when the depth of the queue breaches the configured threshold. |
| <a name="output_queue_depth_alarm_arn"></a> [queue\_depth\_alarm\_arn](#output\_queue\_depth\_alarm\_arn) | The ARN of the alarm that triggers when the depth of the queue breaches the configured threshold. |
| <a name="output_queue_depth_alarm_event_pattern"></a> [queue\_depth\_alarm\_event\_pattern](#output\_queue\_depth\_alarm\_event\_pattern) | The pattern to use for EventBridge rules that trigger off of the queue depth alarm. |
| <a name="output_queue_depth_alarm_name"></a> [queue\_depth\_alarm\_name](#output\_queue\_depth\_alarm\_name) | The name of the alarm that triggers when the depth of the queue breaches the configured threshold. |
| <a name="output_url"></a> [url](#output\_url) | The URL of the queue. |
<!-- END_TF_DOCS -->