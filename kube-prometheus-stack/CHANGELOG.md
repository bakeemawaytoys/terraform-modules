# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## 6.0.0

### Added

- The module now supports major versions 51, 52, 53, 54, and 55 of the Helm chart.
- The tolerations, node selector, image repository, persistent volume size, and resources for Alertmanager pods are now configurable with the `alertmanager_pod_configuration` variable.
- The tolerations, node selector, image repository, and resources for Grafana pods are now configurable with the `grafana_pod_configuration` variable.
- The tolerations, node selector, image repository, persistent volume size, and resources for Prometheus pods are now configurable with the `prometheus_pod_configuration` variable.
- The tolerations, node selector, image repository, and resources for the Prometheus Operator pods are now configurable with the `prometheus_operator_pod_configuration` variable.
- It is now possible to configure the Kube State Metrics pods using the `kube_state_metrics_pod_configuration` variable.  The variable allows customization of the image registry, node selector, tolerations, replica count, and resources.

### Changed

- The `max_history` attribute of the `helm_release` resource has been set to `2`.  Previously it had been unset.  The limit is set to two is because a large history isn't required when Terraform is used in conjunction with Git to manage a Helm release.
- The memory requests and limits for the config reloader sidecar container has been increased from 50Mi to 64Mi base on recommendations made by Goldilocks.
- The memory and CPU requests and limits for the Prometheus Node Exporter pods have been set to 50m and 128Mi.  The values were chosen based on recommendations made by Goldilocks.  Previously, they were unset.  They have been set to improve Karpenter's ability to select instance types when provisioning a node.
- The Kube State Metrics pods now have the `system-cluster-critical` priority class to ensure it is always available.
- Previously, the Alertmanager image was always pulled from the same registry specified for the Prometheus and Node Exporter images.  For consistency and flexibility, Alertmanager registry can be specified separately using the `image_registry` attribute on the new `alertmanager_pod_configuration` variable.
- **Breaking Change**: The minimum Terraform version supported by the module has been changed from 1.5 to 1.6.
- All pods are now configured to tolerate taints for the `kubernetes.io/arch` node label when the value is either `amd64` or `arm64`.  The purpose of these taints is to ease the transition to Graviton instance types.  The tolerations are always present.  If custom tolerations are specified through module variables, the `kubernetes.io/arch` tolerations are added to the custom tolerations and then passed to the Helm release.
- All pods are now configured with a node selector to ensure they only run on Linux nodes.  There are no plans to deploy Windows nodes, but the selector has been added just in case.  If a custom node selector is provided through a module variable, the Linux node selector is merged into the custom node selector and then passed to the Helm release.

### Removed

- **Breaking Change**: The `alertmanager_volume_size` variable has been replaced by the `volume_size` attribute on the new `alertmanager_pod_configuration` variable.
- **Breaking Change**: The `prometheus_operator_image_registry` variable has been replaced by the `image_registry` attribute on the new `prometheus_operator_pod_configuration` variable.
- **Breaking Change**: The `prometheus_image_registry` variable has been replaced by the `image_registry` attribute on the new `prometheus_pod_configuration` variable.
- **Breaking Change**: The `prometheus_volume_size` variable has been replaced by the `volume_size` attribute on the new `prometheus_pod_configuration` variable.

## 5.1.0

### Added

- The URL of the Prometheus Kubernetes service is now exposed by the module through the `prometheus_service_url` output.  The new output simplifies the configuration of other Kubernetes workloads that require access to the Prometheus API.
- The name of the Kubernetes namespace where the controller is deployed is now exposed through the `namespace` output to simplify the configuration of Kubernetes resources that must reside in the same namespace as the controller.

## 5.0.0

### Upgrade Notes

The kubectl provider's source has changed from `gavinbunney/kubectl` to `alekc/kubectl`.  To upgrade the module to version 5.0+, the following command must be run to change the source in the Terraform state file.

```shell
terraform state replace-provider gavinbunney/kubectl alekc/kubectl
```

### Changed

- **Breaking Change**: The kubectl provider's source has been changed from [`gavinbunney/kubectl`](https://registry.terraform.io/providers/gavinbunney/kubectl/latest) to [`alekc/kubectl`](https://registry.terraform.io/providers/alekc/kubectl/latest).  The `alekc/kubectl` implementation is a fork of `gavinbunney/kubectl`.  It fixes a number of bugs and updates its dependencies to newer versions.  A new version of the `gavinbunney/kubectl` implementation hasn't been released in two years and, based on the lack of activity in its Github project, appears to be dead.  Given that the provider is for managing K8s resources, it is important to use a version that is kept up-to-date with the K8s API.

## 4.0.0

### Added

