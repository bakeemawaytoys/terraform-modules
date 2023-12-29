# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## 7.1.0

### Added

- The module now supports deploying Karpenter v0.31.3.

### Fixed

- The validation message on the `chart_version` has fixed.  It now includes the 0.31.x versions supported by the module.

## 7.0.0

### Upgrade Notes

The kubectl provider's source has changed from `gavinbunney/kubectl` to `alekc/kubectl`.  To upgrade the module to version 7.0+, the following command must be run to change the source in the Terraform state file.

```shell
terraform state replace-provider gavinbunney/kubectl alekc/kubectl
```

### Changed

- **Breaking Change**: The kubectl provider's source has been changed from [`gavinbunney/kubectl`](https://registry.terraform.io/providers/gavinbunney/kubectl/latest) to [`alekc/kubectl`](https://registry.terraform.io/providers/alekc/kubectl/latest).  The `alekc/kubectl` implementation is a fork of `gavinbunney/kubectl`.  It fixes a number of bugs and updates its dependencies to newer versions.  A new version of the `gavinbunney/kubectl` implementation hasn't been released in two years and, based on the lack of activity in its Github project, appears to be dead.  Given that the provider is for managing K8s resources, it is important to use a version that is kept up-to-date with the K8s API.

## 6.1.0

### Added

