variable "aws_service_message_producers" {
  default     = {}
  description = <<-EOF
  An object whose attributes defines the AWS services (and their corresponding resources) that are granted permission to write to the queue.

  The 'events' attributes defines the EventBridge rules that are permitted to use the queue as a target.
  The 'sns' attribute defines the SNS topics whose subscriptions can include the queue.
  EOF
  nullable    = false
  type = object({
    events = optional(set(string), [])
    s3     = optional(set(string), [])
    sns    = optional(set(string), [])
  })

  validation {
    condition     = alltrue([for arn in var.aws_service_message_producers.events : can(regex("^arn:aws:events:us-((east)|(west))-[1-9]:[0-9]+:rule/[a-zA-Z0-9\\-_.]{1,64}$", arn))])
    error_message = "One or more of the EventBridge rule ARNs are not syntactically valid."
  }

  validation {
    condition     = alltrue([for arn in var.aws_service_message_producers.s3 : can(regex("^arn:aws:s3:::[a-z0-9\\-.]{3,63}$", arn))])
    error_message = "One or more of the S3 bucket ARNs are not syntactically valid."
  }

  validation {
    condition     = alltrue([for arn in var.aws_service_message_producers.sns : can(regex("^arn:aws:sns:us-((east)|(west))-[1-9]:[0-9]+:[a-zA-Z0-9\\-_]+(.fifo)?$", arn))])
    error_message = "One or more of the SNS topic ARNs are not syntactically valid."
  }
}

variable "cloudwatch_alarms" {
  default     = {}
  description = <<-EOF
  Configures the CloudWatch alarms managed by the module.
  The 'actions' attribute is an optional list of ARNs for all alarm actions.
  The 'queue_depth_alarm' configures the alarm that triggers if messages aren't being consumed from the queue.
  The `message_age_alarm` configures the alarm that triggers if the oldest message is older than the threshold.  The alarm is required by Vanta.
  EOF
  nullable    = false
  type = object(
    {
      actions = optional(list(string), [])
      queue_depth_alarm = optional(object({
        actions_enabled    = optional(bool, true)
        evaluation_periods = optional(number, 2)
        period             = optional(number, 60)
        threshold          = optional(number, 1)
      }), {})
      message_age_alarm = optional(object({
        actions_enabled    = optional(bool, true)
        evaluation_periods = optional(number, 5)
        period             = optional(number, 60)
        threshold          = optional(number, 5 * 60)
      }), {})
    }
  )

  validation {
    condition     = 1 <= var.cloudwatch_alarms.queue_depth_alarm.evaluation_periods
    error_message = "The queue depth alarm's 'evaluation_periods' attribute must be greater than or equal to one."
  }

  validation {
    condition     = 0 < var.cloudwatch_alarms.queue_depth_alarm.period && ((var.cloudwatch_alarms.queue_depth_alarm.period % 60) == 0 || contains([10, 30], var.cloudwatch_alarms.queue_depth_alarm.period))
    error_message = "The queue depth alarm's period must be 10, 30, and any multiple of 60."
  }

  validation {
    condition     = 1 <= var.cloudwatch_alarms.queue_depth_alarm.threshold
    error_message = "The queue depth alarm's threshold must be greater than or equal to one."
  }

  validation {
    condition     = 1 <= var.cloudwatch_alarms.message_age_alarm.evaluation_periods
    error_message = "The message age alarm's 'evaluation_periods' attribute must be greater than or equal to one."
  }

  validation {
    condition     = 0 < var.cloudwatch_alarms.message_age_alarm.period && ((var.cloudwatch_alarms.message_age_alarm.period % 60) == 0 || contains([10, 30], var.cloudwatch_alarms.message_age_alarm.period))
    error_message = "The message age alarm's period must be 10, 30, and any multiple of 60."
  }

  validation {
    condition     = 1 <= var.cloudwatch_alarms.message_age_alarm.threshold
    error_message = "The message age alarm's threshold must be greater than or equal to one."
  }
}

variable "consumer_role_arns" {
  default     = []
  description = "A set of ARNs of the IAM roles to include in the queue's policy to grant permission to consume messages from the queue."
  nullable    = false
  type        = set(string)

  validation {
    condition     = alltrue([for arn in var.consumer_role_arns : can(regex("^arn:aws:iam::[0-9]+:role/[a-zA-Z0-9+=,.@_\\-/]+$", arn))])
    error_message = "One or more of the role ARNs is syntactically incorrect."
  }
}

variable "dead_letter_queue" {
  default     = {}
  description = "Configures the attributes of the dead-letter queue."
  nullable    = false
  type = object({
    enabled            = optional(bool, true)
    consumer_role_arns = optional(set(string), [])
  })

  validation {
    condition     = alltrue([for arn in var.dead_letter_queue.consumer_role_arns : can(regex("^arn:aws:iam::[0-9]+:role/[a-zA-Z0-9+=,.@_\\-/]+$", arn))])
    error_message = "One or more of the consumer role ARNs is syntactically incorrect."
  }
}

variable "delay_seconds" {
  default     = 0
  description = "The time in seconds that the delivery of all messages in the queue will be delayed."
  nullable    = false
  type        = number

  validation {
    condition     = 0 <= var.delay_seconds && var.delay_seconds <= 900
    error_message = "The delay must be in the range of 0 and 900 inclusive."
  }
}

