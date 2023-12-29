# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## 2.1.1

## Fixed

- Corrected a Helm release value to ensure the `image_registry` takes effect.

## 2.1.0

### Added

- The module now supports versions 3.9.x and 3.10.x of the Helm chart (server version 0.6.3).
- The image registry is now configurable through the optional `image_registry` variable.

## 2.0.1

### Fixed

- Fixed a bug in `replicas` variable validation that prevented the default value from passing.

## 2.0.0

## Added

- The `node_tolerations` and `node_selector` variables have been added to control pod scheduling.
- The `labels` variable has been added to specify the Kubernetes labels that are added to all resources created by the Helm release.
- The `enable_service_monitor` variable has been added to control the deployment of a [ServiceMonitor resource](https://prometheus-operator.dev/docs/operator/api/#monitoring.coreos.com/v1.ServiceMonitor).  It defaults to `true`.
- Pod resource requests and limits can be configured with the new `pod_resources` variable.
- The number of pods deployed by the module is controlled by the new `replicas` variable.  The minimum value and default value is two pods.
- A default set of tolerations are defined by the module to allow pods to be scheduled on nodes that use the `kubernetes.io/arch` taint.  The taint uses the Exists operator instead of Equals because [metrics server images are available for all architectures available on AWS](https://github.com/kubernetes-sigs/metrics-server/blob/master/FAQ.md#how-to-run-metric-server-on-different-architecture).

## Changed

- **Breaking Change**: Switched to using [the Helm chart and container image maintained by the Kubernets project](https://github.com/kubernetes-sigs/metrics-server).  The primary motivation for the switch is to support running the server on ARM architectures.  Bitnami images are only available for x86-64.
- **Breaking Change**: The `helm_chart_version` variable has been renamed `chart_version` to be consistent with the other modules in this project.  Validation has been added to the variable to restrict the allowed versions to those supported by the chart.
- The Helm release now deploys a pod disruption budget that requires at least one pod to run at all times.

## Removed

- **Breaking Change**: The `helm_chart_release_name` variable has been removed.  The release name is now hardcoded to `metrics-server`.
- **Breaking Change**: The `namespace` variable has been removed.  The module now creates all resources in the `kube-system` namespace.
- **Breaking Change**: The `settings` variable has been removed in favor of selectively exposing Helm chart values via module variables and hardcoding other values for consistency.

## 1.0.2

### Changed

- Upgrade Metrics Server Chart version to 6.2.1

## 1.0.1

### Changed

- modified the namespace variable to "devops".
- Updated module version to 1.0.1

## 1.0.0

### Added

- Initial release !2, !3
