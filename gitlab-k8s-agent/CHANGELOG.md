# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## 5.1.0

### Added

- A Kubernetes ClusterRole has been added to grant Gitlab users access to a limited set of cluster-scoped resources.  The role is bound to the `gitlab:user` Kubernetes group.  All Gitlab users accessing the Kubernetes API with the agent's user impersonation feature now have permission to get and list namespaces and custom resource definitions.  This change is primarily to facilitate the [Kubernetes Dashboard](https://docs.gitlab.com/ee/ci/environments/kubernetes_dashboard.html) feature but is also helpful when accessing a Kubernetes cluster with kubectl or k9s.

## 5.0.0

### Changed

- **Breaking Change**: Dropped support for chart versions 1.14.x through 1.19.x.
- Min supported chart version is now 1.20.x Covering Gitlab 16.5.x.

## 4.0.0

### Changed

- **Breaking Change**: Dropped support for chart versions 1.12.x and 1.13.x.
- Min supported chart version is now 1.14.x with a max of 1.18.x covering Gitlab 16.0.x through 16.3.x.

## 3.0.0

### Added

- Pod tolerations are now configurable with the optional `node_tolerations` variable.
- Pod node selectors are now configurable with the optional `node_selector` variable.
- The module now supports deploying version 1.13.x (and agent version 15.11.x) of the Helm chart.

### Changed

- **Breaking Change**: The minimum supported Terraform version is now 1.4.
- **Breaking Change**: The `chart_version` variable no longer has a default value.  By removing the default value, the installed version must be specified in the module call. It is no longer necessary to look at the module source to figure out which version is deployed in a module call.
- Pods now include tolerations for taints on the `kubernetes.io/arch` label with the `amd64` or `arm64` values.
- A container security context has been added to the agent's container to drop all capabilities, disable privilege escalation, add the RuntimeDefault seccomp profile, ensure the container runs as non-root, and set the root filesystem as read-only.

### Removed

- **Breaking Change**: Dropped support for chart versions 1.10.x and 1.11.x.

## 2.5.0

### Changed

- Updated the `chart_version` variable. The min value is 1.12.0 which represents the default for version 15.10.0 of the agent.

## 2.4.1

### Changed

- Fixed the `chart_version` variable. The min value is 1.10.0 with the default set to 1.11.0 for version 15.9.0 of the agent.

## 2.4.0

### Changed

- Updated the `chart_version` variable. The min value is 1.8.0 with the default set to 1.11.0 for version 15.9.0 of the agent.

## 2.3.0

### Changed

- Updated the `chart_version` variable. The min value is 1.5.0 with the default set to 1.8.0 for version 15.6.0 of the agent.

## 2.2.0

### Changed

- Upgraded the sealed-secret module version to 2.0.0 to apply bug fixes and increase timeouts.

## 2.1.1

### Fixed

- Upgraded the sealed-secret module to version 1.0.3 to apply yet another workaround to a bug in the `kubernetes_manifest` resource.

## 2.1.0

### Changed

- Switched to using the [sealed-secret module](../sealed-secret/) to manage the access token's `SealedSecret` resource instead of directly managing the resource in this module.  This will reduce code duplication among modules and include workarounds for the [bugs in the Kubernetes provider's `kubernetes_manifest` resource](https://github.com/hashicorp/terraform-provider-kubernetes/issues/1610).

## 2.0.1

### Fixed

- Validation on the `agent_name` resource now allows names longer than three characters and less than 63 as intended.

## 2.0.0

### Changed

- **Breaking Change**: Validation on the `chart_version` variable has been tightened to constrain the allowed values to those that the module is designed to support.  The minimum value is 1.0.0 with the default set to 1.1.0 for version 15.0.0 of the agent.
- Set the minimum version of the Kubernetes provider to 2.12.1 to make use of the new `condition` option on the `wait` attribute of the `kubernetes_manifest` resource.
- Set the minimum Helm provider version to 2.6.0 to upgrade Helm to 3.9.

## 1.0.0

### Added

- Initial release !1