- The module now supports version [0.31.1](https://github.com/aws/karpenter/releases/tag/v0.31.1) in addition to 0.28.1 and 0.29.2.  Starting with version 0.30.0 of the Helm chart, pod and container security contexts are hardcoded in the deployment template.  To minimize the complexity of the module, the `controller.SecurityContext` and `podSecurityContext` values are set on the Helm release regardless of the Karpenter version.  They are simply ignored when version 0.31.1 is deployed.

## 6.0.0

### Added

- The module now supports versions 0.28.1 and 0.29.2.  Version 0.29.1 is NOT supported due to [a known resource leak](https://github.com/aws/karpenter/releases/tag/v0.29.1).

### Changed

- **Breaking Change**: The minimum supported Terraform version is now 1.5.
- **Breaking Change**: The minimum supported AWS provider version is now 5.0.
- The `karpenter.k8s.aws/cluster` tag is no longer added to every resource created by Karpenter nor is it required by Karpenter's IAM policy for Create actions.  [Karpenter automatically adds it to its launch templates](https://karpenter.sh/docs/upgrade-guide/#upgrading-to-v0140) but none of the other resources.  Tagging its other resources with it is confusing and unnecessary.
- Karpenter's IAM policy now requires the `karpenter.sh/provisioner-name` tag to be in any requests that create resources and on any resources it destroys.  Karpenter has always added this tag but this change will ensure it is always present.

### Removed

- **Breaking Change**: Dropped support for versions 0.26 and 0.27 due to [the number of breaking changes in version 0.28](https://karpenter.sh/docs/upgrade-guide/#upgrading-to-v0280).

## 5.0.0

### Added

- The controller pod resource requests and limits are now configurable with the optional `pod_resources` variable.  The default values match those in the Karpenter Helm chart prior to their removal in 0.26.
- All AWS resources are now tagged with the `kubernetes.io/cluster` tag.
- The Kubernetes namespace has been labeled with the `goldilocks.fairwinds.com/enabled` label to enable support for [Goldilocks](https://github.com/FairwindsOps/goldilocks).  The value of the annotation is controlled by the `enable_goldilocks` variable.
- The Kubernetes namespace has been labeled with [the Pod Security Standards labels](https://kubernetes.io/docs/tasks/configure-pod-container/enforce-standards-namespace-labels/).  The value of the labels is controlled by the `pod_security_standards` variable.  The default for all three labels is `restricted`.
- Support for deploying Karpenter 0.26.1 and 0.27.6.  Version 0.28.x is available but it contains a number of changes that would make the module more complex to support at this time.

### Changed

- Karpenter 0.25 add [the capability for it to discover the endpoint of the EKS cluster](https://karpenter.sh/docs/upgrade-guide/#upgrading-to-v0250) instead of supplying it via the Helm release values.  Karpenter's IAM role policies have been modified to allow it to use the EKS API to discover the endpoint.  The `cluster_endpoint` attribute of the `eks_cluster` variable has been removed to enable the discovery mechanism.
- **Breaking Change**: The minimum supported version of Terraform has been changed from 1.2 to 1.4.
- The container security context has been modified to drop all capabilities to allow it to run under the `restricted` pod security standard.
- The pod security context has been modified to set the seccomp profile to `RuntimeDefault` to allow it to run under the `restricted` pod security standard.

### Removed

- **Breaking Change**: Support for Karpenter 0.20.0 and 0.24.0 has been dropped.  When adding support for new versions of Karpenter, the module tries to maintain compatibility with at least one of the versions it previously supported.  Unfortunately, due to Helm chart changes in 0.26 and metrics label changes in 0.27, attempting to support 0.24.0 would over complicate the module implementation.

## 4.0.1

### Fixed

- Corrected the type of the `taints` and `startup_taints` attributes in the `provisioners` variable.  Renamed them to match their names in the Kubernetes resource because I'll never remember to use snake-case instead of camel-case.
- Reworked the logic to build the Provisioner resources to ensure the `ttlSecondsUntilExpired` and `ttlSecondsAfterEmpty` attributes are correctly added.  Also renamed their attributes in the `provisioners` variable to match the names in the Kubernetes resource.
- Fixed the allowed values of the requirements operator in the in the `provisioners` variable's validation.
- Added two standard provisioner requirements to ensure the nodes run on nitro instances and linux instances.

## 4.0.0

### Added

- **Breaking Change**:A new variable named `eks_cluster` has been introduced to consolidate the variables used to pass in EKS cluster attributes.  The variable's type is an object whose attribute names match the outputs of the [eks-cluster module](../eks-cluster).  The object attributes include replacements for the `cluster_name` and `service_account_oidc_provider_arn` variables while adding the `cluster_endpoint` and `cluster_security_group_id` attributes.
- The module now supports [Karpenter v0.24.0](https://github.com/aws/karpenter/releases/tag/v0.24.0).
- The module can now manage [Karpenter Provisioner resources](https://karpenter.sh/v0.24.0/concepts/provisioners) using the optional `provisioners` variable.  The variable allows a subset of Provisioner resource attributes but it also removes the need to specify attributes that are the same for every Provisioner.  Provisioner resources managed by the module will also be updated when a new version of Karpenter is added to the module to ensure they are valid for all supported versions.

### Changed

- The module has been refactored to use fewer data resources.  In particular, it no longer uses an `aws_eks_cluster` data resource to obtain the cluster's main security group ID and endpoint.  Previously, when the module is applied to the same project as the [eks-cluster module](../eks-cluster), changes to the cluster module would trigger a number of unnecessary changes to Karpenter resources because the cluster data resource was read during the apply and not during the plan.
- **Breaking Change**: The `node_subnet_ids` variable has been renamed `node_subnets` and its type has been changed to a list of objects.  The objects contain two attributes, `id` and `arn`.  The attribute names align with both the attributes of the `aws_subnet` resource and data resource as well as the [`node_subnet_resources` output in the eks-cluster module](../eks-cluster/outputs.tf).  The change both reduces the usage of data resources that are ready at apply time and simplifies construction of the argument for the caller.
- **Breaking Change**: The `fargate_pod_subnet_ids` variable has been renamed `fargate_pod_subnets` and its type has been changed to a list of objects.  The objects contain one attribute, `id`.  The attribute name aligns with both the attributes of the `aws_subnet` resource and data resource as well as the [`node_subnet_resources` output in the eks-cluster module](../eks-cluster/outputs.tf).  The change both reduces the usage of data resources that are ready at apply time and simplifies construction of the argument for the caller.
- **Breaking Change**: Replaced the `enable_service_monitor` variable with the `service_monitor` variable to make the module consistent with other modules in the project while also exposing additional customization of the ServiceMonitor resource.

### Removed

- **Breaking Change**: The `cluster_name` and `service_account_oidc_provider_arn` variables have been removed.  They have been replaced with attributes of the new `eks_cluster` variable.
- The module no longer supports Karpenter v0.19.x

## 3.2.1

### Removed

- The `karpenter-controllers` and `karpenter-controllers-allocation` Grafana dashboards have been removed from the project.  They are broken.  Neither of them are referenced in the Karpenter docs or scripts either.

## 3.2.0

### Added

- The module now supports the option to deploy Grafana dashboards for Karpenter metrics.  The dashboards are deployed in Kubernetes configmaps to allow [Grafana's sidecar to discover them](https://github.com/grafana/helm-charts/tree/main/charts/grafana#sidecar-for-dashboards).
- The `grafana_dashboard_config` variable has been added to configure the Grafana dashboard deployment.  Its type matches the structure of the `dashboard_config` output in the kube-prometheus-stack module for easy integration.
- The module now supports version v0.20.0.
- A CloudWatch alarm has been added to the module to monitor the depth of Karpenter's SQS queue.  Under normal operation, the queue will always be empty.  The alarm triggers if the queue contains any messages over a configured period of time.

### Removed

- Dropped support for version v0.19.2.

## 3.1.0

### Changed

- The module no longer downloads the CRD files from Github because of Github API rate limits.  As more and more of the modules in this project were modified to download CRD files, the risk of hitting the rate limit increased.  To avoid the issue, the CRDs for the supported chart versions are now bundled in the module.  While this increases the maintenance burden of this module, it eliminates a pain point when consuming the module.
- The `chart_version` variable is now restricted to the Helm chart versions whose CRDs are bundled in the module.

### Removed

- The `http` provider is no longer required by the module.  It was only used to download the CRD files.

## 3.0.0

### Added

- An SQS queue and EventBride rules have been added to enable Karpenter's built-in instance interruption handling.
- A new optional variable named `enable_service_monitor` has been added to control the deployment of a [Prometheus Operator ServiceMonitor resource](https://prometheus-operator.dev/docs/operator/api/#monitoring.coreos.com/v1.ServiceMonitor) for scraping metrics.

### Changed

- The module now deploys [Karpenter 0.19.x](https://github.com/aws/karpenter/releases/tag/v0.19.0) instead of 0.16.x.
- The Helm chart is now pulled from oci://public.ecr.aws/karpenter/karpenter as described in [the upgrade nodes for version 0.17](https://karpenter.sh/v0.19.0/upgrade-guide/#upgrading-to-v0170).
- At least two replicas must be specified due to the critical nature of Karpenter.  The validation on the `replicas` variable has been modified to reflect this change.

### Removed

- The Node Termination Handler Helm release has been removed from the module in favor of using Karpenter's built-in handler.  The `node_termination_handler_image_registry` variable has also been removed.
- The Amazon Linux 2 node template has been removed along with the `amazon_linux_2_node_template_provider_ref` and `amazon_linux_2_node_template_name` outputs.  It was never used and is unlikely to be used now that all clusters are using Bottlerocket on all nodes.

## 2.0.2

### Fixed

- Removed an incorrect use of `for_each` on the security group data resource.  For some reason, it didn't cause an error until attempting to upgrade the EKS cluster.
- Added an explicity dependency on the CRD resources to the node template resources to ensure that they are updated after any changes to the CRDs.

## 2.0.1

### Fixed

- Set the `force_new` attribute back to `false` on the `kubectl_manifest` resources that manage the CRDs.  When a CRD is deleted, all of its resources are deleted as well and that is bad.

### Changed

- Set the `force_conflicts` attribute to `true` on the `kubectl_manifest` resources that manage the CRDs.  When updating resources that were created by Helm and then imported into TF, k8s field management can prevent the update because Helm owns the fields.  Forcing updates will ignore field management.

## 2.0.0

### Upgrade Instructions

Prior to upgrading to version 2.x, the Karpenter CRD resources must be imported into the Terraform state by running the following command.  Replace `<module-name>` in the command with the actual name of your module call.

```shell
terraform import 'module.<module-name>.kubectl_manifest.crd["karpenter.k8s.aws_awsnodetemplates.yaml"]' 'apiextensions.k8s.io/v1//CustomResourceDefinition//awsnodetemplates.karpenter.k8s.aws'
terraform import 'module.<module-name>.kubectl_manifest.crd["karpenter.sh_provisioners.yaml"]' 'apiextensions.k8s.io/v1//CustomResourceDefinition//provisioners.karpenter.sh'

```

### Added

- **Breaking Change**: The module now manages the Karpenter CRDs with Terraform instead of delegating to the Helm chart.  Helm 3 does not provide a built in method for updating CRDs nor does the Karpenter chart implement anything to update the CRDs.
- The Terraform `http` provider is  now required by the module to download the Karpenter CRDs from Github.
- The `amazon_linux_2_node_template_provider_ref` output and the `bottlerocket_node_template_provider_ref` output have been added so that consumers of this module can easily set all properties of the `spec.providerRef` attribute on Karpenter Provisioner resources.  Karpenter's current implementation only requires the name attribute because it only supports AWS.  Once Karpenter begins to support other cloud providers, the other properties in the `providerRef` will become required.  This change serves as a form of future proofing.  The `amazon_linux_2_node_template_name` and `bottlerocket_node_template_name` outputs should be considered deprecated.
- The `node_security_group_ids` variable has been added to support specifying security groups to include in the node templates in addition to the cluster's security group.

### Changed

- The module no longer includes image digests when overriding the container images in the Helm release values.  The current implementation of the chart (0.16.x) does not provide a way to override the just the registry component of the images defined in the chart's default values.  In order to override the registry while still using image digests, the module had implemented a hardcoded lookup table mapping the chart version to the image digests.  The lookup table became too burdensome to manage so it has been removed.  There is [an open issue on the Karpenter Github project](https://github.com/aws/karpenter/issues/2465) to allow overriding just the repository.
- The `chart_version` variable's validation has been modified to allow any `0.16` patch version.

### Removed

- **Breaking Change**: The node templates generated by the module no longer include the secondary security groups assigned to the EKS cluster.  The templates now mimic the behavior of EKS managed node groups.  The new `node_security_group_ids` variable can be used to attach the cluster's secondary security groups if necessary.

## 1.2.0

### Added

- Karpenter 0.16.2 is now supported by the module.

### Changed

- The [Hashicorp time provider](https://registry.terraform.io/providers/hashicorp/time/latest) has been introduced to generate a suffix for the Fargate profile's name.  Fargate profiles are immutable so [the `create_before_destroy` lifecycle meta-argument](https://www.terraform.io/language/meta-arguments/lifecycle#create_before_destroy) cannot be used with them if the name is static.  By configuring a `time_static` resource to trigger whenever any of the profile's immutable files changes, the `create_before_destroy` attribute can be used to ensure a Fargate profile is always available for Karpenter.  Due to this change, **upgrading to this version or later will result in recreation of the Fargate profile.**

## 1.1.0

### Added

- Deploying the [AWS Node Termination Handler](https://github.com/aws/aws-node-termination-handler) to gracefully handle spot interruption notifications, spot rebalance recommendations, and EC2 scheduled maintenance events.  The handler is deployed as a daemon set on nodes with the label `karpenter.sh/capacity-type` set to `true`.  To keep things simple, it uses the [Instance Metadata Service Processor](https://github.com/aws/aws-node-termination-handler#instance-metadata-service-processor) to monitor for spot events.

### Changed

- Removed permission to use the `ec2:RequestSpotFleet` action on Karpenter's IAM policy.  Karpenter doesn't appear to use it and, [according to the EC2 documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/spot-best-practices.html#which-spot-request-method-to-use), it is a legacy API.

## 1.0.0

### Added

- Initial release
