# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## 1.1.0

### Added

- Three Kubernetes `ClusterRole` resources are now included in the module to provide access to the Flagger custom resources.  The three roles are `flagger-view`, `flagger-edit`, and `flagger-admin` to cover the read-only, poweruser, and admin use-cases.  The roles are labeled so that they [aggregate](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#aggregated-clusterroles) to the standard `view`, `edit`, and `admin` roles, respectively.  The only difference between the `flagger-edit` and `flagger-admin` roles is that admins have access to the `AlertProvider` resource and editors don't.  Access to the `AlertProvider` resources are restricted because they can contain sensitive data in the form of web hook URLs.  The `flagger-view` role does not have access to `AlertProvider` resources.
- The name of the new `ClusterRole` resources are exposed to module callers with the new `admin_cluster_role`, `edit_cluster_role`, and `view_cluster_role` outputs.
- The name of the Kubernetes namespace where Flagger is deployed is now exposed to callers through the `namespace` output.

### Fixed

- The name of the namespace that appears in the Prometheus alert for failed canary deployments has been fixed.  It had displayed the namespace where Flagger is deployed instead of the the namespace where the Canary resource is deployed.  The root cause is the Prometheus Operator relabeling the `namespace` label to `exported_namespace`.

## 1.0.0

### Added

- Initial release
