# Kubernetes Metrics Server

## Overview

A Terraform module to deploy [the Kubernetes Metrics Server](https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/).  The module uses [the official Helm chart](https://github.com/kubernetes-sigs/metrics-server/tree/master/charts/metrics-server) to deploy it in the `kube-system` namespace.  The Helm release is configured to deploy at least two pods along with a [pod disruption budget](https://kubernetes.io/docs/concepts/workloads/pods/disruptions/#pod-disruption-budgets) to ensure high availability.

## Additional Resources

- [Metrics Server Documentation](https://kubernetes-sigs.github.io/metrics-server/)
- [Kubernetes Metrics Server repo](https://github.com/kubernetes-sigs/metrics-server)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.4 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.9 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.9 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.metrics_server](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | The Metrics Server Helm chart version to use.  Supported versions are 3.8.x, 3.9.x, and 3.10.x.  See https://github.com/kubernetes-sigs/metrics-server/releases for the list of available versions. | `string` | n/a | yes |
| <a name="input_enable_service_monitor"></a> [enable\_service\_monitor](#input\_enable\_service\_monitor) | Set to true to deploy a ServiceMonitor resource for scraping Prometheus Karpenter metrics. | `bool` | `true` | no |
| <a name="input_image_registry"></a> [image\_registry](#input\_image\_registry) | The container image registry from which the images will be pulled.  The images must be in the metrics-server/metrics-server repository.  Defaults to the registry.k8s.io.<br>The value can have an optional path suffix to support the use of ECR pull-through caches. | `string` | `"registry.k8s.io"` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | An optional map of kubernetes labels to attach to every resource created by the module. | `map(string)` | `{}` | no |
| <a name="input_node_selector"></a> [node\_selector](#input\_node\_selector) | An optional map of node labels to use the node selector of the pods. | `map(string)` | `{}` | no |
| <a name="input_node_tolerations"></a> [node\_tolerations](#input\_node\_tolerations) | An optional list of objects to set node tolerations on the pods.  The object structure corresponds to the structure of the<br>toleration syntax in the Kubernetes pod spec.<br><br>https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/ | <pre>list(object(<br>    {<br>      key      = string<br>      operator = string<br>      value    = optional(string)<br>      effect   = string<br>    }<br>  ))</pre> | `[]` | no |
| <a name="input_pod_resources"></a> [pod\_resources](#input\_pod\_resources) | CPU and memory settings for the pods. | <pre>object(<br>    {<br>      limits = optional(<br>        object(<br>          {<br>            cpu    = optional(string, "100m")<br>            memory = optional(string, "256Mi")<br>          }<br>        ),<br>      {})<br>      requests = optional(<br>        object(<br>          {<br>            cpu    = optional(string, "100m")<br>            memory = optional(string, "256Mi")<br>          }<br>        ),<br>      {})<br>    }<br>  )</pre> | `{}` | no |
| <a name="input_replicas"></a> [replicas](#input\_replicas) | The number of pods to run.  Must be greater than or equal to two. | `number` | `2` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->