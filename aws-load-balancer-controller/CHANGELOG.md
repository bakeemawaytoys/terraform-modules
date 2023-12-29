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
- **Breaking Change**: The minimum version of Terraform supported by the module is now 1.6.
- **Breaking Change**: The minimum version of the AWS provider supported by the module has been changed from 4.x to 5.x.
- The minimum version of the Kubernetes provider has been changed from 2.13 to 2.23.
- The minimum version of the Helm provider has been changed from 2.7 to 2.11.

## 3.2.0

### Added

- The module now supports version 1.6.x of the Helm chart ([controller version 2.6.x](https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/tag/v2.6.0)).

## 3.1.0

### Added

- The module now supports versions 2.5.2 and 2.5.3 of the controller.  These correspond to versions 1.5.3 and 1.5.4 of the Helm chart.
- Modified the controller's IAM policy to allow it to use the Resource Group API to find resources instead of using the API of each individual service.  [The feature that uses this API was added to the controller in version 2.5.2 but it is not enabled yet](https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/tag/v2.5.2).
- The `"kubernetes.io/cluster" = "<cluster name>"` tag is now applied to every AWS resource in the module.

### Fixed

- The `app.kubernetes.io/instance`, `app.kubernetes.io/name`, and `app.kubernetes.io/version` labels have been removed from the `IngressClassParams` resources that are managed by the module.  The values of the labels referenced dynamic attributes of the `helm_release` resource.  As a result, every time Karpenter was updated, Terraform would modify the the `IngressClassParams` resources to update the labels.  The modifications would fail because the `helm_release` resource modified the `IngressClassParams` CRD during the during the apply run.  Terraform reported a `Provider produced inconsistent final plan` error due to the CRD differences between the plan and apply runs.  While a second apply run would succeed, it wasn't ideal and the errors were false alarms.  Removing the labels removes the need to change the `IngressClassParams` resources during upgrades.

## 3.0.0

### Added

- **Breaking Change**: New attributes `sslPolicy` and `inboundCIDRs` have been added to the IngressClassParams resource. Chart version
  1.5.0 or newer must be used.
- The `defaultTargetType` has been set to `ip` in the helm chart so ingresses no longer need to add the annotation explicitly.
- `serviceMutatorWebhook` added to `enabled_features` variable to allow defaulting to this controller for all LoadBalancer services.

## 2.0.1

### Fixed

- Reconfigured the backend security group's egress rule to allow all ports. When an ingress is configured to target IPs instead of instances, the pod's exposed ports are used. Pod ports can include reserved ports in addition to ephemeral ports.

## 2.0.0

### Added

- The `service_monitor` variable has been added to control the deployment of a Kubernetes `ServiceMonitor` resource. The `kube-prometheus-stack` Helm chart's CRDs must be installed prior to deploying the `ServiceMonitor` resource.
- The `node_selector` and `node_tolerations` variables have been added to control where the controller's pods are scheduled.
- Validation has been added to the `namespace`, and `labels` variables.
- The `default_tls_security_policy` variable allows for configuration of the TLS listener policies applied to
- The Helm release has been configured to deploy a Kubernetes pod disruption budget that requires at least one pod at all times.
- The `default_load_balancer_tags` variable is now available to control the set of AWS tags applied every AWS resource managed by the controller.
- To simplify adding the [pod readiness gate](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/deploy/pod_readiness_gate) to a namespace, the required K8s labels are exposed with the new `pod_readiness_gate_namespace_labels` output
- The ALB access log settings can be configured with the optional `alb_access_logs` variable.
- **Breaking Change**: The `eks_cluster` variable has been introduced to consolidate the variables related to the EKS cluster into one variable of type object. In addition to consolidating existing variables, its attributes add new required variables. The new attributes are used to simplify construction of the controller's IAM role's trust policy.
- The default behavior of the controller is to create and manage a backend security group shared by all of the ALBs it manages. The behavior has been disabled in favor of explicitly managing the backend security group in Terraform. This will ensure the lifecycle of the group is full managed. For a more detailed description of the security groups required by the controller, see <https://github.com/kubernetes-sigs/aws-load-balancer-controller/issues/2118>

### Changed

- The tags in the `aws_default_tags` data resource are no longer added to the set of default tags applied to resource managed by the controller. The tags applied to this module's resources don't necessarily make sense for the load balancer resources. To add the tags in the `aws_default_tags` data resource, use the new `default_load_balancer_tags` variable.
- Enabled the use of K8s Endpoint Slices to determine the endpoints for IP targets.
- The default value of the `enabled_features` variable has been changed from an empty list to a list containing `wafv2`. Of the three available features, it is the only one we plan on using.
- Limited the allowed chart versions 1.4.5, 1.4.6, and 1.4.7 by modifying the validation on the `chart_version` variable. In all likelihood, only 1.4.7 will be deployed as it is the latest but allowing a few older versions makes it easy to downgrade in case there is a bug in 1.4.7.
- **Breaking Change**: Replaced the ingress class named `alb` (created by the Helm chart) with two classes. The `internet-facing-application-load-balancer` ingress class is for creating ALBs that can be accessed from the Internet. Its corresponding IngressClassParams resource is configurable with the new `internet_facing_ingress_class_parameters` variable. The other ingress class, named `internal-application-load-balancer`, is for creating private ALBs. It is configurable with the new `internal_ingress_class_parameters` variable. The [`scheme` parameter](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/guide/ingress/ingress_class/#specscheme) on each class is hardcoded to ensure they are only used to create their type of ALB.

### Removed

- Version 2.0.0+ of the controller [only supports one deployment per cluster](https://github.com/kubernetes-sigs/aws-load-balancer-controller/issues/2185). The `release_name`, `service_account_name` variables have been removed because they aren't useful unless multiple controllers can be deployed.
- The `cluster_name` and `service_account_oidc_provider_arn` variables have been removed. They have been replaced with attributes on the new `eks_cluster` variable.

## 1.0.0

### Added

- Initial release !2
