# AWS Load Balancer Controller

## Overview

Deploys version 2.6.x or 2.5.x of the [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.6/) to an EKS cluster.  The module creates an [IAM role for the controller's service account](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html) to grant it permission to access the AWS API.

## Ingress Classes

In addition to deploying the controller, the module deploys two ingress classes.  One class is configured to create [internal application load](https://docs.aws.amazon.com/elasticloadbalancing/latest/classic/elb-internal-load-balancers.html) balancers while the other is configured to create [internet-facing application load balancers](https://docs.aws.amazon.com/elasticloadbalancing/latest/classic/elb-internet-facing-load-balancers.html).

| Name | Scheme | Configuration Variable |
| --- | --- | --- |
| internal-application-load-balancer | internal | internal_ingress_class_parameters |
| internet-facing-application-load-balancer | internet-facing | internet_facing_ingress_class_parameters |

## Limitations

- IPv6 is not supported.
- [Ingress groups](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.45guide/ingress/annotations/#ingressgroup) are disabled.
- Only one controller deployment per cluster is allowed.  This is [a limitation of the controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/deploy/configurations/), not just the module.

## References

- [Official documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.5/)
- [Helm chart](https://github.com/kubernetes-sigs/aws-load-balancer-controller/tree/main/helm/aws-load-balancer-controller)
- [Reference IAM policy for the controller's role](https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/main/docs/install/iam_policy.json)
- [A detailed explanation of the various security groups used by the controller](https://github.com/kubernetes-sigs/aws-load-balancer-controller/issues/2118)
- [ALB Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html)
- [NLB Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/introduction.html)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.11 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 2.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.23 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.11 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | >= 2.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.23 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_role.service_account](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.elb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.features](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_security_group.alb_backend](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [helm_release.controller](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubectl_manifest.ingress_class_params](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [kubernetes_ingress_class_v1.predefined](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/ingress_class_v1) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.elb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.shield](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.trust_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.waf](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.wavf2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_vpc.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alb_access_logs"></a> [alb\_access\_logs](#input\_alb\_access\_logs) | An optional object whose attributes are used to enable and configure ALB access log storage in an existing S3 bucket.  The values are applied to every IngressClassParams object created by the module. | <pre>object({<br>    bucket_name   = string<br>    bucket_prefix = optional(string, "alb")<br>    enabled       = optional(bool, true)<br>  })</pre> | `null` | no |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | The version of the 'aws-load-balancer-controller' Helm chart to use.  See https://github.com/aws/eks-charts/tree/master/stable/aws-load-balancer-controller for the list of valid versions. | `string` | n/a | yes |
| <a name="input_default_aws_resource_tags"></a> [default\_aws\_resource\_tags](#input\_default\_aws\_resource\_tags) | An optional map of AWS tags to attach to every AWS resource created by the controller. | `map(string)` | `{}` | no |
| <a name="input_default_tls_security_policy"></a> [default\_tls\_security\_policy](#input\_default\_tls\_security\_policy) | The default ALB TLS (SSL) security policy to use for HTTPS listeners.  It must be valid for both ALBs and NLBs.<br>The available ALB policies are listed at https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-https-listener.html#describe-ssl-policies.<br>The available NLB policies are listed at https://docs.aws.amazon.com/elasticloadbalancing/latest/network/create-tls-listener.html#describe-ssl-policies | `string` | `"ELBSecurityPolicy-FS-1-2-Res-2020-10"` | no |
| <a name="input_eks_cluster"></a> [eks\_cluster](#input\_eks\_cluster) | Attributes of the EKS cluster on which the controller is deployed.  The names of the attributes match the names of outputs in the eks-cluster module to allow using the module as the argument to this variable.<br><br>The `cluster_name` attribute the the name of the EKS cluster.  It is required.<br>The `cluster_security_group_id` is the ID of the security group generated by EKS when the cluster was created.  It is required.<br>The `service_account_oidc_audience_variable` attribute is the ID of the cluster's IAM OIDC identity provider with the string ":aud" appended to it.  It is required.<br>The `service_account_oidc_subject_variable` attribute is the ID of the cluster's IAM OIDC identity provider with the string ":sub" appended to it.  It is required.<br>The 'service\_account\_oidc\_provider\_arn' attribute is the ARN of the cluster's IAM OIDC identity provider.  It is required. | <pre>object({<br>    cluster_name                           = string<br>    cluster_security_group_id              = string<br>    service_account_oidc_audience_variable = string<br>    service_account_oidc_subject_variable  = string<br>    service_account_oidc_provider_arn      = string<br>  })</pre> | n/a | yes |
| <a name="input_enabled_features"></a> [enabled\_features](#input\_enabled\_features) | "Enable support for optional features.  Specify 'serviceMutatorWebhook' to make this controller<br>the default for all new LoadBalancer services, 'shield' for AWS Shield, 'waf' for AWS WAFv1, and/or 'wafv2' for AWS WAFv2.  Defaults to 'wafv2'." | `set(string)` | <pre>[<br>  "wafv2"<br>]</pre> | no |
| <a name="input_externally_managed_tag_keys"></a> [externally\_managed\_tag\_keys](#input\_externally\_managed\_tag\_keys) | AWS Tag keys that will be managed externally. Specified Tags are ignored during reconciliation. | `list(string)` | `[]` | no |
| <a name="input_internal_ingress_class_parameters"></a> [internal\_ingress\_class\_parameters](#input\_internal\_ingress\_class\_parameters) | Configures IngressClassParams resource assigned to the `internal-application-load-balancer` IngressClass resource managed by the module.  The class is used to create internal application load balancers.<br>The variable allows for configuration of the inboundCIDRs, namespaceSelector, tags, and selected attributes of the loadBalancerAttributes parameters.  The classes scheme paramter is set to internet-facing.<br>**Due to naming limitations of object attributes in Terraform type definitions, the dots in the attribute names must be replaced with dashes.**<br>For more details on the parameters see https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/guide/ingress/ingress_class/#ingressclassparams-specification | <pre>object({<br>    inbound_cidrs = optional(list(string), [])<br>    load_balancer_attributes = optional(<br>      object({<br>        idle_timeout-timeout_seconds                             = optional(number, 60)<br>        routing-http-desync_mitigation_mode                      = optional(string, "strictest")<br>        routing-http-drop_invalid_header_fields-enabled          = optional(bool, true)<br>        routing-http-preserve_host_header-enabled                = optional(bool, false)<br>        routing-http-x_amzn_tls_version_and_cipher_suite-enabled = optional(bool, false)<br>        routing-http-xff_client_port-enabled                     = optional(bool, false)<br>        routing-http-xff_header_processing-mode                  = optional(string, "remove")<br>        waf-fail_open-enabled                                    = optional(bool, false)<br>      }),<br>    {})<br>    namespace_selector = optional(<br>      object({<br>        match_expressions = optional(list(<br>          object({<br>            key      = string<br>            operator = string<br>            values   = optional(list(string), [])<br>          })<br>          ),<br>        [])<br>        match_labels = optional(map(string), {})<br>      }),<br>    {})<br>    tags = optional(map(string), {})<br>  })</pre> | `{}` | no |
| <a name="input_internet_facing_ingress_class_parameters"></a> [internet\_facing\_ingress\_class\_parameters](#input\_internet\_facing\_ingress\_class\_parameters) | Configures IngressClassParams resource assigned to the `internet-facing-application-load-balancer` IngressClass resource managed by the module.  The class is used to create internet-facing application load balancers.<br>The variable allows for configuration of the namespaceSelector, tags, and selected attributes of the loadBalancerAttributes parameters.  The classes scheme paramter is set to internet-facing.<br>For more details on the parameters see https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/guide/ingress/ingress_class/#ingressclassparams-specification | <pre>object({<br>    load_balancer_attributes = optional(<br>      object({<br>        idle_timeout-timeout_seconds                             = optional(number, 60)<br>        routing-http-desync_mitigation_mode                      = optional(string, "strictest")<br>        routing-http-drop_invalid_header_fields-enabled          = optional(bool, true)<br>        routing-http-preserve_host_header-enabled                = optional(bool, false)<br>        routing-http-x_amzn_tls_version_and_cipher_suite-enabled = optional(bool, false)<br>        routing-http-xff_client_port-enabled                     = optional(bool, false)<br>        routing-http-xff_header_processing-mode                  = optional(string, "remove")<br>        waf-fail_open-enabled                                    = optional(bool, false)<br>      }),<br>    {})<br>    namespace_selector = optional(<br>      object({<br>        match_expressions = optional(list(<br>          object({<br>            key      = string<br>            operator = optional(string, "In")<br>            values   = optional(list(string), [])<br>          })<br>          ),<br>        [])<br>        match_labels = optional(map(string), {})<br>      }),<br>    {})<br>    tags = optional(map(string), {})<br>  })</pre> | `{}` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | An optional map of Kubernetes labels to attach to every resource created by the module. | `map(string)` | `{}` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Configures the log verbosity of the controller.  Must be one of debug or info. | `string` | `"info"` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | The namespace where the controller will be installed. | `string` | `"kube-system"` | no |
| <a name="input_node_selector"></a> [node\_selector](#input\_node\_selector) | An optional map of node labels to use the node selector of all pods. | `map(string)` | `{}` | no |
| <a name="input_node_tolerations"></a> [node\_tolerations](#input\_node\_tolerations) | An optional list of objects to set node tolerations on all pods.  The object structure corresponds to the structure of the<br>toleration syntax in the Kubernetes pod spec.<br><br>https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/ | <pre>list(object(<br>    {<br>      key      = string<br>      operator = string<br>      value    = optional(string)<br>      effect   = string<br>    }<br>  ))</pre> | `[]` | no |
| <a name="input_pod_resources"></a> [pod\_resources](#input\_pod\_resources) | CPU and memory settings for the controller pods. | <pre>object(<br>    {<br>      limits = optional(object(<br>        {<br>          cpu    = optional(string, "2000m")<br>          memory = optional(string, "512Mi")<br>        }<br>        ),<br>      {})<br>      requests = optional(<br>        object(<br>          {<br>            cpu    = optional(string, "500m")<br>            memory = optional(string, "256Mi")<br>          }<br>        ),<br>      {})<br>    }<br>  )</pre> | `{}` | no |
| <a name="input_replica_count"></a> [replica\_count](#input\_replica\_count) | The number of controller pods to run. | `number` | `2` | no |
| <a name="input_service_monitor"></a> [service\_monitor](#input\_service\_monitor) | Controls deployment and configuration of a ServiceMonitor custom resource to enable Prometheus metrics scraping.  The kube-prometheus-stack CRDs must be available in the k8s cluster if  `enabled` is set to `true`. | <pre>object({<br>    enabled         = optional(bool, true)<br>    scrape_interval = optional(string, "30s")<br>  })</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | An optional map of AWS tags to attach to every resource created by the module. | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | The unique identifier of the VPC where the target EKS cluster is deployed. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ingress_class_controller"></a> [ingress\_class\_controller](#output\_ingress\_class\_controller) | The value to use for the spec.controller field on a Kubernetes IngressClass resource to have the controller reconcile Ingress resources configured with the class. |
| <a name="output_ingress_class_parameters_access_logs_attributes"></a> [ingress\_class\_parameters\_access\_logs\_attributes](#output\_ingress\_class\_parameters\_access\_logs\_attributes) | A map containing the load balancer attributes that configure ALB access logging.  The values match the values supplied by the alb\_access\_logs variable.  Any IngressClassParams resource created outside fo the module should include these attributes. |
| <a name="output_ingress_class_parameters_api_group"></a> [ingress\_class\_parameters\_api\_group](#output\_ingress\_class\_parameters\_api\_group) | The Kubernetes API group of the custom resource the controller uses to configure the IngressClasses it reconciles. |
| <a name="output_ingress_class_parameters_api_version"></a> [ingress\_class\_parameters\_api\_version](#output\_ingress\_class\_parameters\_api\_version) | The Kubernetes API group of the custom resource the controller uses to configure the IngressClasses it reconciles. |
| <a name="output_ingress_class_parameters_kind"></a> [ingress\_class\_parameters\_kind](#output\_ingress\_class\_parameters\_kind) | The Kubernetes Kind of the custom resource the controller uses to configure the IngressClasses it reconciles. |
| <a name="output_internal_ingress_class_name"></a> [internal\_ingress\_class\_name](#output\_internal\_ingress\_class\_name) | The name of the IngressClass resource to use for internal application load balancers. |
| <a name="output_internet_facing_ingress_class_name"></a> [internet\_facing\_ingress\_class\_name](#output\_internet\_facing\_ingress\_class\_name) | The name of the IngressClass resource to use for internet-facing application load balancers. |
| <a name="output_pod_readiness_gate_namespace_labels"></a> [pod\_readiness\_gate\_namespace\_labels](#output\_pod\_readiness\_gate\_namespace\_labels) | A map containing the labels to add to a namespace to enable the controller's pod readiness gate in that namespace.  https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/deploy/pod_readiness_gate |
| <a name="output_service_account_role_arn"></a> [service\_account\_role\_arn](#output\_service\_account\_role\_arn) | The ARN of the IAM role created for the controller's k8s service account. |
| <a name="output_service_account_role_name"></a> [service\_account\_role\_name](#output\_service\_account\_role\_name) | The name of the IAM role created for the controller's k8s service account. |
| <a name="output_service_load_balancer_class"></a> [service\_load\_balancer\_class](#output\_service\_load\_balancer\_class) | When creating a Kubernetes Service resource whose type is LoadBalancer, specify the spec.loadBalancerClass attribute of the Service to this value to have the controller manage the service's NLB.  https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/guide/service/nlb/ |
| <a name="output_shared_backend_security_group_arn"></a> [shared\_backend\_security\_group\_arn](#output\_shared\_backend\_security\_group\_arn) | The ARN of the backend security group shared among all application load balancers managed by the controller. |
| <a name="output_shared_backend_security_group_id"></a> [shared\_backend\_security\_group\_id](#output\_shared\_backend\_security\_group\_id) | The ID of the backend security group shared among all application load balancers managed by the controller. |
| <a name="output_shared_backend_security_group_resource"></a> [shared\_backend\_security\_group\_resource](#output\_shared\_backend\_security\_group\_resource) | An object containing all of the attributes of the backend security group shared among all application load balancers managed by the controller. |
<!-- END_TF_DOCS -->