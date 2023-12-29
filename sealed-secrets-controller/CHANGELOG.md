# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

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

- The module now supports version 2.13.x of the Helm chart (version 0.24.x of the controller).

### Changed

- **Breaking Change**: The minimum Terraform version supported by the module is now 1.5.
- **Breaking Change**: The minimum Helm provider version supported by the module is now 2.11.
- **Breaking Change**: The minimum Kubernetes provider version supported by the module is now 2.23.

### Removed

- **Breaking Change**: Dropped support for all chart versions older than 2.13.x.

## 3.3.0

### Changed

- Disabled pod security policies for the helm chart as they are no longer supported in [Kubernetes 1.25](https://kubernetes.io/blog/2022/08/04/upcoming-changes-in-kubernetes-1-25/#podsecuritypolicy-removal).

## 3.2.1

### Fixed

- Fixed an issue where the Grafana configmap label logic fails when the `grafana_dashboard_config` variable is null.

## 3.2.0

### Added

- Integration with AlertManager is now supported. The optional `enable_prometheus_rules` variable controls the deployment of [a PrometheusRules resource](https://prometheus-operator.dev/docs/user-guides/alerting/#deploying-prometheus-rules). The resource contains the rules provided by [the Monitoring Mixins project](https://monitoring.mixins.dev/sealed-secrets/).
- A default set of tolerations for the `kubernetes.io/arch` label are added to every pod to automatically support scheduling based on CPU architecture. Both `amd64` and `arm64` are tolerated.
- The module now supports the option to deploy Grafana dashboards for cert-manager metrics. The dashboards are deployed in Kubernetes configmaps to allow [Grafana's sidecar to discover them](https://github.com/grafana/helm-charts/tree/main/charts/grafana#sidecar-for-dashboards).
- The `grafana_dashboard_config` variable has been added to configure the Grafana dashboard deployment. Its type matches the structure of the `dashboard_config` output in the kube-prometheus-stack module for easy integration.
- Support for installing [a ServiceMonitor resource](https://prometheus-operator.dev/docs/operator/api/#monitoring.coreos.com/v1.ServiceMonitor) has been added the module to enable Prometheus metrics scraping when the Prometheus Operator is installed in the k8s cluster. The new `service_monitor` variable controls its deployment and settings.

## 3.1.0

### Changed

- The module no longer downloads the CRD files from Github because of Github API rate limits. As more and more of the modules in this project were modified to download CRD files, the risk of hitting the rate limit increased. To avoid the issue, the CRDs for the supported chart versions are now bundled in the module. While this increases the maintenance burden of this module, it eliminates a pain point when consuming the module.
- The `chart_version` variable is now restircted to the Helm chart versions whose CRDs are bundled in the module.

### Removed

- The `http` provider is no longer required by the module. It was only used to download the CRD files.

## 3.0.0

## Added

- The module now supports the 0.19 versions of the controller. The validation on the `chart_version` variable has been modified to allow the corresponding Helm chart versions in the 2.7.1 line.
- The `node_tolerations` and `node_selector` variables have been added to optionally control where the controller pod is scheduled.

## Changed

- Set the `force_conflicts` attribute to `true` on the `kubectl_manifest` resources that manage the CRDs. When updating resources that were created by Helm and then imported into TF, k8s field management can prevent the update because Helm owns the fields. Forcing updates will ignore field management.
- **Breaking Change**: Set the minimum Terraform version to 1.3 due to the use of `optional` object attributes on variables.
- The `pod_resources` variable has been reworked to make use of `optional` object attributes in the type definition to enable selective overrides of the default attribute values.

## Removed

- **Breaking Change**: The default value has been removed from the `chart_version` variable to make chart upgrades explicit and independant of module upgrades.

## 2.0.0

Prior to upgrading to version 2.x, the `SealedSecret` CRD resource must be imported into the Terraform state by running the following command. Replace `<module-name>` in the command with the actual name of your module call.

```shell
terraform import 'module.<module-name>.kubectl_manifest.crd["bitnami.com_sealedsecrets.yaml"]' 'apiextensions.k8s.io/v1//CustomResourceDefinition//sealedsecrets.bitnami.com'
```

### Changed

- **Breaking Change**: The module now manages the SealedSecret custom resource definition instead of relying on the Helm chart to manage it. Helm 3 has built in support for installing CRDs as part of a chart but [it doesn't provide a way to update them or delete them](https://helm.sh/docs/chart_best_practices/custom_resource_definitions/). The Terraform Helm provider has the same behavior because, under the hood, it is using the same codebase as the Helm CLI tool. Some Helm charts use jobs to update the CRDs but the Sealed Secrets Controller's chart, as of version 2.6.9, does not do this.
- Set the default and minimum value of the `chart_version` variable to `2.6.9` to ensure [the newer SealedSecret CRD with a full schema](https://github.com/bitnami-labs/sealed-secrets/blob/main/RELEASE-NOTES.md#v0184) is installed.
- The module now requires the [`http` provider](https://registry.terraform.io/providers/hashicorp/http/latest) and the [`kubectl` provider](https://registry.terraform.io/providers/gavinbunney/kubectl/latest) in order to manage the CRD resource(s).

## 1.1.0

### Added

- A new rule has been added to the `sealed-secret-edit` aggregate cluster role to support reading the `status` sub-resource of `sealedsecret` resources.

### Fixed

- Corrected the list the verbs on the `sealed-secret-edit` aggregate cluster role. It was set to `*` but that apparently doesn't work. As a result, the role could not perform any write actions on any `sealedsecret` resources. The individual verbs supported by the `sealedsecret` CRD are now listed out in the rules of the custer role. The `deletecollection` verb is supported by the resource but is is not included to prevent accidentally deleting multiple secrets at once.
- Set the default value of the `chart_version` to the latest version, 2.6.2.

## 1.0.2

### Fixed

- Reverted the default value of the `image_registry` varible back to docker.io because the repository in ghcr.io is not the same as Docker Hub. Therefore, ghcr.io breaks the module.

## 1.0.1

### Fixed

- Modified the validation logic on the `image_registry` varible to use the `can` function instead of the `try` function. The `try` function does not return a boolean there for the validation logic was broken.
- Set the default value of the `image_registry` varible to _ghcr.io_ instead of _docker.io_ to avoid Docker Hub's rate limiting.

## 1.0.0

### Added

- Initial release
