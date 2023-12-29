# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## 1.0.2

### Fixed

- The module no longer attempts to create a `aws_s3_bucket_accelerate_configuration` resource if the bucket name contains any periods.  S3 does not allow buckets to have an accelerate configuration even if the configuration is set to the `Suspended` status.

## 1.0.1

### Fixed

- Added the missing `expected_bucket_owner` argument to the `aws_s3_bucket_versioning` resource.
- Removed the `expected_bucket_owner` argument from the `aws_s3_bucket_logging` resource [due to a bug that causes perpetual drift](https://github.com/hashicorp/terraform-provider-aws/issues/26627).

## 1.0.0

### Added

- Initial release
