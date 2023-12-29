# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## 2.3.1

### Fixed

- The value of the `kms:ViaService` condition keys in the S3 policies have been fixed.  [The service name used in the condition value must include the region name](https://docs.aws.amazon.com/kms/latest/developerguide/conditions-kms.html#conditions-kms-via-service).  Prior to this change, it did not.

## 2.3.0

### Added

- Added a new inline policy to the role that grants permission to send emails from verified SES identities.

## 2.2.0

### Added

- The trust policy on the IAM role has been modified to use the `StringLike` operator in [the web identity `sub` condition](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_iam-condition-keys.html#ck_wif-sub).  The `?` and `*` wildcard characters can now be used in the `name` and `namespace` attributes of the `service_account` variable to allow multiple service accounts to assume the role.  To avoid accidentally granting access to AWS, neither value can use the `*` string is its value.  Additionally, the `default` service account cannot be used because it is automatically assigned to pods that don't specify a service account.

### Fixed

- The validation for the `name` attribute of the `service_account` variable has been fixed.  It will now correctly prevents the use of the `default` service account.

## 2.1.0

### Added

- Actions for S3 object legal holds, retention, and attributes have been added to the S3 inline policy statements.  They had been omitted in an effort to minimize policy size but they are, in fact, needed.

## 2.0.0

### Changed

- Added the `sqs:ListQueues` action to the SQS inline policy attached to the role.  The [python-sqs-listener](https://github.com/jegesh/python-sqs-listener) library used by some of the Django projects inexplicably uses the action to look up queues even though the name and/or URL of the queue is passed to the library as part of its configuration.
- **Breaking Change**: The `sqs_consumer_queue_arns` and `sqs_producer_queue_arns` variables have been consolidated into one variable named `sqs_access`.  The new variable is of type object with two attributes that serve the same purpose as the previous two variables.   The change was done to improve the module's policy logic generation.
- **Breaking Change**: The `s3_writer_buckets` and `s3_reader_buckets` variables have been consolidated into one variable named `s3_access`.  The new variable is of type object with two attributes that serve the same purpose as the previous two variables.   The change was done to improve the module's policy logic generation.

### Fixed

- Reworked the SQS and S3 policy generation logic to prevent errors that occurred when creating queue and bucket resources in the same plan/apply run as the IAM role's inline policies.

## 1.1.0

### Added

- The optional `path` variable has been added to support roles with paths.  It defaults to the `/` path.

### Fixed

- Corrected ARN validation in the S3 bucket variables.

## 1.0.0

### Added

- Initial release
