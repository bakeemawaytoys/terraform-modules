# Flagger Progressive Deployment Operator

## Overview

A Terraform module to deploy and manage [Flagger](https://docs.flagger.app/) for automated progressive deployments in Kubernetes.  The module configures Flagger to use [Prometheus](https://docs.flagger.app/usage/metrics#prometheus) as its metrics source and the [nginx Ingress Controller as its service mesh implementation](https://docs.flagger.app/tutorials/nginx-progressive-delivery).  Flagger supports [canary](https://docs.flagger.app/usage/deployment-strategies#canary-release), [A/B](https://docs.flagger.app/usage/deployment-strategies#a-b-testing), and [blue-green](https://docs.flagger.app/usage/deployment-strategies#blue-green-deployments) deployment strategies with the nginx ingress controller.  The module assumes it is the only Flagger deployment in the entire Kubernetes cluster.  When Prometheus is deployed using the Prometheus Operator, the `honorLabels` attribute on the `endpoints` in the Nginx ingress controller's [ServiceMonitor resource](https://prometheus-operator.dev/docs/operator/api/#monitoring.coreos.com/v1.ServiceMonitor) must be set to `true`.  By default, the Prometheus Operator will rewrite any metrics labels whose names collide with the labels it adds itself.  One of the labels renamed, `namespace`, is used in the two Prometheus metrics queries built into Flagger.  The result is that those queries don't return results and all canary deployments fail.  When `honorLabels` is set to `true`, the labels are not rewritten and the queries work.   Starting with version 8.0.1, the [`elb-nginx-ingress-controller` module](../elb-nginx-ingress-controller) sets `honorLabels` to `true`.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.11 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 2.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.23 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.11 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | >= 2.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.23 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.this](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubectl_manifest.crd](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.prometheus_rule](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [kubernetes_cluster_role_v1.admin_aggregate](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_v1) | resource |
| [kubernetes_cluster_role_v1.edit_aggregate](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_v1) | resource |
| [kubernetes_cluster_role_v1.view_aggregate](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_v1) | resource |
| [kubernetes_config_map_v1.leader_election](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map_v1) | resource |
| [kubectl_file_documents.crd](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/data-sources/file_documents) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | The version of the Flagger Helm chart to deploy.  Must be 1.35.x where x is a positive integer. | `string` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The name of the EKS cluster in which Flagger is deployed by this module. | `string` | n/a | yes |
| <a name="input_labels"></a> [labels](#input\_labels) | An optional map of kubernetes labels to attach to every resource created by the module. | `map(string)` | `{}` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Configures the level of the Flagger logger.  Must be one of `debug`, `info`, `warning`, or `error`. | `string` | `"info"` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | The namespace where the controller will be installed.  It must already exist and must be the namespace that contains the nginx ingress controller(s). | `string` | n/a | yes |
| <a name="input_node_selector"></a> [node\_selector](#input\_node\_selector) | An optional map of node labels to use the node selector of all pods. | `map(string)` | `{}` | no |
| <a name="input_node_tolerations"></a> [node\_tolerations](#input\_node\_tolerations) | An optional list of objects to set node tolerations on all pods.  The object structure corresponds to the structure of the<br>toleration syntax in the Kubernetes pod spec.<br><br>https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/ | <pre>list(object(<br>    {<br>      key      = string<br>      operator = string<br>      value    = optional(string)<br>      effect   = string<br>    }<br>  ))</pre> | `[]` | no |
| <a name="input_pod_resources"></a> [pod\_resources](#input\_pod\_resources) | CPU and memory resource for the controller pods. | <pre>object(<br>    {<br>      limits = optional(object(<br>        {<br>          cpu    = optional(string, "500m")<br>          memory = optional(string, "256Mi")<br>        }<br>        ),<br>      {})<br>      requests = optional(<br>        object(<br>          {<br>            cpu    = optional(string, "250m")<br>            memory = optional(string, "128Mi")<br>          }<br>        ),<br>      {})<br>    }<br>  )</pre> | `{}` | no |
| <a name="input_prometheus_rule"></a> [prometheus\_rule](#input\_prometheus\_rule) | An object whose attributes enable and configure a PromtheusRule Kubernetes resource to monitor Flagger's metrics. | <pre>object({<br>    enabled                   = optional(bool, true)<br>    interval                  = optional(string, "30s")<br>    canary_rollback_serverity = optional(string, "critical")<br>  })</pre> | `{}` | no |
| <a name="input_prometheus_url"></a> [prometheus\_url](#input\_prometheus\_url) | The URL of the Prometheus instance containing the metrics to analyze during deployments. | `string` | n/a | yes |
| <a name="input_replica_count"></a> [replica\_count](#input\_replica\_count) | The number of controller pods to run. | `number` | `2` | no |
| <a name="input_service_monitor"></a> [service\_monitor](#input\_service\_monitor) | Controls deployment and configuration of a ServiceMonitor custom resource to enable Prometheus metrics scraping.  The kube-prometheus-stack CRDs must be available in the k8s cluster if  `enabled` is set to `true`. | <pre>object({<br>    enabled      = optional(bool, true)<br>    honor_labels = optional(bool, false)<br>  })</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_admin_cluster_role"></a> [admin\_cluster\_role](#output\_admin\_cluster\_role) | The name of the Kubernetes ClusterRole that grants admin privileges to all Flagger custom resources. |
| <a name="output_edit_cluster_role"></a> [edit\_cluster\_role](#output\_edit\_cluster\_role) | The name of the Kubernetes ClusterRole that grants edit privileges to some Flagger custom resources. |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | The namespace containing the Flagger deployment. |
| <a name="output_view_cluster_role"></a> [view\_cluster\_role](#output\_view\_cluster\_role) | The name of the Kubernetes ClusterRole that grants view privileges to some Flagger custom resources. |
<!-- END_TF_DOCS -->