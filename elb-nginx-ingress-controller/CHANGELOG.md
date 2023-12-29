# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## 8.2.0

### Added

- The module not supports version 4.9.x of the Helm chart.

### Fixed

- Add the `eks.amazonaws.com/compute-type: ec2` annotation to the controller pods to prevent them from running on Fargate nodes.  ELBs do not support Fargate nodes as backends.  If the controller pods were scheduled on a Fargate node, it would break all ingresses.

## 8.1.0

### Added

- The name of the Kubernetes namespace where the controller is deployed is now exposed through the `namespace` output to simplify the configuration of Kubernetes resources that must reside in the same namespace as the controller.

## 8.0.1

### Fixed

- Relabeling on the controller's ServiceMonitor has been disabled by [setting `honorLabels` to `true`](https://prometheus-operator.dev/docs/operator/api/#monitoring.coreos.com/v1.Endpoint).  When the Prometheus Operator relabels the `namespace` label to `exported_namespace`, it breaks [Flagger's built-in Prometheus queries](https://docs.flagger.app/usage/metrics#builtin-metrics) for the controller.

## 8.0.0

### Upgrade Notes

The kubectl provider's source has changed from `gavinbunney/kubectl` to `alekc/kubectl`.  To upgrade the module to version 8.0+, the following command must be run to change the source in the Terraform state file.

```shell
terraform state replace-provider gavinbunney/kubectl alekc/kubectl
```

### Changed

- **Breaking Change**: The kubectl provider's source has been changed from [`gavinbunney/kubectl`](https://registry.terraform.io/providers/gavinbunney/kubectl/latest) to [`alekc/kubectl`](https://registry.terraform.io/providers/alekc/kubectl/latest).  The `alekc/kubectl` implementation is a fork of `gavinbunney/kubectl`.  It fixes a number of bugs and updates its dependencies to newer versions.  A new version of the `gavinbunney/kubectl` implementation hasn't been released in two years and, based on the lack of activity in its Github project, appears to be dead.  Given that the provider is for managing K8s resources, it is important to use a version that is kept up-to-date with the K8s API.

## 7.1.0

### Added

- In version 1.9.x of the controller, the `nginx.ingress.kubernetes.io/configuration-snippet` ingress annotation is disallowed by default.  The new `allow_snippet_annotations` variable allows callers to configure the controller to allow the annotation.  It defaults to `false` due to the security implications related to allowing that level of nginx configuration customization.

## 7.0.0

### Added

- The module now supports version 4.8.x of the Helm chart.  It corresponds to [version 1.9.x](https://github.com/kubernetes/ingress-nginx/blob/main/changelog/Changelog-1.9.0.md) of the controller.
- The module now supports K8s 1.28 in addition to 1.24, 1.25, 1.26, and 1.27.

### Changed

- **Breaking Change**: The minimum version of Terraform supported by the module is now 1.5.
- **Breaking Change**: The minimum version of the AWS provider supported by the module is now 5.0.
- **Breaking Change**: The minimum version of the Kubernetes provider supported by the module is now 2.23.

### Removed

- **Breaking Change**: Dropped support for version 4.6.x of the Helm chart.

## 6.0.0

### Added

- The module now supports versions 4.6.x and 4.7.x of the Helm chart.  These versions correspond to versions [1.7.x](https://github.com/kubernetes/ingress-nginx/releases/tag/controller-v1.7.1) and [1.8.x](https://github.com/kubernetes/ingress-nginx/releases/tag/controller-v1.8.1) of the controller, respectively.
- The module now supports K8s 1.26 and 1.27 in addition to 1.24 and 1.25.
- The image registry containing the controller image can now be configured using the `image_registry` variable.  The image must be in the `ingress-nginx/controller` repository within the registry.
- The hostname of the ELB associated with the controller's service is exposed through the `elb_hostname` output.

### Changed

- **Breaking Change**: The minimum version of Terraform supported by the module is now 1.4.
- The pod and container security contexts have been modfied to support running the controller in namespaces enforcing the restricted Pod Security Standard.
- The values of the `node_selector` and `node_tolerations` variables are now applied to the webhook patch job pod.

### Removed

- **Breaking Change**: Dropped support for versions 4.3 and 4.4 of the Helm chart.
- **Breaking Change**: Dropped support for K8s versions lower than 1.24.

## 5.1.0

### Added

- The module now supports the option to deploy Grafana dashboards for nginx metrics.  The dashboards are deployed in Kubernetes configmaps to allow [Grafana's sidecar to discover them](https://github.com/grafana/helm-charts/tree/main/charts/grafana#sidecar-for-dashboards).
- The `grafana_dashboard_config` variable has been added to configure the Grafana dashboard deployment.  Its type matches the structure of the `dashboard_config` output in the kube-prometheus-stack module for easy integration.
- A default set of tolerations for the `kubernetes.io/arch` label are added to every pod to automatically support scheduling based on CPU architecture.  Both `amd64` and `arm64` are tolerated.

### Changed

- Reduced the maximum Helm release history from 10 down to 5.  The need to maintain a large number of releases is not necessary when using Terraform in combination with source control.  A small history is still useful for emergency roll-backs.

## 5.0.0

### Upgrade Notes

**Due to [changes in the way the controller handles leader election](https://github.com/kubernetes/ingress-nginx/blob/main/Changelog.md#131), the module must be upgraded to version 4.0.0 prior to upgrading to 5.0.0.**

### Added

- The [`kubectl Terraform provider`](https://registry.terraform.io/providers/gavinbunney/kubectl/latest) is now required by the module.
- Node selectors and tolerations can be configured with the new `node_tolerations` and `node_selector` variables.
- Support for installing [a ServiceMonitor resource](https://prometheus-operator.dev/docs/operator/api/#monitoring.coreos.com/v1.ServiceMonitor) has been added the module to enable Prometheus metrics scraping when the Prometheus Operator is installed in the k8s cluster.  The new `service_monitor` variable controls its deployment and settings.
- Pod anti-affinity has been added to prevent multiple controller pods running on the same node.

### Changed

- **Breaking Change**: The minimum Helm chart version supported by the module is now 4.4.0.  It deploys version 1.4.0 of the controller. Version 1.4.0 contains a number of breaking changes when compared to the controllers supported in 4.0.0 of the module.
- **Breaking Change**: The minimum supported Kubernetes version is 1.22.  The maximum is now 1.25.  A [`kubectl_server_version data resource`](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/data-sources/kubectl_server_version) has been added to the project as a way to enforce the version restriction.
- The default value for the `controller_replica_count` variable is now set to 2 for high availability.

### Removed

- The Kubernetes configmap used for leader election by older versions of the controller has been removed from the module.
- The [`kubernetes Terraform provider`](https://registry.terraform.io/providers/hashicorp/kubernetes/latest) is no longer required by the module.

## 4.0.0

### Added

- The [`fluentbit.io/parser_stdout`](https://docs.fluentbit.io/manual/pipeline/filters/kubernetes#kubernetes-annotations) annotation with the value `k8s-nginx-ingress` has been added to the pods to enable structured logging.
- **Breaking Change**: The Kubernetes configmap resource used by the controller to coordinate leader election has been added to the module. It was added to ensure it is removed when the module is uninstalled because the Helm chart does not manage it.  For exiting deployments, the configmap resource must be imported prior to applying the module upgrade.

  ```shell
  terraform import module.<module name>.kubernetes_config_map_v1.leader_election <namespace variable value>/ingress-controller-leader-<value of the ingress_class_resource variable's name attribute>
  ```

### Changed

- **Breaking Change**: Terraform 1.3 is now the minimum supported version due to the use of the `optional` object attribute feature on variable type constraints.
- **Breaking Change**: The `priority_class_name` now defaults to `system-cluster-critical` instead of the cluster default.  The variable no longer nullable either.  To use the cluster default, the variable must be set to an empty string.
- Modified the `chart_version` variable to limit to the charts that deploy version 1.3.0 of the controller or older.  Version 1.3.0 introduces the use of Kubernetes leases as the means of electing the leader when multiple controllers are deployed.  According to [the release notes for version 1.3.1](https://github.com/kubernetes/ingress-nginx/blob/main/Changelog.md#131), the controller must be upgraded to 1.3.0 first to perform the migration from using a configmap to using a lease.  By limiting the supported chart versions, the module can ensure the migration occurs.  The next release of the module will set the minimum chart version to 4.2.4, the first release to deploy version 1.3.1 of the controller.
- The controller now listens on port 8080 for HTTP and 8081 for HTTPS.  The default ports, 80 and 443, required the container to run with `allowPrivilegeEscalation` set to `true` in its security context.  The module is now able to set the `allowPrivilegeEscalation` setting to `false` because the new port numbers are outside of the [well-known port range](https://en.wikipedia.org/wiki/List_of_TCP_and_UDP_port_numbers#Well-known_ports).  The change comes from [an issue in the nginx ingress Github project](https://github.com/kubernetes/ingress-nginx/issues/7055#issuecomment-950571065).
- The type constraint on the `controller_pod_resources` and `ingress_class_resource` variables have been modified to make use of the `optional` object attribute feature added to Terraform in version 1.3.  It is now possible override the default values of individual attributes without specifying the default value for the other attributes when calling the module.
- Validation has been added to the `namespace` and `labels` variables.

### Removed

- **Breaking Change**: The `image_pull_secrets` variable has been removed as it is no longer required.

## 3.0.1

### Fixed

- Explicitly set the `ingressClassByName` variable to `true` to account for the lack of support for the new `ingressClassResource` value by [cert-manager](https://github.com/cert-manager/cert-manager/issues/4821) for `HTTP01` solvers. Notably according to [cert-manager ingress compatibility](https://cert-manager.io/docs/installation/upgrading/ingress-class-compatibility/#ingress-nginx) this value must be set to `true`.

## 3.0.0

### Fixed

- The module now correctly configures the Helm release to support [multiple deployments of the controller](https://kubernetes.github.io/ingress-nginx/user-guide/multiple-ingress/) in a cluster as well as [multiple deployments in the same namespace](https://github.com/kubernetes/ingress-nginx/issues/8144) in the same cluster.  The module ensures that the `controller.electionID` and `controller.ingressClassResource.controllerValue` values are unique.  For whatever reason, the chart doesn't do that by default.
- The validating webhook _should_ work correctly when the module is used to deploy multiple controllers as long as [version 1.1.2 of the controller is deployed](https://github.com/kubernetes/ingress-nginx/releases/tag/controller-v1.1.2).  The change to the controller code is available in [Github](https://github.com/kubernetes/ingress-nginx/pull/8221/files).  Version 4.0.18 of the Helm chart deploys 1.1.2 by default.

### Removed

- **Breaking Change**: Dropped support for version 3.x of the Helm chart.  The values supported by 3.x and 4.x differ enough that it is difficult to construct a correct release for both versions using the variables exposed by the module.  The 3.x chart is almost a year out-of-date as well.  It is long past time to move on.

## 2.0.0

### Changed

- **Breaking Change**: The `internal` variable no longer controls the value of the `service.beta.kubernetes.io/aws-load-balancer-internal` annotation on the k8s service resource.  It only controls the value of the Helm chart's `controller.service.internal.enabled` value.  The value of the annotation is hardcoded to `true`.  The module no longer supports public ELBs because they are not currently used with the ingress controller.  This change also aligns the module with the behavior of the values generated by the Ansible module.

### Fixed

- The `enable_admission_webhook` variable now works as intended.  Prior to this release, the web hook was always enabled regardless of the value of the variable.
- Correctly Set the flag to enable metrics on controller pod.

## 1.2.1

### Fixed

- Explicitly set the `controller.ingressClassResource.enabled` value on the Helm chart to `true` to account for the fact that the 3.x versions of the chart default it to `false`.  When it is set to `false`, the `ingressClass` resource is not created.

## 1.2.0

### Added

- The `controller_replica_count` variable has been added to support running more than one controller pod.
- The `priority_class_name` variable has been added to support adding a Kubernetes priority class to the controller pods.

## 1.1.0

### Added

- Added the `enable_elb_access_logs` variable to make the ELB access logs optional.

### Fixed

- Fixed the invalid structure of the image pull secrets value passed to Helm.

## 1.0.0

### Added

- Initial release