- The module now supports version 51.x of the kube-prometheus-stack Helm chart.
- A [Kubernetes resource quota](https://kubernetes.io/docs/concepts/policy/resource-quotas/) was added to the Grafana dashboard namespace to prevent workloads from running in the namespace.
- **Breaking Change**:  The Vault entities and entity aliases associated with the Grafana and Alertmanager auth roles are now managed by the module.  When upgrading the module, import blocks must be added for them.

### Changed

- **Breaking Change**: The minimum version of Terraform supported by the module is now set to 1.5.
- **Breaking Change**: The Grafana and Alertmanager service accounts are now managed by Terraform instead of Helm.  When upgrading the module, import blocks must be added for them.

### Removed

- **Breaking Change**: Dropped support for versions 40.x, 41.x, 42.x and 43.x of the kube-prometheus-stack Helm chart because they are very old and maintain support for them while also adding support for 51.x will result in too much effort for very little gain.

## 3.5.0

### Changed

- Disabled creation of Pod Security Policies to allow the module to be used on clusters running Kubernetes 1.25+.

## 3.4.0

### Added

- The optional `alertmanager_volume_size` variable has been added to permit modifications to the size of the Alertmanager pods' persistent volumes.
- The optional `prometheus_volume_size` variable has been added to permit modifications to the size of the Prometheus pods' persistent volumes.

## 3.3.0

### Added

- The module now supports major versions [42](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack#from-41x-to-42x) and [43](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack#from-42x-to-43x) of the kube-prometheus-stack Helm chart.
- The `eks.amazonaws.com/compute-type: ec2` annotation has been added to both the Prometheus pods and the Alertmanager pods to prevent EKS from scheduling them on Fargate nodes.  Prometheus uses EBS persistent volumes and those are unsupported on Fargate.

### Changed

- The PrometheusRule selector has been reconfigured to select all PrometheusRule resources regardless of namespace or label.  The previous behavior was to only load the resources in the same namespace as the Helm release that also have the `release: <Helm release name>` label.
- The Probe selector has been reconfigured to select all PrometheusRule resources regardless of namespace or label.  The previous behavior was to only load the resources in the same namespace as the Helm release that also have the `release: <Helm release name>` label.

## 3.2.0

### Added

- The module now includes a Kubernetes namespace named `grafana-dashboards`.  The namespace is intended to be used as shared location for applications to install configmaps containing Grafana dashboards.  A namespace separate from the one in which Grafana is deployed serves two purposes.  The first is that the sidecars won't need to monitor all namespaces to find custom dashboards.  This is beneficial from both a security aspect and an performance aspect.  The second is that the default behavior of the sidecars is to monitor the namespace in which it is running.  The separate namespace removes the need to grant permissions to create resources in Grafana's namespace.
- The `dashboard_config`, `dashboard_folder_annotation_key`, `dashboard_label_key`, `dashboard_label_value`, `dashboard_label`, and `dashboard_namespace` outputs have been added to expose the values required to install custom dashboards in the new namespace.

### Changed

- A security context has been added to the Grafana sidecar containers.
- The Grafana sidecar containers have been reconfigured so that they only look for configmaps in an effort to limit the exposure of secrets.  The only reason the sidecar would need to access secrets is to load Grafana data sources that include credentials.  There aren't any data sources deployed in any of the k8s clusters that have such data sources and there are no plans to deploy any.
- The [`viewers_can_edit`](https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/#viewers_can_edit) option in Grafana is been set to `true` to allow users in the `Viewers` role to use [Grafana's Explore UI](https://grafana.com/docs/grafana/latest/explore/).  The change is primarily to allow non-admin users to search the Loki data in the production data cluster.
- A Kubernetes cluster role is no longer created for the Grafana service account.  It is only required for the sidecar and the sidecar is not configured to look at namespaces outside of those defined in the module.  Kubernetes roles are used instead to grant permission to the module namespaces.

## 3.1.0

### Changed

- The module no longer downloads the CRD files from Github because of Github API rate limits.  As more and more of the modules in this project were modified to download CRD files, the risk of hitting the rate limit increased.  To avoid the issue, the CRDs for the supported chart versions are now bundled in the module.  While this increases the maintenance burden of this module, it eliminates a pain point when consuming the module.
- The `chart_version` variable is now restricted to the Helm chart versions whose CRDs are bundled in the module.

### Removed

- The `http` provider is no longer required by the module.  It was only used to download the CRD files.

## 3.0.0

### Upgrade Note

The minimum Helm chart version supported by this module is now 40.x.  [As mentioned in the kube-prometheus-stack Helm chart's README file](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack#from-39x-to-40x), the Prometheus Node Explorer's daemonset **must be deleted** before upgrading to 40.x or later due to changes in the set's label selector.

### Added

- All deployments now have the `system-cluster-critical` priority class.
- All daemonsets now have the `system-node-critical` priority class.

### Changed

- **Breaking Change**: The minimum supported Helm chart version is now 40.0 and the maximum is now 41.x.

## 2.0.0

### Added

- **Breaking Change**: The Hashicorp Vault provider is now required by the module.
- **Breaking Change**: A new required variable named `vault_auth_backend_path` has been added to allow the module to create and manage the Vault authentication roles that are now required to inject secrets into pods.

### Changed

- **Breaking Change**: Replaced use of the [Vault Secrets Operator](https://github.com/ricoberger/vault-secrets-operator) with the [Hashicorp Secret Store CSI Provider](https://github.com/ricoberger/vault-secrets-operator).
- The module now supports chart versions 34.x.x through 39.x.x.

### Fixed

- Introduced a local value to work around an issue that prevented use of the module to install a new deployment.

### Removed

- Removed the AWS provider as a requirement because it isn't used by the module.

## 1.0.0

### Added

- Initial release
