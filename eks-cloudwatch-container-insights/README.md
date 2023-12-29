# EKS CloudWatch Container Insights

## Overview

Deploys the Kubernetes and AWS resources required to enable [CloudWatch Container Insights](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/deploy-container-insights-EKS.html) for an EKS cluster.  The resources created by the module are based on the [version 1.3.18 of the aws-samples/amazon-cloudwatch-container-insights daemonset manifests](https://github.com/aws-samples/amazon-cloudwatch-container-insights/tree/k8s/1.3.18/k8s-deployment-manifest-templates/deployment-mode/daemonset) Kubernetes manifests with some enhancements ported from the [aws-cloudwatch-metrics Helm chart](https://github.com/aws/eks-charts/tree/master/stable/aws-cloudwatch-metrics).  The Helm chart is not used because, at this time, it does not expose values for customizing the agent config or many of the attributes of the daemon set.

## Components

### Logging Agent

[Fluent Bit is used to capure container logs, system logs, and systemd unit logs](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-setup-logs-FluentBit.html).  It was chosen over [FluentD](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-setup-logs.html) because it requires fewer resources and because Container Insights support for FluentD is in maintenance mode.  For some unknown reason, AWS does not provide a Helm chart for installing Fluent Bit with a configuration compatible with Container Insights.  Instead, the AWS documentation refers users to the [aws-samples/amazon-cloudwatch-container-insights project](https://github.com/aws-samples/amazon-cloudwatch-container-insights).  The project contains [raw Kubernetes manifests for deploying Fluent Bit](https://github.com/aws-samples/amazon-cloudwatch-container-insights/tree/master/k8s-deployment-manifest-templates/deployment-mode) as a daemon set, a service or a side car.  The [daemon set manifests](https://github.com/aws-samples/amazon-cloudwatch-container-insights/tree/master/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/fluent-bit) are used as the basis of the resources created and managed by this module.  The module resources differ from the manifest versions in a number of ways including, but not limited to, the following.

* The dataplane logging configuration and the pod volume mounts have been modified to only capture containerd runtime logs.  Everything related to capturing DOcker runtime logs has been removed.
* Instead of using the EC2 node's instance profile credentials to authenticate with the AWS API, the Fluent Bit pod is configured to use an [IAM role tied to its Kubernetes service account](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html).
* Fluent Bit has been configured to use [the core multiline parsing functionality introduced in version 1.8](https://docs.fluentbit.io/manual/administration/configuring-fluent-bit/multiline-parsing) to both simplify its configuration files and to enable the containerd support.
* Annotations have been added to the Fluent Bit pods to enable Prometheus metrics capture.
* A security context has been added to the Fluent Bit containers to reduce the scope of its access and capabilities.
* The [Kubernetes filter](https://docs.fluentbit.io/manual/pipeline/filters/kubernetes) is configured to include pod labels and to [support configuration via annotations](https://docs.fluentbit.io/manual/pipeline/filters/kubernetes#kubernetes-annotations).
* The `system-node-critical` priority class has been assigned to the pods due to the critical nature of log forwarding.

In addition to the Kubernetes resources, the module also manages the AWS resources required for Container Insights.  The resources include the IAM role assumed by Fluent Bit as well as the CloudWatch log groups targeted by the agent.

### Fargate Logging

Beginning with version 2.0, the module optionally supports [capturing the logs of pods running on Fargate nodes](https://docs.aws.amazon.com/eks/latest/userguide/fargate-logging.html).  When enabled, the logs are pushed to the Container Insights application log group in CloudWatch logs.  The feature can be enabled and configured with the `fargate_logging` variable.  Due to the way Fargate logging is implemented in EKS, this module can only be applied once per cluster.  This limitation is in effect even if the Fargate logging feature is disabled.

Below is an example of the minimum values required to enable Fargate logging.

```hcl
module "container_insights" {
    source = "eks-cloudwatch-container-insights"

    cluster_name = "example-eks-cluster"

    fargate_logging = {
        enabled                  = true
        # At least one role must be provided when enabled.
        pod_execution_role_names = ["example-fargate-pod-execution-role"]
    }
}
```

### Metrics Agent

To capture the metrics used by Container Insights, the module deploys the CloudWatch agent as daemon set.  As mentioned in the overview, AWS does supply a Helm chart to deploy the agent but it is not used in this module.  Instead, the [Kubernetes manifests available in the aws-samples/amazon-cloudwatch-container-insights project](https://github.com/aws-samples/amazon-cloudwatch-container-insights/tree/k8s/1.3.18/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/cwagent) are used as the basis of the resources in this module.  Just like the Fluent Bit resources, the CloudWatch agent resources in the module differ from the manifests versions in an effort to improve upon them.  The differences include but are not limited to the following.

* Instead of using the EC2 node's instance profile credentials to authenticate with the AWS API, the agent pod is configured to use an [IAM role tied to its Kubernetes service account](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html).
* A security context has been added to the agent containers to reduce the scope of its access and capabilities.
* The `system-node-critical` priority class has been assigned to the pods due to the critical nature of metrics capture.
* The agent is configured to collect metrics every 30 seconds instead of the original 60 seconds in an effort to capture metrics on short lived pods like Gitlab CI jobs.  The collection interval can be modified using the `metrics_collection_interval` variable.
* The pod volume mounts have been updated to capure metrics from containerd instead of Docker.

The IAM role assumed by the CloudWatch agent as well as the CloudWatch log group it targets are also created and managed by this module.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.23 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.5 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.23 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.5 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cloudwatch_agent_role"></a> [cloudwatch\_agent\_role](#module\_cloudwatch\_agent\_role) | terraform-aws-modules/iam/aws//modules/iam-eks-role | 5.3.0 |
| <a name="module_fluent_bit_role"></a> [fluent\_bit\_role](#module\_fluent\_bit\_role) | terraform-aws-modules/iam/aws//modules/iam-eks-role | 5.3.0 |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.container_insights_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.container_insights_metrics](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.fargate_fluent_bit](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_role_policy.cloudwatch_agent](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.fargate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.fluent_bit](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [kubernetes_cluster_role_binding_v1.cloudwatch_agent](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding_v1) | resource |
| [kubernetes_cluster_role_binding_v1.fluent_bit](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding_v1) | resource |
| [kubernetes_cluster_role_v1.cloudwatch_agent](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_v1) | resource |
| [kubernetes_cluster_role_v1.fluent_bit](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_v1) | resource |
| [kubernetes_config_map_v1.cloudwatch_agent_config](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map_v1) | resource |
| [kubernetes_config_map_v1.cloudwatch_agent_leader_election](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map_v1) | resource |
| [kubernetes_config_map_v1.fargate](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map_v1) | resource |
| [kubernetes_config_map_v1.fluent_bit_config](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map_v1) | resource |
| [kubernetes_daemon_set_v1.cloudwatch_agent](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/daemon_set_v1) | resource |
| [kubernetes_daemon_set_v1.fluent_bit](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/daemon_set_v1) | resource |
| [kubernetes_namespace_v1.cloudwatch](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_namespace_v1.fargate](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_resource_quota_v1.fargate](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/resource_quota_v1) | resource |
| [kubernetes_service_account_v1.cloudwatch_agent](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account_v1) | resource |
| [kubernetes_service_account_v1.fluent_bit](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account_v1) | resource |
| [random_uuid.cloudwatch_agent_config](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/uuid) | resource |
| [random_uuid.fluent_bit_config](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/uuid) | resource |
| [aws_iam_policy_document.cloudwatch_agent](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.fargate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.fluent_bit](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_ssm_parameter.fluent_bit_image](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cloudwatch_agent_pod_resources"></a> [cloudwatch\_agent\_pod\_resources](#input\_cloudwatch\_agent\_pod\_resources) | CPU and memory settings for the CloudWatch agent pods. | <pre>object(<br>    {<br>      limits = optional(<br>        object({<br>          cpu    = optional(string, "400m")<br>          memory = optional(string, "400Mi")<br>        }),<br>      {})<br>      requests = optional(<br>        object({<br>          cpu    = optional(string, "200m")<br>          memory = optional(string, "200Mi")<br>        }),<br>      {})<br>    }<br>  )</pre> | `{}` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The name of the target EKS cluster. | `string` | n/a | yes |
| <a name="input_enable_enhanced_observability"></a> [enable\_enhanced\_observability](#input\_enable\_enhanced\_observability) | Enables the Enhanced Observability feature on the CloudWatch agent | `bool` | `true` | no |
| <a name="input_enable_goldilocks"></a> [enable\_goldilocks](#input\_enable\_goldilocks) | Determines if Goldilocks monitors the namespace to give recommendations on tuning pod resource requests and limits.<br>https://goldilocks.docs.fairwinds.com/installation/#enable-namespace | `bool` | `true` | no |
| <a name="input_fargate_logging"></a> [fargate\_logging](#input\_fargate\_logging) | An object to optionally enable and configure Fargate pod log collection.  When enabled, the pod logs are pushed to<br>the Container Insights application log group.  When enabled, at least one Fargate pod execution role must be provided.<br>The role names specified in the `pod_execution_role_names` attribute.  The Fluent Bit process logs are enabled by default.<br>They can be disabled using the `enabled` attribute of the `fluent_bit_process_logging` object attribute.  The process log<br>retention defaults to one year.  It can be modified using the `retention_in_days` attribute of the `fluent_bit_process_logging`<br>object attribute. | <pre>object({<br>    enabled = optional(bool, false)<br>    fluent_bit_process_logging = optional(<br>      object({<br>        enabled           = optional(bool, true)<br>        retention_in_days = optional(number, 365)<br>      }),<br>    {})<br>    pod_execution_role_names = optional(set(string), [])<br>  })</pre> | `{}` | no |
| <a name="input_fluent_bit_pod_resources"></a> [fluent\_bit\_pod\_resources](#input\_fluent\_bit\_pod\_resources) | CPU and memory settings for the Fluent Bit pods. | <pre>object({<br>    limits = optional(<br>      object({<br>        cpu    = optional(string, "1000m")<br>        memory = optional(string, "200Mi")<br>      }),<br>    {})<br>    requests = optional(<br>      object({<br>        cpu    = optional(string, "500m")<br>        memory = optional(string, "100Mi")<br>      }),<br>    {})<br>  })</pre> | `{}` | no |
| <a name="input_http_server_enabled"></a> [http\_server\_enabled](#input\_http\_server\_enabled) | Enables the Fluent Bit HTTP server for Prometheus metrics scraping. | `bool` | `true` | no |
| <a name="input_http_server_port"></a> [http\_server\_port](#input\_http\_server\_port) | Configures the listening port for Prometheus metrics scraping. | `number` | `2020` | no |
| <a name="input_image_registry"></a> [image\_registry](#input\_image\_registry) | The container image registry from which the AWS CloudWatch agent image will be pulled.  The images must be in the cloudwatch-agent/cloudwatch-agent repository.<br>The value can have an optional path suffix to support the use of ECR pull-through caches. | `string` | `"public.ecr.aws"` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | An optional map of kubernetes labels to attach to every resource created by the module. | `map(string)` | `{}` | no |
| <a name="input_log_retention_in_days"></a> [log\_retention\_in\_days](#input\_log\_retention\_in\_days) | The number of days to retain the logs in the CloudWatch log groups. | `number` | `365` | no |
| <a name="input_metrics_collection_interval"></a> [metrics\_collection\_interval](#input\_metrics\_collection\_interval) | The interval, in seconds, in which the CloudWatch agent will collect metrics.  Defaults to 30 seconds | `number` | `30` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | The namespace where Kubernetes resources will be installed. | `string` | `"amazon-cloudwatch"` | no |
| <a name="input_read_from_head"></a> [read\_from\_head](#input\_read\_from\_head) | Configures Fluent Bit to read from the head of the log files. | `bool` | `false` | no |
| <a name="input_read_from_tail"></a> [read\_from\_tail](#input\_read\_from\_tail) | Configures Fluent Bit to read from the tail of the log files. | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | An optional map of AWS tags to attach to every resource created by the module. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_application_log_group_arn"></a> [application\_log\_group\_arn](#output\_application\_log\_group\_arn) | The ARN of the CloudWatch log group containing logs from application pods. |
| <a name="output_application_log_group_name"></a> [application\_log\_group\_name](#output\_application\_log\_group\_name) | The name of the CloudWatch log group containing logs from application pods. |
| <a name="output_cloudwatch_agent_iam_role_arn"></a> [cloudwatch\_agent\_iam\_role\_arn](#output\_cloudwatch\_agent\_iam\_role\_arn) | The ARN of the AWS IAM role assumed by the CloudWatch agent. |
| <a name="output_cloudwatch_agent_iam_role_name"></a> [cloudwatch\_agent\_iam\_role\_name](#output\_cloudwatch\_agent\_iam\_role\_name) | The name of the AWS IAM role assumed by the CloudWatch agent. |
| <a name="output_dataplane_log_group_arn"></a> [dataplane\_log\_group\_arn](#output\_dataplane\_log\_group\_arn) | The ARN of the CloudWatch log group containing kubelet, kube-proxy, and container runtime logs. |
| <a name="output_dataplane_log_group_name"></a> [dataplane\_log\_group\_name](#output\_dataplane\_log\_group\_name) | The name of the CloudWatch log group containing kubelet, kube-proxy, and container runtime logs. |
| <a name="output_fluent_bit_iam_role_arn"></a> [fluent\_bit\_iam\_role\_arn](#output\_fluent\_bit\_iam\_role\_arn) | The ARN of the AWS IAM role assumed by Fluent Bit. |
| <a name="output_fluent_bit_iam_role_name"></a> [fluent\_bit\_iam\_role\_name](#output\_fluent\_bit\_iam\_role\_name) | The name of the AWS IAM role assumed by Fluent Bit. |
| <a name="output_host_log_group_arn"></a> [host\_log\_group\_arn](#output\_host\_log\_group\_arn) | The ARN of the CloudWatch log group containing operating system logs generated by Kubernetes nodes. |
| <a name="output_host_log_group_name"></a> [host\_log\_group\_name](#output\_host\_log\_group\_name) | The name of the CloudWatch log group containing operating system logs generated by Kubernetes nodes. |
| <a name="output_metrics_log_group_arn"></a> [metrics\_log\_group\_arn](#output\_metrics\_log\_group\_arn) | The ARN of the CloudWatch log group containing the Kubernetes metrics generated by the CloudWatch agent. |
| <a name="output_metrics_log_group_name"></a> [metrics\_log\_group\_name](#output\_metrics\_log\_group\_name) | The name of the CloudWatch log group containing the Kubernetes metrics generated by the CloudWatch agent. |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | The name of the Kubernetes namespace that contains the Container Insights objects managed by this module. |
<!-- END_TF_DOCS -->