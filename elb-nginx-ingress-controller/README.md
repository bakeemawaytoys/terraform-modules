# ELB Nginx Ingress Controller

## Overview

Deploys the Kubernetes Nginx Ingress Controller to a Kubernetes cluster using [the official Helm chart](https://github.com/kubernetes/ingress-nginx/tree/main/charts/ingress-nginx).  The module currently supports version 4.7.x through 4.9.x of the Helm chart.

The module is modeled after an Ansible role that was modeled after a Helm project.  It makes a few improvements to the Ansible version such as including tags and enabling access logging on the Elastic Load Balancer.  Otherwise, it uses the same configuration and variable.  Few changes were made because the intent is to move away from the Nginx Ingress Controller in the near future.  The module acts as a stop-gap that allows for manage the existing deployments through Terraform.

## Supported Versions

| Helm Chart | Controller | Kubernetes |
|------------|------------|------------|
| [4.7.0](https://github.com/kubernetes/ingress-nginx/blob/main/charts/ingress-nginx/changelog/Changelog-4.7.0.md) | [1.8.0](https://github.com/kubernetes/ingress-nginx/releases/tag/controller-v1.8.0) | 1.27, 1.26, 1.25, 1.24 |
| [4.7.1](https://github.com/kubernetes/ingress-nginx/blob/main/charts/ingress-nginx/changelog/Changelog-4.7.1.md) | [1.8.1](https://github.com/kubernetes/ingress-nginx/releases/tag/controller-v1.8.1) | 1.27, 1.26, 1.25, 1.24 |
| [4.7.2](https://github.com/kubernetes/ingress-nginx/blob/main/charts/ingress-nginx/changelog/Changelog-4.7.2.md) | [1.8.2](https://github.com/kubernetes/ingress-nginx/releases/tag/controller-v1.8.2) | 1.27, 1.26, 1.25, 1.24 |
| [4.8.0](https://github.com/kubernetes/ingress-nginx/blob/main/charts/ingress-nginx/changelog/Changelog-4.8.0.md) | [1.9.0](https://github.com/kubernetes/ingress-nginx/releases/tag/controller-v1.9.0) | 1.28, 1.27, 1.26, 1.25 |
| [4.8.1](https://github.com/kubernetes/ingress-nginx/blob/main/charts/ingress-nginx/changelog/Changelog-4.8.1.md) | [1.9.1](https://github.com/kubernetes/ingress-nginx/releases/tag/controller-v1.9.1) | 1.28, 1.27, 1.26, 1.25 |
| [4.8.2](https://github.com/kubernetes/ingress-nginx/blob/main/charts/ingress-nginx/changelog/Changelog-4.8.2.md) | [1.9.3](https://github.com/kubernetes/ingress-nginx/releases/tag/controller-v1.9.3) | 1.28, 1.27, 1.26, 1.25 |
| [4.8.3](https://github.com/kubernetes/ingress-nginx/blob/main/charts/ingress-nginx/changelog/Changelog-4.8.3.md) | [1.9.4](https://github.com/kubernetes/ingress-nginx/releases/tag/controller-v1.9.4) | 1.28, 1.27, 1.26, 1.25 |
| [4.9.0](https://github.com/kubernetes/ingress-nginx/blob/main/charts/ingress-nginx/changelog/Changelog-4.9.0.md) | [1.9.3](https://github.com/kubernetes/ingress-nginx/releases/tag/controller-v1.9.5) | 1.28, 1.27, 1.26, 1.25 |

## References

* [Ingress Controller Documentation provided by Kubernetes](https://kubernetes.github.io/ingress-nginx/)
* [Kubernetes AWS Cloud Provider documentation](https://cloud-provider-aws.sigs.k8s.io/service_controller/).  It contains documentation for k8s annotations used to configure the ELB.
* [Helm chart default values](https://github.com/kubernetes/ingress-nginx/blob/main/charts/ingress-nginx/values.yaml)

Note: Do NOT use the [Ingress Controller Documentation provided by Nginx](https://docs.nginx.com/nginx-ingress-controller/).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.9 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 2.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.23 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.9 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | >= 2.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.23 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.nginx](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_config_map_v1.grafana_dashboard](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map_v1) | resource |
| [aws_default_tags.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/default_tags) | data source |
| [kubectl_server_version.current](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/data-sources/server_version) | data source |
| [kubernetes_service_v1.controller](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/data-sources/service_v1) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_logging"></a> [access\_logging](#input\_access\_logging) | An object whose attributes configures the generation and destination of the ELB access logs.<br><br>The `enabled` attribute determines if access logs are generated for this bucket.  Defaults to false.<br>The `bucket` attribute is the name of the S3 bucket where the access logs will be written.  It cannot be empty if `enabled` is set to true.<br>The `prefix` attribute configures a a string to prepend to the key of every access log object created.  It is optional. | <pre>object({<br>    enabled = optional(bool, false)<br>    bucket  = optional(string)<br>    prefix  = optional(string, "")<br>  })</pre> | `{}` | no |
| <a name="input_allow_snippet_annotations"></a> [allow\_snippet\_annotations](#input\_allow\_snippet\_annotations) | Set to true to allow ingress resources to set the `nginx.ingress.kubernetes.io/configuration-snippet` annotation.  Defaults to false. | `bool` | `false` | no |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | The version of the 'ingress-nginx' Helm chart to use.  Must be in either the 4.7.x, 4.8.x, or 4.9.x releases.  See https://github.com/kubernetes/ingress-nginx/releases for the list of valid versions. | `string` | n/a | yes |
| <a name="input_controller_pod_resources"></a> [controller\_pod\_resources](#input\_controller\_pod\_resources) | CPU and memory settings for the controller pods.  Defaults to the same values as the Helm chart's default values. | <pre>object(<br>    {<br>      limits = optional(object(<br>        {<br>          cpu    = optional(string, "200m")<br>          memory = optional(string, "180Mi")<br>        }<br>        ),<br>      {})<br>      requests = optional(<br>        object(<br>          {<br>            cpu    = optional(string, "100m")<br>            memory = optional(string, "90Mi")<br>          }<br>        ),<br>      {})<br>    }<br>  )</pre> | `{}` | no |
| <a name="input_controller_replica_count"></a> [controller\_replica\_count](#input\_controller\_replica\_count) | The number of controller pods to run. | `number` | `2` | no |
| <a name="input_default_ssl_certificate_name"></a> [default\_ssl\_certificate\_name](#input\_default\_ssl\_certificate\_name) | The name (without the namespace) of the Kubernetes secret containing the TLS certificate to use by default.  Must be in the namespace specified in the 'namespace' variable. | `string` | n/a | yes |
| <a name="input_enable_admission_webhook"></a> [enable\_admission\_webhook](#input\_enable\_admission\_webhook) | Enables deployment of the ingress controller's validating webhook. | `bool` | `true` | no |
| <a name="input_grafana_dashboard_config"></a> [grafana\_dashboard\_config](#input\_grafana\_dashboard\_config) | Configures the optional deployment of Grafana dashboards in configmaps.  Set the value to null to disable dashboard installation.  The dashboards will be added to the "Nginx Ingress" folder in the Grafana UI.<br><br>The 'folder\_annotation\_key' attribute is the Kubernets annotation that configures the Grafana folder into which the dasboards will appear in the Grafana UI.  It cannot be null or empty.<br>The 'label' attribute is a single element map containing the label the Grafana sidecar uses to discover configmaps containing dashboards.  It cannot be null or empty.<br>The 'namespace' attribute is the namespace where the configmaps are deployed.  It cannot be null or empty.<br><br>* https://github.com/grafana/helm-charts/tree/main/charts/grafana#sidecar-for-dashboards | <pre>object(<br>    {<br>      folder_annotation_key = string<br>      label                 = map(string)<br>      namespace             = string<br>    }<br>  )</pre> | `null` | no |
| <a name="input_image_registry"></a> [image\_registry](#input\_image\_registry) | The container image registry from which the controller images will be pulled.  The images must be in the `ingress-nginx/controller` repository.<br>The value can have an optional path suffix to support the use of ECR pull-through caches. | `string` | `"registry.k8s.io"` | no |
| <a name="input_ingress_class_resource"></a> [ingress\_class\_resource](#input\_ingress\_class\_resource) | Configures the attributes of the ingress class resource created by the Helm chart.  Note that unlike the Helm chart, the ingress class will be set as the default class. | <pre>object(<br>    {<br>      name    = optional(string, "nginx")<br>      default = optional(bool, true)<br>    }<br>  )</pre> | `{}` | no |
| <a name="input_internal"></a> [internal](#input\_internal) | Set to true if the ingress traffic originates inside the AWS network or false if it originates from the Internet. | `bool` | `false` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | An optional map of kubernetes labels to attach to every resource created by the module. | `map(string)` | `{}` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | The namespace where the controller will be installed.  It must already exist. | `string` | `"kube-system"` | no |
| <a name="input_nginx_custom_configuration"></a> [nginx\_custom\_configuration](#input\_nginx\_custom\_configuration) | Custom Nginx configuration options.  See https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/ for the full list of available options. | `map(any)` | `{}` | no |
| <a name="input_node_selector"></a> [node\_selector](#input\_node\_selector) | An optional map of node labels to use the node selector of all pods. | `map(string)` | `{}` | no |
| <a name="input_node_tolerations"></a> [node\_tolerations](#input\_node\_tolerations) | An optional list of objects to set node tolerations on all pods.  The object structure corresponds to the structure of the<br>toleration syntax in the Kubernetes pod spec.<br><br>https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/ | <pre>list(object(<br>    {<br>      key      = string<br>      operator = string<br>      value    = optional(string)<br>      effect   = string<br>    }<br>  ))</pre> | `[]` | no |
| <a name="input_priority_class_name"></a> [priority\_class\_name](#input\_priority\_class\_name) | The k8s priority class to assign to the controller pods.  Defaults to system-cluster-critical.  Set to an empty string to use the cluster default priority. | `string` | `"system-cluster-critical"` | no |
| <a name="input_release_name"></a> [release\_name](#input\_release\_name) | The name to give to the Helm release. | `string` | `"nginx"` | no |
| <a name="input_service_monitor"></a> [service\_monitor](#input\_service\_monitor) | Controls deployment and configuration of a ServiceMonitor custom resource to enable Prometheus metrics scraping.  The kube-prometheus-stack CRDs must be available in the k8s cluster if  `enabled` is set to `true`. | <pre>object({<br>    enabled         = optional(bool, true)<br>    scrape_interval = optional(string, "30s")<br>  })</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | An optional map of AWS tags to attach to every resource created by the module. | `map(string)` | `{}` | no |
| <a name="input_watch_ingress_without_class"></a> [watch\_ingress\_without\_class](#input\_watch\_ingress\_without\_class) | Set to true to process Ingress objects without ingressClass annotation/ingressClassName field, false to ignore them. | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_elb_hostname"></a> [elb\_hostname](#output\_elb\_hostname) | The hostname of the ELB the cluster created for the controller's Kubernetes service. |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | The name of the Kubernetes namespace where the controller resources are deployed. |
<!-- END_TF_DOCS -->