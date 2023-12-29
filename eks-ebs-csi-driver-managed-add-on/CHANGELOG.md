# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## 2.0.0

### Changed

- **Breaking Change**: The minium supported version of the AWS provider has been changed from 4.67 to 5.0.  The `aws_eks_addon` resource contains deprecations in version 5.0.  The module has been modified to remove the use of those deprecations.

## 1.2.0

### Added

- The controller pod's node selector can be configured using the `node_selector` variable when version 1.14 or greater is deployed.
- All AWS resources are now tagged with the `kubernetes.io/cluster` tag.

### Fixed

- The controller logs will no longer be flooded with errors about missing snapshot CRDs when version 1.19 or greater is deployed.

## 1.1.0

### Added

- Controller and node pod logs will be in JSON format when driver version 1.16 or later is specified.
- The AWS tag `managed_with = "ebs-csi-driver"` is now added to every EBS volume managed by the driver.

### Changed

- Version 4.47.0 of the AWS provider is now the minimum supported version due to a change in that version used by this version of the module.

## 1.0.0

### Added

- Initial release !1
