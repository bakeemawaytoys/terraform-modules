# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## 2.3.2

### Fixed

- Typo for `log_min_curation_statement` parameter should be `log_min_duration_statement` to enable `slow query logging`.

## 2.3.1

### Fixed

- Set the `log_min_curation_statement` parameter apply method to `immediate` instead of `pending reboot`.

## 2.3.0

### Added

- The `log_min_curation_statement` parameter to enable `slow query logging` for RDS instances.

## 2.2.0

### Added

- The module now supports instances that contain [PostgreSQL foreign data wrappers](https://www.postgresql.org/docs/current/postgres-fdw.html) targeting other PostgreSQL instances.  The optional `foreign_data_wrapper_security_group_egress_rules` variable has been added to define egress rules for port 5432 on the instance's security group.
- The `db_instance_identifier` tag has been added to the instance's security group, CloudWatch alarms, and parameter group to make it easier to reference them using a data resource.

## 2.1.1

### Fixed

- The `snapshot_identifier` attribute is now correctly set to the value of the `db_snapshot_identifier` attribute of the `source_snapshot` variable.

## 2.1.0

### Added

- Instances can now be configured as a [multi-az deployment](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZSingleStandby.html) using the `multi_az_enabled` variable.

## 2.0.0

### Added

- The `performance_insights` variable has been added enable configuration of the instance's Performance Insights retention period and, optionally, encryption key.  If an encryption key is not provided in the variable, the key provided in the `kms_encryption_key_alias` variable is used.   The default behavior is to use the key in the `kms_encryption_key_alias` variable.

### Changed

- **Breaking Change**: The `source_snapshot_identifier` variable has been replaced by the `source_snapshot` variable.  The new variable is an object containing the attributes of an RDS snapshot resource instead of a simple string.  By passing in the attributes, the module no longer has to use an `aws_db_snapshot` data resource.  The data resource caused problems because it was implemented with a count meta-attribute whose value wasn't always known at plan time.
- The default value of the `backup_retention_period` variable has been reduced to `7` to help reduce the cost of using RDS.
- The default Performance Insights retention period has been lowered from `31` to `7` days to help reduce the cost of using RDS.  It can be changed back to `31` via the new `performance_insights` variable.

### Removed

- **Breaking Change**: Dropped support for using the module to create a read-only replica.  It made the module implementation very complex, was full of edge cases, and is a use case that is better served by using an Aurora cluster.  The `replication_source_db_identifier` variable has been removed for this change.

## 1.0.0

### Added

- Initial release
