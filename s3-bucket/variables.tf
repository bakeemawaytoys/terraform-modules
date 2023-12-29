variable "access_logging" {
  default     = {}
  description = <<-EOF
  An object whose attributes configures the generation and destination of the S3 access logs.

  The `enabled` attribute determines if access logs are generated for this bucket.  Defaults to false.
  The `bucket` attribute is the name of the S3 bucket where the access logs will be written.  It cannot be empty if `enabled` is set to true.
  The `prefix` attribute configures a a string to prepend to the key of every access log object created.  It is optional.
  EOF
  nullable    = false
  type = object({
    enabled = optional(bool, false)
    bucket  = optional(string)
    prefix  = optional(string, "")
  })

  validation {
    condition     = !startswith(var.access_logging.prefix, "/")
    error_message = "The prefix cannot start with a '/' character."
  }

  validation {
    condition     = var.access_logging.prefix == "" || endswith(var.access_logging.prefix, "/")
    error_message = "The prefix must end with a '/' character."
  }
}

variable "bucket_encryption_key_arn" {
  default     = null
  description = "The optional ARN of the AWS KMS key to use as the default server-side encryption key for objects in the bucket.  If set to null, the keys managed by S3 are used for encryption."
  nullable    = true
  type        = string
}

variable "bucket_resource_policy_statements" {
  default     = []
  description = <<-EOF
  An optional list of objects that define bucket policy statements that permit actions on bucket resources.  The attributes of the objects
  mirror the arguments of the aws_iam_policy_document data resource except for the `resources` argument.  The objects do not
  have a `resources` attribute because the bucket ARN is not known by module callers.  The module inserts the correct `resources`
  argument into every statement on behalf of the caller.

  The set of actions allowed in the statements is limited to read-only actions that are typically used in the context of object
  access.  The supported actions are those that start with `s3:GetBucket` and `s3:ListBucket`.

  The `not_principals` statement argument is not supported because AWS recommends not using it.
  EOF
  nullable    = false
  type = list(object({
    actions = list(string)
    effect  = optional(string, "Allow")
    conditions = optional(
      list(
        object({
          test     = string
          values   = list(string)
          variable = string
      })),
    [])
    not_actions = optional(list(string), [])
    principals = list(object({
      identifiers = list(string)
      type        = string
    }))
    sid = optional(string)
  }))

  validation {
    condition     = alltrue([for effect in var.bucket_resource_policy_statements[*].effect : contains(["Allow", "Deny"], effect)])
    error_message = "One or more statements has an invalid effect. Valid values for the effect attribute are either Allow or Deny.  The value is case sensitive."
  }

  validation {
    condition     = alltrue([for principals in flatten(var.bucket_resource_policy_statements[*].principals[*]) : 0 < length(principals.identifiers)])
    error_message = "Every principals object must have at least one element in its identifiers list."
  }

  validation {
    condition     = alltrue([for statement in var.bucket_resource_policy_statements : (0 < length(statement.actions)) != (0 < length(statement.not_actions))])
    error_message = "One or more statements has invalid actions and not_actions attributes.  Exactly one of those attributes must be non-empty."
  }

  validation {
    condition     = alltrue([for type in flatten(var.bucket_resource_policy_statements[*].principals[*].type) : contains(["AWS", "Service", "Federated"], type)])
    error_message = "One or more statements has an invalid principal type.  Valid types are AWS, Service, or Federated.  The values are case sensitive."
  }

  validation {
    condition = alltrue([for action in flatten(var.bucket_resource_policy_statements[*].actions) :
      anytrue([
        startswith(action, "s3:GetBucket"),
        startswith(action, "s3:ListBucket"),
      ])
    ])
    error_message = "One or more statements contains an unsupported action.  Supported actions start with either s3:GetBucket or s3:ListBucket."
  }
}

variable "name" {
  default     = null
  description = "The full name of the bucket.  If neither the name nor the name_prefix variables are set, Terraform generates a name for the bucket."
  nullable    = true
  type        = string
}

variable "name_prefix" {
  default     = null
  description = "The prefix Terraform should use when generating a unique name for the bucket.  If neither the name nor the name_prefix variables are set, Terraform generates a name for the bucket."
  nullable    = true
  type        = string
}

