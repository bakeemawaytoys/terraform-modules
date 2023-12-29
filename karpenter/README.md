# AWS Karpenter

## Overview

Deploys [AWS Karpenter](https://karpenter.sh/) to an EKS cluster.  The Karpenter pods are [deployed to a Fargate nodes](https://aws.github.io/aws-eks-best-practices/karpenter/#run-the-karpenter-controller-on-eks-fargate-or-on-a-worker-node-that-belongs-to-a-node-group) using a Fargate profile managed by this module.  The [official Helm chart](https://github.com/aws/karpenter/tree/main/charts/karpenter) is used to deploy Karpenter.  The access to the EC2 API is provided to Karpenter using the [IAM roles for service accounts](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html) feature of EKS.

The module also manages an `AWSNodeTemplate` resource to use with [Karpenter `Provisioner` resources](https://karpenter.sh/v0.29/concepts/provisioners/).  The template is configured to launch nodes with [the Bottlerocket operating system](https://github.com/bottlerocket-os/bottlerocket).

As of version 0.19, Karpenter has native support for handling instance events such as spot instance interruption warnings, state-change notifications, AWS health events, and rebalance recommendations.  The module deploys the SQS queue and EventBridge rules required for this feature.

The module supports versions v0.28.1, v0.29.2, v0.31.1.

## Limitations

1. The [`AWSNodeTemplate` resources](https://karpenter.sh/v0.29/concepts/node-templates/) managed by this module configure the instance metadata service to prevent pods from accessing it.
1. The policy on Karpenter's IAM role prevents it from attaching any security groups to the nodes other than the cluster's security groups.
1. The policy on Karpenter's IAM role prevents it from launch nodes unless certain tags are included.  The `required_tags` output contains a map with required tags.  It can be used to construct new `AWSNodeTemplate` resources outside of the module that will work with Karpenter's IAM permissions.

## Module Maintenance

### Custom Resource Definitions

The module manages the Karpenter custom resource definitions with Terraform   The Helm release resource is configured to skip CRD installation.  While it is possible to dynamically download the CRD files using [the Terraform `http` provider](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http), the rate limiting on the Github API makes this approach impractical.  Instead, the CRD files are bundled in the module.  For each version of the Helm chart supported by the module, [there is a subdirectory](files/crds/) whose name corresponds to the chart version.  The CRDs for the chart version are in the subdirectory with one CRD per file.  When modifying the module to support additional chart versions, create a directory for each new supported version and add the CRD files for that version.  The CRDs files can be downloaded from [the Karpenter Github project](https://github.com/aws/karpenter/tree/main/pkg/apis/crds).  When dropping support for a chart version, remove its CRD directory.

### Grafana Dashboards

The module supports installing Grafana dashboards as Kubernetes configmaps.  The configmaps are constructed to work with [the sidecar deployed as part of the Grafana Helm release](https://github.com/grafana/helm-charts/tree/main/charts/grafana#sidecar-for-dashboards).  The module manages the dashboard definitions in the same way as the custom resource definitions (see above).  The dashboard subdirectory is [files/dashboards](files/dashboards).  The original dashboard definitions are found in the Github project in [the source for the eksctl Getting Started documentation](https://github.com/aws/karpenter/tree/main/website/content/en/v0.31/getting-started/getting-started-with-karpenter).

## References

- <https://aws.github.io/aws-eks-best-practices/karpenter/>
- <https://github.com/aws/karpenter>
- <https://karpenter.sh/v0.29.0/>

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.10 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 2.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.23 |
| <a name="requirement_time"></a> [time](#requirement\_time) | ~> 0.8 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.10 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | >= 2.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.23 |
| <a name="provider_time"></a> [time](#provider\_time) | ~> 0.8 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_karpenter_iam_role"></a> [karpenter\_iam\_role](#module\_karpenter\_iam\_role) | terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks | ~> 5.3 |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_event_rule.interruption_notification](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.interruption_notification](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_metric_alarm.queue_depth](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_eks_fargate_profile.karpenter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_fargate_profile) | resource |
| [aws_iam_role_policy.eks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.instance_metadata](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.interruption_notification](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.karpenter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_sqs_queue.interruption_notification](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue_policy.interruption_notification](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_policy) | resource |
| [helm_release.karpenter](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubectl_manifest.crd](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.karpenter_bottlerocket_node_template](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.provisioner](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [kubernetes_config_map_v1.grafana_dashboard](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map_v1) | resource |
| [kubernetes_namespace_v1.karpenter](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [time_static.fargate_profile](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/static) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_default_tags.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/default_tags) | data source |
| [aws_iam_instance_profile.cluster_node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_instance_profile) | data source |
| [aws_iam_policy_document.eks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.instance_metadata](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.interruption_notification](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.interruption_notification_queue_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.karpenter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_role.fargate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_role) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | The version of the Karpenter Helm chart to deploy.  Only `v0.28.1`, `v0.29.2`, `v0.31.1`, and `v0.31.3` are supported. | `string` | n/a | yes |
| <a name="input_cloudwatch_alarms"></a> [cloudwatch\_alarms](#input\_cloudwatch\_alarms) | Configures the CloudWatch alarms managed by the module.<br>The 'actions' attribute is an optional list of ARNs for all alarm actions.<br>The 'queue\_depth\_alarm' configures the alarm that triggers if Karpenter isn't consuming messages from its instance notification queue. | <pre>object(<br>    {<br>      actions = optional(list(string), [])<br>      queue_depth_alarm = optional(object({<br>        actions_enabled    = optional(bool, true)<br>        evaluation_periods = optional(number, 2)<br>        period             = optional(number, 60)<br>        threshold          = optional(number, 1)<br>      }), {})<br>    }<br>  )</pre> | `{}` | no |
| <a name="input_container_registry_mirrors"></a> [container\_registry\_mirrors](#input\_container\_registry\_mirrors) | A list of objects for configuring containerd registry mirrors.<br><br>The 'registry' attribute is the hostname of the upstream registry.<br>The 'endpoint' attrbute is the URL of the mirror.<br><br>https://github.com/bottlerocket-os/bottlerocket#container-image-registry-settings<br>https://github.com/containerd/containerd/blob/main/docs/hosts.md#setup-a-local-mirror-for-docker | <pre>list(object(<br>    {<br>      endpoint = string<br>      registry = string<br>    }<br>  ))</pre> | `[]` | no |
| <a name="input_eks_cluster"></a> [eks\_cluster](#input\_eks\_cluster) | Attributes of the EKS cluster on which Karpenter is deployed.  The names of the attributes match the names of outputs in the eks-cluster module to allow using the module as the argument to this variable.<br><br>The `cluster_name` attribute the the name of the EKS cluster.  It is required.<br>The `cluster_security_group_id` is the ID of the security group generated by EKS when the cluster was created.  It is required.<br>The 'service\_account\_oidc\_provider\_arn' attribute is the ARN of the cluster's IAM OIDC identity provider.  It is required. | <pre>object({<br>    cluster_name                      = string<br>    cluster_security_group_id         = string<br>    service_account_oidc_provider_arn = string<br>  })</pre> | n/a | yes |
| <a name="input_enable_goldilocks"></a> [enable\_goldilocks](#input\_enable\_goldilocks) | Determines if Goldilocks monitors the namespace to give recommendations on tuning pod resource requests and limits.<br>https://goldilocks.docs.fairwinds.com/installation/#enable-namespace | `bool` | `true` | no |
| <a name="input_fargate_pod_execution_role_name"></a> [fargate\_pod\_execution\_role\_name](#input\_fargate\_pod\_execution\_role\_name) | The name of the IAM role the to assign to the Fargate profile. | `string` | n/a | yes |
| <a name="input_fargate_pod_subnets"></a> [fargate\_pod\_subnets](#input\_fargate\_pod\_subnets) | A list of objects containing the IDs of AWS subnets to use for the Karpenter Fargate profile. | <pre>list(object({<br>    id = string<br>  }))</pre> | n/a | yes |
| <a name="input_grafana_dashboard_config"></a> [grafana\_dashboard\_config](#input\_grafana\_dashboard\_config) | Configures the optional deployment of Grafana dashboards in configmaps.  Set the value to null to disable dashboard installation.  The dashboards will be added to the "Karpenter" folder in the Grafana UI.<br><br>The 'folder\_annotation\_key' attribute is the Kubernets annotation that configures the Grafana folder into which the dasboards will appear in the Grafana UI.  It cannot be null or empty.<br>The 'label' attribute is a single element map containing the label the Grafana sidecar uses to discover configmaps containing dashboards.  It cannot be null or empty.<br>The 'namespace' attribute is the namespace where the configmaps are deployed.  It cannot be null or empty.<br><br>* https://github.com/grafana/helm-charts/tree/main/charts/grafana#sidecar-for-dashboards<br>* https://karpenter.sh/v0.20.0/getting-started/getting-started-with-eksctl/#deploy-a-temporary-prometheus-and-grafana-stack-optional<br>* https://github.com/aws/karpenter/tree/main/website/content/en/v0.20.0/getting-started/getting-started-with-eksctl | <pre>object(<br>    {<br>      folder_annotation_key = string<br>      label                 = map(string)<br>      namespace             = string<br>    }<br>  )</pre> | `null` | no |
| <a name="input_instance_profile_name"></a> [instance\_profile\_name](#input\_instance\_profile\_name) | The name of the IAM instance profile to attach to every instance launched by Karpenter. | `string` | n/a | yes |
| <a name="input_karpenter_image_registry"></a> [karpenter\_image\_registry](#input\_karpenter\_image\_registry) | The container image registry from which the Karpenter images will be pulled.  The images must be in the karpenter/controller repository.<br>The value can have an optional path suffix to support the use of ECR pull-through caches. | `string` | `"public.ecr.aws"` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | An optional map of kubernetes labels to attach to every resource created by the module. | `map(string)` | `{}` | no |
| <a name="input_node_security_group_ids"></a> [node\_security\_group\_ids](#input\_node\_security\_group\_ids) | An optional set of additional security groups to nodes provisioned with the default node templates managed by the module. | `set(string)` | `[]` | no |
| <a name="input_node_subnets"></a> [node\_subnets](#input\_node\_subnets) | A list of objects containing the IDs and ARNs of the AWS subnets in which the EKS cluster's nodes are launched. | <pre>list(<br>    object({<br>      id  = string<br>      arn = string<br>    })<br>  )</pre> | n/a | yes |
| <a name="input_node_volume_size"></a> [node\_volume\_size](#input\_node\_volume\_size) | The size, in gigabytes, of the volumes attached to instances launched by Karpenter | `number` | `512` | no |
| <a name="input_pod_resources"></a> [pod\_resources](#input\_pod\_resources) | CPU and memory settings for the controller pods. | <pre>object(<br>    {<br>      limits = optional(object(<br>        {<br>          cpu    = optional(string, "1000m")<br>          memory = optional(string, "1Gi")<br>        }<br>        ),<br>      {})<br>      requests = optional(<br>        object(<br>          {<br>            cpu    = optional(string, "1000m")<br>            memory = optional(string, "1Gi")<br>          }<br>        ),<br>      {})<br>    }<br>  )</pre> | `{}` | no |
| <a name="input_pod_security_standards"></a> [pod\_security\_standards](#input\_pod\_security\_standards) | Configures the levels of the pod security admission modes on the build pod namespace<br><br>https://kubernetes.io/docs/concepts/security/pod-security-admission/<br>https://kubernetes.io/docs/tasks/configure-pod-container/enforce-standards-namespace-labels/<br>https://kubernetes.io/docs/concepts/security/pod-security-standards/ | <pre>object({<br>    audit   = optional(string, "restricted")<br>    enforce = optional(string, "restricted")<br>    warn    = optional(string, "restricted")<br>  })</pre> | `{}` | no |
| <a name="input_provisioners"></a> [provisioners](#input\_provisioners) | An optional map containing objects that define Karpenter Provisioner resources the module will manage.  The keys in<br>the map are used as the name of the provisioner.  The attributes of the objects correspond to a subset of the attributes<br>of the Provisioner resource's spec attribute.<br><br>All provisioners specified in the argument are configured with to use the Bottlerocket node template managed by this<br>module.  Provisioner resources can be created outside of this module but managing them with the module requires less<br>boilerplate code.  It also ensures the resources are updated to reflect any changes to the CRDs when Karpenter is upgraded.<br><br>For details on the provisioner attributes, see https://karpenter.sh/v0.24.0/concepts/provisioners/. | <pre>map(object({<br>    annotations = optional(map(string), {})<br>    consolidation = optional(object({<br>      enabled = optional(bool, true)<br>      }),<br>    {})<br>    labels = optional(map(string), {})<br>    limits = optional(object({<br>      resources = optional(object({<br>        cpu    = optional(string, "1k")<br>        memory = optional(string, "1000Gi")<br>        }),<br>      {})<br>      }),<br>    {})<br>    requirements = optional(list(<br>      object({<br>        key      = string<br>        operator = optional(string, "In")<br>        values   = optional(set(string), [])<br>      })),<br>    [])<br>    startupTaints = optional(list(<br>      object(<br>        {<br>          key    = string<br>          value  = optional(string)<br>          effect = string<br>        }<br>      )),<br>    [])<br>    taints = optional(list(<br>      object(<br>        {<br>          key    = string<br>          value  = optional(string)<br>          effect = string<br>        }<br>      )),<br>    [])<br>    ttlSecondsAfterEmpty   = optional(number)<br>    ttlSecondsUntilExpired = optional(number)<br>    weight                 = optional(number)<br>  }))</pre> | `{}` | no |
| <a name="input_replicas"></a> [replicas](#input\_replicas) | The number of Karpenter pods to run.  Must be greater than or equal to one. | `number` | `2` | no |
| <a name="input_service_monitor"></a> [service\_monitor](#input\_service\_monitor) | Controls deployment and configuration of a ServiceMonitor custom resource to enable Prometheus metrics scraping.  The kube-prometheus-stack CRDs must be available in the k8s cluster if  `enabled` is set to `true`. | <pre>object({<br>    enabled         = optional(bool, true)<br>    scrape_interval = optional(string, "30s")<br>  })</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | An optional map of AWS tags to attach to every resource created by the module. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bottlerocket_node_template_name"></a> [bottlerocket\_node\_template\_name](#output\_bottlerocket\_node\_template\_name) | The name of the AWSNodeTemplate resource for Bottlerocket nodes. |
| <a name="output_bottlerocket_node_template_provider_ref"></a> [bottlerocket\_node\_template\_provider\_ref](#output\_bottlerocket\_node\_template\_provider\_ref) | An object to use as the value of the Karpenter Provisioner resource's spec.providerRef attribute for Bottlerocket nodes. |
| <a name="output_node_security_group_selector"></a> [node\_security\_group\_selector](#output\_node\_security\_group\_selector) | A string containing the cluster security group IDs separated by a comma.  Intended to be used as the value of the spec.securityGroupSelector.aws-id attribute in Karpenter AWSNodeTemplate K8s resources. |
| <a name="output_node_subnet_id_selector"></a> [node\_subnet\_id\_selector](#output\_node\_subnet\_id\_selector) | A string containing the node subnet IDs separated by a comma.  Intended to be used as the value of the spec.subnetSelector.aws-id attribute in Karpenter AWSNodeTemplate K8s resources. |
| <a name="output_required_tags"></a> [required\_tags](#output\_required\_tags) | A map of AWS tags that Karpenter must apply to the EC2 resources it creates.  It must be included in the spec.tags attribute in any Karpenter AWSNodeTemplate resource. |
<!-- END_TF_DOCS -->