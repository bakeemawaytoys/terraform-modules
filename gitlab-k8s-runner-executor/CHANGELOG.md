# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## 6.0.0

### Changed

- **Breaking Change** Set the minimum allowed Helm chart version to 0.57.x and the maximum to 0.58.x in the validation logic of the `chart_version` variable.
- Set the default value of the `chart_version` variable to 0.58.0 in support of Gitlab 16.5.1.

## 5.2.0

### Added

- Modified config toml to spin up an empty_dir volume in job pods. This will allow jobs to have write access to a directory that doesn't require root.

## 5.1.0

### Changed

- Modified the type declarations on the `build_pod_annotations`, `build_container_security_context`, `build_pod_service_account` to use optional object attribute feature introduced in Terraform 1.3.  The default values for their object attributes are now defined at the type level.  Values passed into those variables no longer have to define every attribute in order to override a subset of values.

### Fixed

- The build pod's `run_as_group` security context setting is now correctly set to the value of the `build_container_security_context` variable's `run_as_group` attribute.

## 5.0.0

### Changed

- **Breaking Change** Set the minimum allowed Helm chart version to 0.53.x and the maximum to 0.56.x in the validation logic of the `chart_version` variable.
- Set the default value of the `chart_version` variable to 0.56.0 in support of Gitlab 16.3.x.
- Due to the restrictions on the runner Helm chart versions, the supported runner version 16.0.2, 16.1.0, 16.2.0 and 16.3.0 which support Gitlab versions 16.0.x through 16.3.x.

## 4.0.1

### Fixed

