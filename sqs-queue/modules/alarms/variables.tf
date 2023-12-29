variable "queue" {
  description = "The attributes of the queue to monitor."
  nullable    = false
  type = object({
    name = string
  })
}

variable "actions" {
  default     = []
  description = "An optional list of ARNs for all alarm actions"
  nullable    = false
  type        = list(string)
}

variable "queue_depth_alarm" {
  default     = {}
  description = "Configures the alarm that triggers if the depth of the queue exceeds the threshold."
  nullable    = false
  type = object({
    actions_enabled    = optional(bool, true)
    evaluation_periods = optional(number, 2)
    period             = optional(number, 60)
    threshold          = optional(number, 1)
  })

  validation {
    condition     = 1 <= var.queue_depth_alarm.evaluation_periods
    error_message = "The queue depth alarm's 'evaluation_periods' attribute must be greater than or equal to one."
  }

  validation {
    condition     = 0 < var.queue_depth_alarm.period && ((var.queue_depth_alarm.period % 60) == 0 || contains([10, 30], var.queue_depth_alarm.period))
    error_message = "The queue depth alarm's period must be 10, 30, and any multiple of 60."
  }

  validation {
    condition     = 1 <= var.queue_depth_alarm.threshold
    error_message = "The queue depth alarm's threshold must be greater than or equal to one."
  }
}

variable "message_age_alarm" {
  default     = {}
  description = "Configures the alarm that triggers when the age of the oldest message in the queue exceeds the threshold."
  nullable    = false
  type = object({
    actions_enabled    = optional(bool, true)
    evaluation_periods = optional(number, 5)
    period             = optional(number, 60)
    threshold          = optional(number, 5 * 60)
  })

  validation {
    condition     = 1 <= var.message_age_alarm.evaluation_periods
    error_message = "The message age alarm's 'evaluation_periods' attribute must be greater than or equal to one."
  }

  validation {
    condition     = 0 < var.message_age_alarm.period && ((var.message_age_alarm.period % 60) == 0 || contains([10, 30], var.message_age_alarm.period))
    error_message = "The message age alarm's period must be 10, 30, and any multiple of 60."
  }

  validation {
    condition     = 1 <= var.message_age_alarm.threshold
    error_message = "The message age alarm's threshold must be greater than or equal to one."
  }
}

variable "tags" {
  default     = {}
  description = "An optional map of AWS tags to attach to every resource created by the module."
  nullable    = false
  type        = map(string)
}