variable "intelligent_tiering_archive_configurations" {
  default     = {}
  description = <<-EOF
  An optional map whose elements specify the settings for intelligent-tiering archive configurations.  The keys in the map are the names of the configurations.  The keys are objects containing the settings for the configuration.

  The `enabled` attribute determines if the configuration's rules should be applied.  Defaults to true.
  The `filter` attribute is an object whose attributes, `prefix` and `tags`, scope the configuration's rules to objects based on key prefix and/or tags.  Set to null (the default) to apply the rules to all objects in the bucket.
  The `tiering` attribute is an object whose attributes, `archive_access` and `deep_archive_access`, determine the number of days after which the objects are moved to the Archive Access tier and the Deep Archive Access tier, respctively.
    At least one of the tiering object's attributes must have a value.  Neither have a default value.
  EOF
  nullable    = false
  type = map(object({
    enabled = optional(bool, true)
    filter = optional(object({
      prefix = optional(string)
      tags   = optional(map(string))
    }))
    tiering = object({
      archive_access      = optional(number)
      deep_archive_access = optional(number)
    })
  }))

  validation {
    condition     = alltrue([for k in keys(var.intelligent_tiering_archive_configurations) : can(regex("^[a-zA-Z0-9]{1,64}$", k))])
    error_message = "Every key must be between one and 64 characters in length (inclusive) and only consist of alphanumeric characters."
  }

  validation {
    condition     = alltrue([for t in values(var.intelligent_tiering_archive_configurations)[*].tiering : t.archive_access != null || t.deep_archive_access != null])
    error_message = "Either the `archive_access` attribute, the `deep_archive_access` attribute, or both attributes must have a value in every entry's `tiering` object attribute."
  }

  validation {
    condition     = alltrue([for t in values(var.intelligent_tiering_archive_configurations)[*].tiering : 90 <= t.archive_access if t.archive_access != null])
    error_message = "The `archive_access` attribute must be greater than or equal to 90 if it is not null."
  }

  validation {
    condition     = alltrue([for t in values(var.intelligent_tiering_archive_configurations)[*].tiering : 180 <= t.deep_archive_access if t.deep_archive_access != null])
    error_message = "The `deep_archive_access` attribute must be greater than or equal to 90 if it is not null."
  }
}

variable "object_lifecycle_rules" {
  default = {
    "Default" = {
      noncurrent_version_transition = [{
        noncurrent_days = 0
        storage_class   = "INTELLIGENT_TIERING"
      }]
      transition = [{
        days          = 0
        storage_class = "INTELLIGENT_TIERING"
      }]
    }
  }
  description = <<-EOF
  An optional map of object lifecycle rules to add to the bucket in addition to the required rules added by the module.  Each entry in the map corresponds to one lifecycle rule.
  The keys in the map are the identifiers (i.e. the id attributes) of the rules.  The values in the map are objects that configure each rule.  The default value contains a
  single rule to transition all objects and non-concurrent versions to Intelligent Tiering at midnight UTC following creation.
  EOF
  nullable    = false
  type = map(object({
    filter = optional(
      object({
        prefix                   = optional(string)
        object_size_greater_than = optional(number)
        object_size_less_than    = optional(number)
        tags                     = optional(map(string), {})
      }),
    {})
    enabled = optional(bool, true)
    expiration = optional(
      object({
        days = optional(number)
        date = optional(string)
    }))
    noncurrent_version_expiration = optional(
      object({
        newer_noncurrent_versions = optional(number)
        noncurrent_days           = optional(number)
    }))
    noncurrent_version_transition = optional(
      list(object({
        newer_noncurrent_versions = optional(number)
        noncurrent_days           = optional(number)
        storage_class             = string
      })),
    [])
    transition = optional(
      list(object({
        days          = optional(number)
        date          = optional(string)
        storage_class = string
      })),
    [])

  }))

  validation {
    condition     = alltrue([for storage_class in flatten(values(var.object_lifecycle_rules)[*].transition[*].storage_class) : contains(["GLACIER", "STANDARD_IA", "ONEZONE_IA", "INTELLIGENT_TIERING", "DEEP_ARCHIVE", "GLACIER_IR"], storage_class)])
    error_message = "One or more transition attributes contains an invalid storage class.  Valid storage class values are GLACIER, STANDARD_IA, ONEZONE_IA, INTELLIGENT_TIERING, DEEP_ARCHIVE, GLACIER_IR."
  }

  validation {
    condition     = alltrue([for transition in flatten(values(var.object_lifecycle_rules)[*].transition) : (transition.date != null) != (transition.days != null)])
    error_message = "One or more transition attributes does not specify either a date or days.  One or the other must be specified but not both."
  }

  validation {
    condition     = alltrue([for storage_class in flatten(values(var.object_lifecycle_rules)[*].noncurrent_version_transition[*].storage_class) : contains(["GLACIER", "STANDARD_IA", "ONEZONE_IA", "INTELLIGENT_TIERING", "DEEP_ARCHIVE", "GLACIER_IR"], storage_class)])
    error_message = "One or more nonconcurrent version transition attributes contains an invalid storage class.  Valid storage class values are GLACIER, STANDARD_IA, ONEZONE_IA, INTELLIGENT_TIERING, DEEP_ARCHIVE, GLACIER_IR."
  }

  validation {
    condition     = alltrue([for expiration in values(var.object_lifecycle_rules)[*].expiration : (expiration.date != null) != (expiration.days != null) if expiration != null])
    error_message = "One or more expiration attributes does not specify either a date or days.  One or the other must be specified but not both."
  }

  validation {
    condition     = alltrue([for id in keys(var.object_lifecycle_rules) : 0 < length(id) && length(id) <= 255])
    error_message = "The keys in the map must be non-empty strings and less than or equal to 255 characters in length."
  }

  validation {
    condition     = alltrue([for prefix in values(var.object_lifecycle_rules)[*].filter.prefix : prefix != "" if prefix != null])
    error_message = "One or more filter attributes contains a prefix set to an empty string.  Prefixes must be either null or a non-empty string."
  }

  validation {
    condition     = alltrue([for id in keys(var.object_lifecycle_rules) : !contains(["DeleteMarkerCleanup", "PrepareBucketForDeletion", "MultipartUploadCleanup"], id)])
    error_message = "The strings DeleteMarkerCleanup, PrepareBucketForDeletion, and MultipartUploadCleanup cannot be used as keys in the map."
  }

}

