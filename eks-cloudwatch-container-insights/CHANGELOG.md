# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## 3.1.0

### Added

- The Enhanced Observability feature is now optional.  It is enabled by default to keep the behavior of the module consistent with version 3.0.0.  It can be disabled with the new `enable_enhanced_observability` variable.

## 3.0.0

### Added

- Enabled [Enhanced Observability](https://aws.amazon.com/blogs/mt/new-container-insights-with-enhanced-observability-for-amazon-eks/) on the CloudWatch agent.  The agent's Kubernetes cluster role has been modified to grant it access additional resources as [described in the AWS documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-setup-metrics.html).

### Changed

- Upgraded the Fluent Bit and CloudWatch agent container image versions to match version 3.1.18 of [the Container Insights project](https://github.com/aws-samples/amazon-cloudwatch-container-insights).
- **Breaking Change**: The minimum Terraform version supported by the module has been changed from 1.3 to 1.6.
- **Breaking Change**: The minimum AWS provider version supported by the module has been changed 4.x to 5.0

### Fixed

- Modified the `application_log_group_arn`, `application_log_group_name`, `dataplane_log_group_arn`, `dataplane_log_group_name`, `host_log_group_arn`, and `host_log_group_name` outputs to return `null` if the log group does not exist.  Due to the use of `for_each` to implement the log group resources, importing module resources was impossible unless all of the log groups were present in the state file.

## 2.0.1

### Changed

- The name of the Fargate logging Fluent Bit process CloudWatch log group has been renamed to be consistent with other resources. A `moved` block has been added to ensure no changes are required by module callers.

### Fixed

- Fixed the `Merge_Log` and `Merge_Log_Key` behavior of the Fluent Bit K8s filter in the Fargate Logging configuration.  It now matches the behavior of the filter in the Fluent Bit daemon set.

## 2.0.0

### Added

- All AWS resources are now tagged with the `kubernetes.io/cluster` tag.
- [The `RUN_WITH_IRSA` environment variable has been added to the CloudWatch agent pods to force it to use the default credential provider chain](https://github.com/aws/amazon-cloudwatch-agent/pull/682).
- [Pod security standard](https://kubernetes.io/docs/concepts/security/pod-security-standards/) labels have been added to the Kubernetes namespace.  They have been configured to enforce the `privileged` standard because both FluentBit and the CloudWatch agent require access to host paths.
- [EKS Fargate pod logging](https://docs.aws.amazon.com/eks/latest/userguide/fargate-logging.html) support is now available.  The new, optional `fargate_logging` variable exposes the configuration options related to Fargate pod logging.  At this time, the module only supports push logs to the Container Insights application log group in CloudWatch.  By default, Fargate logging is disabled due to the fact that the Fargate pod execution roles require additional permissions to push logs to CloudWatch.
- The Kubernetes namespace has been labeled with the `goldilocks.fairwinds.com/enabled` label to enable support for [Goldilocks](https://github.com/FairwindsOps/goldilocks).  The value of the annotation is controlled by the `enable_goldilocks` variable.
- The CloudWatch agent metrics collection interval can be configured with the new `metrics_collection_interval` variable.

### Changed

- **Breaking Change**: The minimum supported Terraform version has been changed from 1.2 to 1.4.
- **Breaking Change**: The default value of the `log_retention_in_days` variable has been lowered to one year.
- The module is now modeled after [version 1.3.16 of the amazon-cloudwatch-container-insights project](https://github.com/aws-samples/amazon-cloudwatch-container-insights/releases/tag/k8s%2F1.3.16).  It had previously been modeled on version 1.3.10.
  - The CloudWatch agent has been upgraded [from version 1.247355.0b252062 to version 1.247360.0b252689](https://github.com/aws/amazon-cloudwatch-agent/blob/main/RELEASE_NOTES).
  - The AWS for FluentBit image has upgraded from version 2.28.4 to version 2.31.11.
  - [Added a 30 second shutdown grace period to FluentBit](https://github.com/aws-samples/amazon-cloudwatch-container-insights/pull/110).
  - [Fixed invalid parsing of the dmesg logs](https://github.com/aws-samples/amazon-cloudwatch-container-insights/pull/108).
- The `cloudwatch_agent_pod_resources` and `fluent_bit_pod_resources` variables have been modified to set the default attribute values in the type declaration instead of in the variables' default values.  It is now possible to override individual attributes without having to copy the default values of the unchanged attributes.
- The logs for the `host-containerd.service` systemd unit are now included in the dataplane logs.  This unit is specific to the Bottlerocket OS.
- The `RuntimeDefault` SECCOMP profile has been added to all container security contexts.
- The CloudWatch agent's metrics collection interval has been increased from 20 seconds to 30 seconds to reduce the amount of data pushed to CloudWatch.  It can be set the original value with the `metrics_collection_interval` variable.

### Removed

- **Breaking Change**: EKS no longer supports the Docker container engine and neither does this module.

## 1.1.1

### Fixed

- Due to a bug in the implementation of the changes in 1.1.0, the dockershim path was not used on 1.22 clusters.  The bug has been destroyed.

## 1.1.0

### Changed

- The module will continue to use `/run/dockershim.sock` instead of `/run/containerd/containerd.sock` when the cluster is running Kubernetes 1.23.  Previously it used the containerd socket when running on 1.23 but caused it to break when the cluster is on 1.23 but some of the nodes are on 1.22.  On the 1.23 AWS AMIs, the containerd socket is `/run/containerd/containerd.sock` but `/run/dockershim.sock` is still available as a symlink to the containerd socket.  In the 1.24 AMIs, the dockershim is completely removed.  By waiting until 1.24 to change to `/run/containerd/containerd.sock`, upgrading the Kubernetes version from 1.22 to 1.23 can happen without a gap in the metrics.
- The AWS Fluent Bit image has been upgraded from 2.28.0 to [2.28.4](https://github.com/aws/aws-for-fluent-bit/releases/tag/v2.28.4) to apply security fixes.
- The CloudWatch agent image has been upgraded from 1.247352.0b251908 to [1.247355.0b252062](https://github.com/aws/amazon-cloudwatch-agent/releases/tag/v1.247355.0)

### Fixed

- The AWS tags in the `tags` variable are now correctly applied to every AWS resource in the module.

## 1.0.0

### Added

- Initial release
