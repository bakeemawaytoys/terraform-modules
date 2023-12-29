# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## 2.0.0

### Added

- The optional `timeouts` variable has been added to control the timeouts of the create, delete, and update operations on the Terraform resource that manages the k8s SealedSecret resource.
- Validation has been added to the `labels`, `annotations`, and `secret_metadata` variables.

### Changed

- Set the minimum Terraform version to 1.3.0 due to the use of the `optional` object attributes on variable types.
- Validation on the `secret_type` variable now ensures the value is one of [the built-in types of secrets](https://kubernetes.io/docs/concepts/configuration/secret/#secret-types).

### Fixed

- The module no longer orphans the SealedSecret resource when the secret cannot be unsealed.  A `kubernetes_resource` data resource has been added to the module to check the status of the SealedSecret resource after it has been created.  It is no longer necessary to manually delete the SealedSecret resource when an update or create operation fails.

## 1.0.4

### Changed

- Increased the timeouts to better handle scenarios where the controller is briefly unavailable at the same time the resource is created.

## 1.0.3

### Fixed

- Modified the `kubernetes_manifest` resource to use `fields` attribute in the [`wait` block](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest#using-wait-to-block-create-and-update-calls) instead of `condition` blocks.  The `kubernetes` provider panics when the `condition` block is used and k8s API returns a resource without a status attribute.

### Changed

- Set the minimum version of the `kubernetes` provider to 2.13 to ensure the fix works.

## 1.0.2

### Fixed

- Added the label `"app.kubernetes.io/managed-by": "terraform"` as a default label so that the SealedSecret resource always has at least one label.  The `kubernetes_manifest` resource errors out when the manifest specifies an empty map as the value of the labels attribute in the metadata block.

## 1.0.1

### Fixed

- Implemented a work around to a crash caused by [a bug in the Kubernetes provider](https://github.com/hashicorp/terraform-provider-kubernetes/issues/1610) during the plan phase.
- Added the value of the `labels` variable to the `spec.template.metadata` attribute in the SealedSecret resource to ensure any labels on it are propagated to the generated `Secret` resource.

## 1.0.0

### Added

- Initial release