variable "object_lock" {
  default     = {}
  description = <<-EOF
  An object whose attributes determine if object locking is enable don the bucket and, optionally, the default retention for locked objects.

  The `enabled` attribute determines if object locking is enabled.  It defaults to false.
  The `default_retention` object configures the retention settings to use for objects that are created without retention settings.  Optional is optional and defaults to null.
  EOF
  nullable    = false
  type = object({
    default_retention = optional(
      object({
        days  = optional(number)
        mode  = string
        years = optional(number)
      })
    )
    enabled = optional(bool, false)
  })

  validation {
    condition     = try(contains(["COMPLIANCE", "GOVERNANCE"], var.object_lock.default_retention.mode), var.object_lock.default_retention == null)
    error_message = "The default retention mode must be either COMPLIANCE or GOVERNANCE."
  }
}

variable "object_resource_policy_statements" {
  default     = []
  description = <<-EOF
  An optional list of objects that define bucket policy statements that permit actions on object resources.  The attributes of
  the objects mirror the arguments of the aws_iam_policy_document data resource except for the `resources` and `not_resources`
  arguments.  The objects do not have those attributes because the bucket ARN is not known by module callers.  Instead, each
  object has `prefixes` and `not_prefixes` attributes that are used to construct the `resources` and `not_resources`,
  respectively, in the policy statement.  The `prefixes` attribute is the list of object prefixes that are appended to the
  bucket's ARN to construct object ARNs.  The object ARNs are then used to populate the statement's `resouces` or `not_resources` list.

  The `not_principals` statement argument is not supported because AWS recommends not using it.
  EOF
  nullable    = false
  type = list(object({
    actions = optional(list(string), [])
    effect  = optional(string, "Allow")
    conditions = optional(
      list(
        object({
          test     = string
          values   = list(string)
          variable = string
      })),
    [])
    not_actions  = optional(list(string), [])
    not_prefixes = optional(list(string), [])
    prefixes     = optional(list(string), [])
    principals = list(object({
      identifiers = list(string)
      type        = string
    }))
    sid = optional(string)
  }))

  validation {
    condition     = alltrue([for effect in var.object_resource_policy_statements[*].effect : contains(["Allow", "Deny"], effect)])
    error_message = "One or more statements has an invalid effect. Valid values for the effect attribute are either Allow or Deny.  The value is case sensitive."
  }

  validation {
    condition     = alltrue([for principals in flatten(var.object_resource_policy_statements[*].principals) : 0 < length(principals.identifiers)])
    error_message = "Every principals object must have at least one element in its identifiers list."
  }

  validation {
    condition     = alltrue([for statement in var.object_resource_policy_statements : (0 < length(statement.actions)) != (0 < length(statement.not_actions))])
    error_message = "One or more statements has invalid actions and not_actions attributes.  Exactly one of those attributes must be non-empty."
  }

  validation {
    condition     = alltrue([for type in flatten(var.object_resource_policy_statements[*].principals[*].type) : contains(["AWS", "Service", "Federated"], type)])
    error_message = "One or more statements has an invalid principal type.  Valid types are AWS, Service, or Federated.  The values are case sensitive."
  }

  validation {
    condition     = alltrue([for prefix in flatten(var.object_resource_policy_statements[*].prefixes) : !startswith(prefix, "/")])
    error_message = "One or more statements contains a value in the prefixes attribute that starts with a '/' character.  Prefixes cannot start with a '/' character."
  }

  validation {
    condition     = alltrue([for prefix in flatten(var.object_resource_policy_statements[*].not_prefixes) : !startswith(prefix, "/")])
    error_message = "One or more statements contains a value in the not_prefixes attribute that starts with a '/' character.  Prefixes cannot start with a '/' character."
  }

  validation {
    condition     = alltrue([for statement in var.object_resource_policy_statements : (0 < length(statement.prefixes)) != (0 < length(statement.not_prefixes))])
    error_message = "One or more statements has invalid prefixes and not_prefixes attributes.  Exactly one of those attributes must be non-empty."
  }

  validation {
    condition = alltrue([for action in flatten(var.object_resource_policy_statements[*].actions) :
      anytrue([
        startswith(action, "s3:GetObject"),
        startswith(action, "s3:PutObject"),
        startswith(action, "s3:DeleteObject"),
        contains(["s3:AbortMultipartUpload", "s3:ListMultipartUploadParts"], action),
      ])
    ])
    error_message = "One or more statements contains a value in its actions attribute that is not an object action."
  }

  validation {
    condition = alltrue([for action in flatten(var.object_resource_policy_statements[*].not_actions) :
      anytrue([
        startswith(action, "s3:GetObject"),
        startswith(action, "s3:PutObject"),
        startswith(action, "s3:DeleteObject"),
        contains(["s3:AbortMultipartUpload", "s3:ListMultipartUploadParts"], action),
      ])
    ])
    error_message = "One or more statements contains a value in its actions attribute that is not an object action."
  }
}

