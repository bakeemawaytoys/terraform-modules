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

### Added

- The module now supports deploying cert-manager version 1.13.2 in addition to version 1.12.6.  Version 1.13.0 added support for configuring the cert-manager components with files instead of using command line options.  The module will continue to use the command line options until support for version 1.12 has been removed.
- The module now supports integration with [Goldilocks](https://github.com/FairwindsOps/goldilocks).  The `enable_goldilocks` variable controls the status of the integration.  It is enabled by default.
- The [Restricted Pod Security Standard](https://kubernetes.io/docs/concepts/security/pod-security-standards/#restricted) is now applied to all pods running in cert-manager's Kubernetes namespace.  The new `pod_security_standards` variable can be used to apply a different policy should the need arise but changing the policy should be avoided if at all possible.
- The `namespace` output has been added to expose cert-manager's namespace name.

### Changed

- **Breaking Change**: The kubectl provider's source has been changed from [`gavinbunney/kubectl`](https://registry.terraform.io/providers/gavinbunney/kubectl/latest) to [`alekc/kubectl`](https://registry.terraform.io/providers/alekc/kubectl/latest).  The `alekc/kubectl` implementation is a fork of `gavinbunney/kubectl`.  It fixes a number of bugs and updates its libraries to newer versions.  A new version of the `gavinbunney/kubectl` implementation hasn't been released in two years and, based on the lack of activity in its Github project, appears to be dead.  Given that the provider is for managing K8s resources, it is important to use a version that is kept up-to-date with the K8s API.
- **Breaking Change**: The `cert-manager` namespace resource has been added to the module and all Kubernetes resources are now deployed in the namespace.  This change was made to isolate cert-manager because it is a critical cluster service with elevated privileges within the cluster.  It will also ensure `cert-manager` deployments are consistent across clusters.
- **Breaking Change:** The `cluster_name` variable has been merged into the new `eks_cluster` variable.  The new variable is an object whose attributes match the outputs of the [`eks-cluster` module](../eks-cluster/) to simplify supplying a value to the variable.  The new variable's attribute eliminate the need to use data resources to fetch the EKS cluster's IAM OIDC identity provider.  In certain scenarios, the data resources would be read at apply time instead of plan time and that limited Terraform's ability to include all changes in the plan.
- The 1.12.x version of cert-manager supported by the module has been changed to 1.12.5 to [1.12.6 to ensure CVE fixes are deployed](https://cert-manager.io/docs/releases/release-notes/release-notes-1.12#v1126).

### Removed

- **Breaking Change**: The `namespace` variable has been removed.  The name of the namespace is now hardcoded to `cert-manager` to ensure consistency across K8s clusters.  Should the need arise to change it, the variable can be added to the module again.
- **Breaking Change**: The `service_account_name` variable has been removed.  The name of the cert-manager controller's service account is now hardcoded to `cert-manager` to ensure consistency across K8s clusters.  Should the need arise to change it, the variable can be added to the module again.

## 4.0.1

### Changed

- Changed the supported cert-manager version from 1.12.1 to [1.12.5](https://cert-manager.io/docs/releases/release-notes/release-notes-1.12#v1125) to apply fixes for a CVE and a memory leak, among others.

## 4.0.0

### Added

- The module now supports cert-manager version [1.12.1](https://cert-manager.io/docs/release-notes/release-notes-1.12/).  Support 1.11.x was not added because supporting both 1.11 and 1.12 would add unnecessary complexity to the module.

### Changed

- **Breaking Change**: [Restricted the CA injector to managing cert-manager's internal resources](https://cert-manager.io/docs/release-notes/release-notes-1.12/#cainjector).  The injector is not used with anything else at this time and the change can potentially reduce resource usage of the it's pods.  While this change shouldn't break anything currently deployed to the EKS clusters, it is marked as a breaking change just in case.
- Pod disruption budgets are now enabled on the controller, CA injector, and webhook deployments.
- The controller, CA injector, and webhook have been configured to format their logs in JSON.
- Removed the `--enable-certificate-owner-ref` controller argument from the `extraArgs` Helm value in favor of using the `enableCertificateOwnerRef` value added to the chart in version 1.12.0.
- Removed the `--acme-http01-solver-image` controller argument from the `extraArgs` Helm value in favor of using the `acmesolver` value added to the chart in version 1.12.0.
- The minimum supported version of the AWS provider is 4.67.0.
- The minium supported version of the Helm provider is 2.9.0

### Removed

- **Breaking Change**: Dropped support for cert-manager versions 1.9.x and 1.10.x.

## 3.2.0

### Added

- The optional `http_challenge_solver_pod_configuration` variable has been added to allow for customization of the resource requests and limits of the pods created to solve ACME HTTP01 challenges.  The variables default values are set to the same default values used by the cert-manager controller except for the CPU request.  It has been increased from 10m to 50m to give it a 2:1 limit-to-request ratio.  The increase will allow the pods to start in Kubernetes namespaces containing [gitlab-application-k8s-namespace](../gitlab-application-k8s-namespace/) module's default limit range resource.

## 3.1.0

### Changed

- Disabled pod security policies for the helm chart as they are no longer supported in [Kubernetes 1.25](https://kubernetes.io/blog/2022/08/04/upcoming-changes-in-kubernetes-1-25/#podsecuritypolicy-removal).

## 3.0.2

### Fixed

- In version 1.10.x of the Helm chart, the pod security contexts were updated to add the `RuntimeDefault` seccomp profile. As a result of that change, the default pod security profile deployed by the chart would add the app armor annotation in addition to the seccomp annotation. After upgrading to the new version, Kubernetes blocked the pods from starting because app armor is not enabled on Bottlerocket. The Helm release values have been modified to remove app armor from the pod security policy.

## 3.0.1

### Fixed

- Version 3.0.0 of the module deploys the v1.11.0-alpha.1 CRDs when the chart version is set to v1.10.1. The correct CRDs are now deployed for 1.10.1.

## 3.0.0

### Added

- The module now supports cert-manager 1.10.1.
- Integration with AlertManager is now supported. The optional `enable_prometheus_rules` variable controls the deployment of [a PrometheusRules resource](https://prometheus-operator.dev/docs/user-guides/alerting/#deploying-prometheus-rules). The resource contains the rules provided by [the Monitoring Mixins project](https://monitoring.mixins.dev/cert-manager/).
- The optional `node_tolerations` variable has been added to control pod scheduling. Unlike the node selectors, it is applied to every pod deployed by the Helm release.
- A default set of tolerations for the `kubernetes.io/arch` label are added to every pod to automatically support scheduling based on CPU architecture. Both `amd64` and `arm64` are tolerated.
- The module now supports the option to deploy Grafana dashboards for cert-manager metrics. The dashboards are deployed in Kubernetes configmaps to allow [Grafana's sidecar to discover them](https://github.com/grafana/helm-charts/tree/main/charts/grafana#sidecar-for-dashboards).
- The `grafana_dashboard_config` variable has been added to configure the Grafana dashboard deployment. Its type matches the structure of the `dashboard_config` output in the kube-prometheus-stack module for easy integration.
- A new optional variable named `service_monitor` has been added to control the deployment of a [Prometheus Operator ServiceMonitor resource](https://prometheus-operator.dev/docs/operator/api/#monitoring.coreos.com/v1.ServiceMonitor) for scraping metrics.
- **Breaking Change**: The `kubernetes` provider is now required by the module.

### Changed

- Reduced the maximum Helm release history from 25 down to 5. The need to maintain a large number of releases is not necessary when using Terraform in combination with source control. A small history is still useful for emergency roll-backs.

### Removed

- **Breaking Change**: Dropped support for cert-manager versions in the 1.8.x line and all but 1.9.2 in the 1.9.x line.
- The `http` provider has been removed from the `required_providers` block. It should have been removed in 2.2.0.

## 2.2.0

### Changed

- The module no longer downloads the CRD files from Github because of Github API rate limits. As more and more of the modules in this project were modified to download CRD files, the risk of hitting the rate limit increased. To avoid the issue, the CRDs for the supported chart versions are now bundled in the module. While this increases the maintenance burden of this module, it eliminates a pain point when consuming the module.
- The `chart_version` variable is now restricted to the Helm chart versions whose CRDs are bundled in the module.

### Removed

- The `http` provider is no longer required by the module. It was only used to download the CRD files.
- Removed the unused k8s provider from the `required_providers` block.

## 2.1.1

### Fixed

- Added the missing image tag to the controller's `--acme-http01-solver-image` argument. It is set to the same value as the `chart_version` variable to ensure all components use the same cert-manager release.

## 2.1.0

### Added

- The default certificate issuer to use with ingresses that don't specify one can now be configured with the optional `default_ingress_issuer` variable. See <https://cert-manager.io/docs/usage/ingress/#optional-configuration> for more details.

### Fixed

- Set `create_namespace` to `false` on the Helm release to ensure it doesn't create a namespace.

## 2.0.0

### Upgrade Guide

The Cert Manager Customer Resource Definition resources are now managed by Terraform. As part of the upgrade process, the CRDs must be imported into the Terraform state. The following script can be used to import them by replacing `example` with the actual name of your module.

```shell
#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

terraform import 'module.example.kubectl_manifest.crd["/apis/apiextensions.k8s.io/v1/customresourcedefinitions/certificaterequests.cert-manager.io"]' apiextensions.k8s.io/v1//CustomResourceDefinition//certificaterequests.cert-manager.io
terraform import 'module.example.kubectl_manifest.crd["/apis/apiextensions.k8s.io/v1/customresourcedefinitions/certificates.cert-manager.io"]' apiextensions.k8s.io/v1//CustomResourceDefinition//certificates.cert-manager.io
terraform import 'module.example.kubectl_manifest.crd["/apis/apiextensions.k8s.io/v1/customresourcedefinitions/challenges.acme.cert-manager.io"]' apiextensions.k8s.io/v1//CustomResourceDefinition//challenges.acme.cert-manager.io
terraform import 'module.example.kubectl_manifest.crd["/apis/apiextensions.k8s.io/v1/customresourcedefinitions/clusterissuers.cert-manager.io"]' apiextensions.k8s.io/v1//CustomResourceDefinition//clusterissuers.cert-manager.io
terraform import 'module.example.kubectl_manifest.crd["/apis/apiextensions.k8s.io/v1/customresourcedefinitions/issuers.cert-manager.io"]' apiextensions.k8s.io/v1//CustomResourceDefinition//issuers.cert-manager.io
terraform import 'module.example.kubectl_manifest.crd["/apis/apiextensions.k8s.io/v1/customresourcedefinitions/orders.acme.cert-manager.io"]' apiextensions.k8s.io/v1//CustomResourceDefinition//orders.acme.cert-manager.io

```

### Added

- The `image_registry` variable has been added to support overriding the default image registry (quay.io) in the Helm chart.
- The optional `cluster_resource_namespace` variable has been added support configuring [the namespace where cert-manager's cluster-scoped resources will create namespaced resources](https://cert-manager.io/docs/configuration/#cluster-resource-namespace). If the variable is not set, it defaults to the value of the `namespace` variable.
- The `issuer_acme_dns01_route53_solvers` and `issuer_acme_dns01_route53_solvers_by_zone` outputs have been added to simply the creation of `ClusterIssuer` and `Issuer` resources.
- The optional `log_level` variable has been added to enable control of over the verbosity of the logs generated by the cert-manager components. It defaults to the same value as the Helm chart.

### Changed

- **Breaking Change**: The module now requires Terraform 1.3 or later due to the use of [optional object type attributes](https://www.terraform.io/language/expressions/type-constraints#optional-object-type-attributes).
- **Breaking Change**: The Cert Manager CRDs are now managed by Terraform instead of Helm. While the Helm chart does include hooks to install and updated the CRDs, Terraform will manage the full lifecycle. To support implement CRD managment, the [`kubectl`](https://registry.terraform.io/providers/gavinbunney/kubectl) and [`http`](https://registry.terraform.io/providers/hashicorp/http) providers are now required.
- The validation on `chart_version` variable now constrains the value to the Helm chart versions the module has been designed against. It currently supports versions 1.8.x and 1.9.x.
- The `controller_pod_configuration`, `ca_injector_pod_configuration`, and `webhook_pod_configuration` variables have been replaced with the`controller_pod_resources`,`injector_pod_resources`, and`webhook_pod_resources` variables. The new variables support specifying replica counts and node selectors in additional to the resource limits and requests supported by the old variables. The new variables also make use of Terraform 1.3's optional object attributes to define default values and simplify overriding those defaults.
- The `acme_dns01_route53_solvers` variable has been introduced as a replacment for the `route53_zone_names` variable. The new variable allows for more control over the the DNS records that cert-manager is allowed to create in Route53. The variable is used to generate the AWS IAM policy attached to cert-manager's policy. The policy makes heavy use of the [resource record set permissions](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-permissions.html) that were recently introduced.
- The default resource requests and limits have been increased for every workload.

### Fixed

- The labels specified in the `labels` variable are now applied to every K8s resource in the module.

### Removed

- The optional [ingress-shim](https://cert-manager.io/docs/usage/ingress/#optional-configuration) is no longer set in the Helm release's values as it is no longer needed.

## 1.0.0

### Added

- Initial release !2
