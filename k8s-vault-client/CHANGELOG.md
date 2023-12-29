# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## 4.0.0

### Upgrade Notes

The kubectl provider's source has changed from `gavinbunney/kubectl` to `alekc/kubectl`.  To upgrade the module to version 4.0+, the following command must be run to change the source in the Terraform state file.

```shell
terraform state replace-provider gavinbunney/kubectl alekc/kubectl
```

### Changed

- **Breaking Change**: The kubectl provider's source has been changed from [`gavinbunney/kubectl`](https://registry.terraform.io/providers/gavinbunney/kubectl/latest) to [`alekc/kubectl`](https://registry.terraform.io/providers/alekc/kubectl/latest).  The `alekc/kubectl` implementation is a fork of `gavinbunney/kubectl`.  It fixes a number of bugs and updates its dependencies to newer versions.  A new version of the `gavinbunney/kubectl` implementation hasn't been released in two years and, based on the lack of activity in its Github project, appears to be dead.  Given that the provider is for managing K8s resources, it is important to use a version that is kept up-to-date with the K8s API.

## 3.1.0

### Added

- The `agent_default_configuration` variable's `resources` attribute has bee modified to support configuring the agent side-car [container's ephemeral storage requests and limits(https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#setting-requests-and-limits-for-local-ephemeral-storage).  The default value for the requests is 256Mi and limit is 512Mi to ensure enough storage is allocated for both the Vault image layers and the files created by the agent.

## 3.0.1

### Fixed

- The validation on the `secrets_store_csi_driver_chart_version` variable wasn't updated to allow version 1.3.4.  It now allows that version and only that version.

## 3.0.0

### Added

- The module now supports version 0.26.x of the Vault Helm chart.

### Changed

- **Breaking Change**: The Kubernetes Vault auth backend has been reconfigured to [use the client JWT as the review JWT token](https://developer.hashicorp.com/vault/docs/auth/kubernetes#use-the-vault-client-s-jwt-as-the-reviewer-jwt).  The Kubernetes service account and long-lived token used as the review JWT token have been removed from the module.  After upgrading to the new version of this module, all Kubernetes workloads integrated with Vault must use a token whose service account is bound to the `system:auth-delegator` cluster role to authenticate.
- **Breaking Change**: The minimum Terraform version supported by the module is 1.5.
- The maximum history maintain by the Helm releases has been reduced from 25 to 5.  When Terraform is used in conjunction with Git, maintaining a large number of Helm releases is unnecessary because rollback is a matter of reverting Git commits.
- The Secrets Store CSI driver has been upgraded from 1.3.3 to [1.3.4](https://github.com/kubernetes-sigs/secrets-store-csi-driver/releases/tag/v1.3.4).

### Removed

- **Breaking Change**: Dropped support for versions 0.23 and 0.24 of the Vault Helm chart.
- **Breaking Change**: Dropped support for using Vault versions 1.11 and 1.12 as the agent sidecar.

## 2.2.0

### Added

- The `vault_auth_backend` output has been added to expose all attributes of the Vault auth backend as a single object.

## 2.1.0

### Changed

- Updated validation on vault_version configuration to only allow 1.11.x - 1.14.x.
- Update Helm Chart version to `0.25.0`.

## 2.0.2

### Fixed

- Fixed the CSI driver upgrade failures caused by changes to its daemonset tolerations in version 1.3.  The upgrades failed because changes allow the pods to tolerate Farget node taints.  Node affinity has been added to the daemonset to ensure the pods are only scheduled on EC2 instances.

## 2.0.1

### Fixed

- Fixed regex for secrets store version validation.

## 2.0.0

### Changed

- Updated secrets store chart version to latest version and updated values accordingly.
- Updated vault chart version to latest version.
- Updated validation on vault_version configuration to only allow 1.11.x - 1.13.x.

## 1.2.0

### Added

- The module now supports version 0.23.x of the Helm chart.
- The agent injector has been configured with a [pod disruption budget](https://kubernetes.io/docs/tasks/run-application/configure-pdb/) to ensure at least one injector is always running. The PDB is configured with `maxUnavailable: "50%"`.

### Fixed

- The resource limits and values specified in the `agent_default_configuration` variable are now correctly applied.

## 1.1.0

### Changed

- The module no longer downloads the Secret Store CSI driver CRD files from Github because of Github API rate limits. As more and more of the modules in this project were modified to download CRD files, the risk of hitting the rate limit increased. To avoid the issue, the CRDs for the supported chart versions are now bundled in the module. While this increases the maintenance burden of this module, it eliminates a pain point when consuming the module.
- The `chart_version` variable is now restircted to the Helm chart versions whose CRDs are bundled in the module.

### Removed

- The `http` provider is no longer required by the module. It was only used to download the CRD files.

## 1.0.3

### Changed

- Disabled JSON logging on the Secret Store CSI driver. Fluent Bit doesn't like that the timestamp field is a float and OpenSearch doesn't like that the `spcps` attribute is a string in some log entries and an object in others.

## 1.0.2

### Fixed

- Fixed the formatting of the metadata in the Vault auth backend's description.

## 1.0.1

### Fixed

- Added the missing default value for the `template_config` attribute on the `agent_default_configuration` variable.

## 1.0.0

### Added

- Initial release