variable "prepare_for_deletion" {
  default     = false
  description = <<-EOF
  When set to true, the bucket is configured to remove all of its objects so that it can be deleted.
  To achive this, the following changes are made.
  * Versioning, if it is enabled, is suspended.
  * A statment is added to the bucket policy to explicitly deny the creation of new objects.
  * All custom bucket policy statements are removed.
  * A lifecycle rule scoped to the entire bucket is added expire all objects and nonconcurrent versions one day after their creation date.  Aborted multipart uploads are set to be deleted after one day instead of seven.
  * All lifecycle rules set in the object_lifecycle_rules variable are removed from the bucket.
  * The `force_destroy `argument on the `aws_s3_bucket` resource is set to true.
  EOF
  nullable    = false
  type        = bool
}

variable "tags" {
  default     = {}
  description = "A set of AWS tags to apply to every resource in the module"
  nullable    = false
  type        = map(string)
}

variable "versioning" {
  default     = {}
  description = <<-EOF
  An object whose attributes determine if object versioning is enabled, disabled, or enabled but suspended.
  It also determines if the principle must be authenticated using MFA to allow deletion of objects.
  EOF
  nullable    = false
  type = object({
    enabled      = optional(bool, true)
    suspended    = optional(bool, false)
    mfa_required = optional(bool, false)
  })

  validation {
    condition     = !var.versioning.mfa_required || (var.versioning.mfa_required && var.versioning.enabled && !var.versioning.suspended)
    error_message = "If MFA is required, enabled must be set to true and suspended must be set to false."
  }

  validation {
    condition     = !(!var.versioning.enabled && var.versioning.suspended)
    error_message = "If versioning is disabled, suspended cannot be set to true."
  }
}