variable "environment" {
  default     = ""
  description = <<-EOF
  The short name of the environment in which the queue is deployed.  It is optional and should only be set when an AWS account is used for multiple environments.
  If it is set, the value is included in the name of the queue.  Valid values are 'dev', 'stage', 'uat', or an empty string (the default).  Production (prod) is
  not included in the valid values to discourage scoping the names of production resources.
  EOF
  nullable    = false
  type        = string

  validation {
    condition     = contains(["dev", "stage", "uat", ""], var.environment)
    error_message = "The environment must be one of 'dev', 'stage','uat', or an empty string."
  }
}

variable "fifo_settings" {
  default     = {}
  description = "An object for configuring the queue attributes that only appy to FIFO queues.  The settings are ignored unless the value of the 'type' variable is'fifo'."
  nullable    = false
  type = object({
    content_based_deduplication = optional(bool, false)
    deduplication_scope         = optional(string, "queue")
    fifo_throughput_limit       = optional(string, "perQueue")
  })

  validation {
    condition     = contains(["messageGroup", "queue"], var.fifo_settings.deduplication_scope)
    error_message = "The deduplication scope must be one of 'queue' or 'messageGroup'."
  }

  validation {
    condition     = contains(["perMessageGroupId", "perQueue"], var.fifo_settings.fifo_throughput_limit)
    error_message = "The throughput limit must be one of 'perMessageGroupId' or 'perQueue'."
  }

  validation {
    condition     = (var.fifo_settings.fifo_throughput_limit == "perMessageGroupId" && var.fifo_settings.deduplication_scope == "messageGroup") || var.fifo_settings.fifo_throughput_limit != "perMessageGroupId"
    error_message = "The deduplication scope must be 'messageGroup' if the throughput limit is set to 'perMessageGroupId'."
  }
}

variable "max_message_size" {
  default     = 256
  description = "The limit of how many kilobytes a message can contain before Amazon SQS rejects it.  The limit is applied to both the queue and its dead-letter queue."
  nullable    = false
  type        = number

  validation {
    condition     = 1 <= var.max_message_size && var.max_message_size <= 256
    error_message = "The maximum message size must be in the range of 1 and 256 inclusive."
  }
}

variable "max_receive_count" {
  default     = 5
  description = "The maximum number of times a consumer tries receiving a message from a queue without deleting it before being moved to the dead-letter queue."
  nullable    = false
  type        = number
  validation {
    condition     = 1 <= var.max_receive_count && var.max_receive_count <= 1000
    error_message = "The maximum receive count must be in the range of 1 to 1000 inclusive."
  }
}

variable "message_retention_seconds" {
  default     = 345600
  description = "The number of seconds messages are retained in the queue."
  nullable    = false
  type        = number

  validation {
    condition     = 60 <= var.message_retention_seconds && var.message_retention_seconds <= 1209600
    error_message = "The message retention must be in the range of 60 to 1209600 inclusive."
  }
}

variable "name" {
  description = "The name the queue and the prefix of the dead-letter queue.  The name must be under 65 characters instead of the AWS limit of 80 to account for suffixes appended by the module."
  nullable    = false
  type        = string

  validation {
    condition     = !endswith(var.name, ".fifo")
    error_message = "The name cannot contain the '.fifo' suffix.  The suffix is automatically added when the type variable is set to 'fifo'."
  }

  validation {
    condition     = !endswith(var.name, "-dlq")
    error_message = "The name cannot end with the '-dlq' suffix.  It is reserved for dead-letter queues."
  }

  validation {
    condition     = !endswith(var.name, "-")
    error_message = "The name cannot end with a '-' character."
  }

  validation {
    condition     = can(regex("^[a-zA-Z0-9_\\-]{1,65}$", var.name))
    error_message = "The name must be 65 characters or less and can only contain alphanumeric characters, hyphens, and underscores."
  }
}

variable "producer_role_arns" {
  default     = []
  description = "A set of ARNs of the IAM roles to include in the queue's policy to grant permission to consume messages from the queue."
  nullable    = false
  type        = set(string)

  validation {
    condition     = alltrue([for arn in var.producer_role_arns : can(regex("^arn:aws:iam::[0-9]+:role/[a-zA-Z0-9+=,.@_\\-/]+$", arn))])
    error_message = "One or more of the role ARNs is syntactically incorrect."
  }
}

variable "receive_wait_time_seconds" {
  default     = 0
  description = "The time for which a ReceiveMessage call will wait for a message to arrive (long polling) before returning"
  nullable    = false
  type        = number

  validation {
    condition     = 0 <= var.receive_wait_time_seconds && var.receive_wait_time_seconds <= 20
    error_message = "The receive wait time must be in the range 0 to 20 inclusive."
  }
}

variable "tags" {
  default     = {}
  description = "An optional map of AWS tags to attach to every resource created by the module."
  nullable    = false
  type        = map(string)
}

variable "type" {
  default     = "standard"
  description = "Specifies if the queue is a standard queue or a FIFO queue."
  nullable    = false
  type        = string

  validation {
    condition     = contains(["standard", "fifo"], var.type)
    error_message = "The queue type must be either 'standard' or 'fifo'."
  }
}

variable "visibility_timeout_seconds" {
  default     = 30
  description = "The period of time during which Amazon SQS prevents other consumers from receiving and processing the message"
  nullable    = false
  type        = number
  validation {
    condition     = 0 <= var.visibility_timeout_seconds && var.visibility_timeout_seconds <= 43200
    error_message = "The visibility timeout must be in the range of 0 and 43200, inclusive."
  }
}

