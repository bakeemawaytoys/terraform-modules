# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## 1.1.0

### Added

- The name of the Vault policy is now exposed through the `policy_name` output.
- The resource metadata has been modified to include the value of the `application_name` variable.  Its key in the metadata is appropriately named `application_name`.

### Fixed

- A Vault identity entity can only have one alias per backend.  Version 1.0.x did not account for this restriction.  As a result, the module would break when multiple Kubernetes service accounts were supplied.  The module has been modified to create a separate identity entity for each service account.  To account for this change, the `entity` output has been renamed `entities` and it now produces a map of service account UIDs to entity attribute objects instead of a single entity attribute object.

## 1.0.1

### Changed

- Modified the `external_kv_secrets` variable to allow wildcard suffixes.  Modified the logic to generate the corresponding policy rules to only include the wildcard suffix if it present in the variable value instead of always including it.  This change is considered a fix because 1.0.0 incorrectly assumed that all policies included the wildcard suffix for external rules.  It turns out the policies for the Enrollment service do not.

## 1.0.0

### Added

- Initial release