- Added `pods/log` resource to the Kubernetes role in the build pod namespace.  [The Kubernetes executor documentation, as of version 16.1, doesn't include it in the set of resources required by the executor's service account](https://docs.gitlab.com/runner/executors/kubernetes.html#configure-runner-api-permissions).  It turns out it is needed to [read the logs from service pods when the `CI_DEBUG_SERVICES` environment variable is included in a job](https://docs.gitlab.com/ee/ci/services/#capturing-service-container-logs).

## 4.0.0

## Added

- The module now supports version Helm chart version 0.52.x/Gitlab 15.11.x.
- Pod Security Admission labels have been added to the build pod namespace.  They can be configured with the new `pod_security_standards` variable.
- Container ephemeral storage requests, limits, and allowed overwrites can now be configured in the `helper_container_resources`, `service_container_resources`, and `build_container_resources` variables.
- The build pods now include a `NoSchedule` toleration for the `kubernetes.io/arch` label.  The `architecture` variable determines the value to tolerate.

## Changed

- The `service_container_resources`, `helper_container_resources`, `executor_pod_resources`, and `build_container_resources` variables have been modified to use optional object attribute feature introduced in Terraform 1.3.  Individual attributes can now be overridden without the need to include all attributes in the variable.
- The default value of the `default_build_image` variable has been changed to from `public.ecr.aws/docker/library/alpine:3.15.4` to `public.ecr.aws/docker/library/alpine:3.17.3`.
- **Breaking Change**: The `chart_version` variable no longer has a default value.  By removing the default value, the installed version must be specified in the module call. It is no longer necessary to look at the module source to figure out which version is deployed in a module call.
- A [`terraform_data` resource](https://developer.hashicorp.com/terraform/language/resources/terraform-data) has been added to the module as a way to pretty-print the runner's config.toml file in the output of a plan.  Prior to this, the only way to see the file in the plan output was in the Helm release's values.  In the Helm release values, the formatting of the file was lost, making it difficult to read.
- **Breaking Change**: The minimum supported Terraform version is now 1.4 due to the `terraform_data` resource added to the module.
- **Breaking Change**: The [overwriting container resources](https://docs.gitlab.com/15.11/runner/executors/kubernetes.html#overwrite-container-resources) is now disabled by default.  It hasn't see much, if any use, and it isn't something the devs should be using unless absolutely necessary.

## 3.7.0

### Changed

- Set the minimum allowed Helm chart version to 0.51.0 and the maximum to 0.51.1 in the validation logic of the `chart_version` variable.
- Set the default value of the `chart_version` variable to 0.51.1.
- Due to the restrictions on the runner Helm chart versions, the supported runner version 15.10.0 and 15.10.1 which contain the latest [Gitlab new features | https://about.gitlab.com/releases/2023/04/05/gitlab-15-10-2-released//].

## 3.6.0

### Changed

- Set the minimum allowed Helm chart version to 0.50.0 and the maximum to 0.50.1 in the validation logic of the `chart_version` variable.
- Set the default value of the `chart_version` variable to 0.50.1.
- Due to the restrictions on the runner Helm chart versions, the supported runner versions are 15.9.0 and 15.9.1 which contain the latest [Gitlab new features | https://about.gitlab.com/releases/2023/02/22/gitlab-15-9-released/].

## 3.5.1

### Fixed

- Fixed regex for the `gitlab-k8s-runner-executor` allowing it to correctly validate the newer chart for Gitlab 15.6.x

## 3.5.0

### Changed

- Set the minimum allowed Helm chart version to 0.45.0 and the maximum to 0.47.0 in the validation logic of the `chart_version` variable.
- Set the default value of the `chart_version` variable to 0.47.0.
- Due to the restrictions on the runner Helm chart versions, the supported runner versions are 15.4, 15.5, and 15.6 which contain the latest [Gitlab security release | https://about.gitlab.com/releases/2022/11/30/security-release-gitlab-15-6-1-released/?utm_medium=email&utm_source=marketo&utm_campaign=security+release+email&utm_content=Nov+30+2022].

## 3.4.0

### Changed

- Upgraded the sealed-secret module version to 2.0.0 to apply bug fixes and increase timeouts.

## 3.3.0

### Fixed

- Upgraded the sealed-secret module to version 1.0.3 to apply yet another workaround to a bug in the `kubernetes_manifest` resource.

### Added

- The `"fluentbit.io/exclude":"true"` annotation has been added to the job pods to prevent FluentBit from harvesting job logs.  There is no reason to push the logs to CloudWatch when they are already captured by Gitlab itself.

## 3.2.0

### Added

- The `build_pod_node_tolerations` variable has been introduced to support specifying [tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/) on the build pods.  By utilizing the `build_pod_node_tolerations` variable, the `build_pod_node_selector`variable, and Kubernetes node taints the build pods can now be confined to dedicated nodes.
- The `build_pod_node_selector` and `labels` variables now include validation to ensure they [conform to the syntax specified by Kubernetes](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set).

## 3.1.0

### Added

- The build job pods now include the `karpenter.sh/do-not-evict` annotation [to prevent Karpenter from evicting the pod](https://karpenter.sh/preview/tasks/deprovisioning/#pod-set-to-do-not-evict) until the job is complete.  One of Karpenter's features is to move pods to different nodes in an effort to consolidate all pods onto the minimum number of nodes.  The feature is great for application pods but not so great for Gitlab CI jobs.
- The `build_pod_node_selector` variable has been added to allow for customization of the [node selector](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector) on the build pods.

### Changed

- Switched to using the [sealed-secret module](../sealed-secret/) to manage the registration token's `SealedSecret` resource instead of directly managing the resource in this module.  This will reduce code duplication among modules and include workarounds for the [bugs in the Kubernetes provider's `kubernetes_manifest` resource](https://github.com/hashicorp/terraform-provider-kubernetes/issues/1610).

## 3.0.0

### Added

- Enabled the [artifact attestation feature](https://docs.gitlab.com/ee/ci/runners/configure_runners.html#artifact-attestation) by default.
- Enabled [the fastzip feature flag](https://docs.gitlab.com/ee/ci/runners/configure_runners.html#configure-fastzip-to-improve-performance) by default to reduce the resources required by the helper container.

### Changed

- **Breaking Change** Set the minimum allowed Helm chart version to 0.42.0 and the maximum to 0.44.0 in the validation logic of the `chart_version` variable.  Version 0.42.0 of the chart [introduced new values for overriding portions of the runner's image name](https://gitlab.com/gitlab-org/charts/gitlab-runner/-/merge_requests/351) instead of using a single value to specify the entire image name with a tag. The new values simplify the implementation of the `runner_image_registry` variable.
- Set the default value of the `chart_version` variable to 0.42.0.
- Due to the restrictions on the runner Helm chart versions, the supported runner versions are 15.1, 15.2, and 15.3.
- **Breaking Change**: Set the minimum http provider version to 3.0.0 to make use of new attributes introduced in the 3.x line.
- **Breaking Change**: Set the minimum Terraform version to 1.2.0 due to [the use of post-condition blocks](https://www.terraform.io/language/expressions/custom-conditions#preconditions-and-postconditions).
- **Breaking Change**: Dropped support for [the legacy 'exec' job execution strategy](https://docs.gitlab.com/runner/executors/kubernetes.html#job-execution).  The permissions on the the role attached the executor's service account are now limited to those [required for the 'attach' execution strategy](https://docs.gitlab.com/runner/executors/kubernetes.html#overwriting-kubernetes-namespace).
- Bumped the executor's log level from debug to info to reduce the amount of noise it generates.
- Switched to using the runner's version instead of its Git revision to determine which helper image to pull.  The helper image repository in ECR public doesn't have a revision tag for the image that corresponds to the runner's 15.3.0 build.  The Gitlab documentation also seems to imply that the version tags are now the preferred method of referencing the helper images.  This change both address the pull failures as well as aligns the module with the Gitlab documentation.

## 2.0.2

### Fixed

- Added permission to read k8s service accounts to the executor's role in the job pod namespace.  Apparently it is now required as of version 15.0 of the runner.  Without the new permissions, the job pods fail to launch with the message "Timed out while waiting for ServiceAccount/foo".  The solution was found at <https://stackoverflow.com/questions/72534199/setting-up-build-pod-timed-out-while-waiting-for-serviceaccount-service-accoun>.

## 2.0.1

### Fixed

- The optional variable `build_pod_aws_iam_role` was not implemented with a default value effectively making it a required variable.  The default attribute has been added and set to `null`.  Its validation logic has also been modified to accept `null` as valid.
- Removed the use of the deprecated `response` attribute on a `http` data resource.
- The version constraint on the `http` provider has also been constrained to 2.2.x or greater but less than 3.x due to breaking changes in 3.0.  The minimum is set to 2.2.x because that is when the replacement for the `response` attribute was added.

## 2.0.0

### Added

- Version 0.41.x of the runner Helm chart is now supported in addition to the 0.40.x version.
- The `service_container_resources` variable has been added to support configuring resource requests and limits on [service containers](https://docs.gitlab.com/ee/ci/services/) in the build pods.
- The [recommended Kubernetes labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/) have been added to all resources.
- The `build_pod_aws_iam_role` variable has been added to simplify associating an IAM role with the build pods.  It should be used instead of the `build_pod_service_account` variable to add the required annotations to the build pod's service account.
- The `build_pod_iam_role_name` output has been added to simplify creating an IAM role for the build pod service account.  It is set to the `name` attribute of the `build_pod_aws_iam_role` or null if the variable was not assigned a value.
- The `iam_eks_role_module_service_account_value` output has been added to simplify using version 5.2+ of the [terraform-aws-iam/iam-eks-role](https://github.com/terraform-aws-modules/terraform-aws-iam/tree/master/modules/iam-eks-role) module.  It is structured for use as the value of the module's `cluster_service_accounts` variable.

### Changed

- **Breaking Change**: The validation on the `chart_version` variable has been modified to limit values to the versions the module is designed to support.
- **Breaking Change**: Set the default user ID in the `build_container_security_context` variable to 1000 instead of 100 to align with the use of Alpine as the default container image.  It also reduced the potential for accidentally running as a user created by an operating system package.
- **Breaking Change**: The `build_container_security_context` variable now includes the `drop_capabilities` attribute to support specifying the Linux capabilities to drop.  Its default value is `["ALL"]` to drop all capabilities to align with the previous behavior.  The primary use case is to support pods running on Fargate nodes.  [Fargate does not support adding capabilities, only dropping them](https://aws.github.io/aws-eks-best-practices/security/docs/pods/#linux-capabilities).  The change is considered to be a breaking change because the new attribute must be specified as the variable type is `object`.
- Increased the default executor pod memory requests and limits from 64Mi/128Mi to 256Mi/512Mi.  The original values are too low in practice, especially when the executor has to handle a large number of jobs concurrently.

### Fixed

- Labels specified in the `labels` variable are now correctly applied to the executor pod.

## 1.2.0

### Added

- Enabled the metrics endpoint on the runner executor.

### Changed

- Set a limit on the Helm release history to keep the k8s resource usage under control.  By default, the Helm provider doesn't limit the history.

## 1.1.0

### Added

- The new `runner_image_registry` variable can be used to specify the container registry from which the runner and runner helper images will be pulled.  The variable also supports specifying an ECR pull-through cache.  The default value is the previously hard-coded _public.ecr.aws_.
- Modified the `chart_version` variable to include validation.

## 1.0.0

### Added

- Initial release !1
