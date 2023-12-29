# Sealed Secrets Controller

## Overview

Installs the [Bitnami Sealed Secrets controller](https://github.com/bitnami-labs/sealed-secrets) using the official [Helm chart](https://github.com/bitnami-labs/sealed-secrets/tree/main/helm/sealed-secrets).  Sealed secrets are safe to store in public places such as Git repositories.  Once a sealed secret resource is created in a Kubernetes cluster, it is "unsealed" to produce a standard [Kubernetes secret resource](https://kubernetes.io/docs/concepts/configuration/secret/).  Therefore, they are useful for installing Kubernetes secrets through GitOps processes and/or Infrastructure-as-code tooling.  For more details, refer to the [documentation](https://github.com/bitnami-labs/sealed-secrets/blob/main/README.md).

The [sealed-secret](../sealed-secret/) module is a companion to this module.  It is used to create SealedSecret resources.

## Module Maintenance

### Custom Resource Definitions

The module manages the Sealed Secrets custom resource definitions with Terraform   The Helm release resource is configured to skip CRD installation.  While it is possible to dynamically download the CRD files using [the Terraform `http` provider](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http), the rate limiting on the Github API makes this approach impractical.  Instead, the CRD files are bundled in the module.  For each version of the Helm chart supported by the module, [there is a subdirectory](files/crds/) whose name corresponds to the chart version.  The CRDs for the chart version are in the subdirectory with one CRD per file.  When modifying the module to support additional chart versions, create a directory for each new supported version and add the CRD files for that version.  The CRDs files can be downloaded from [the Sealed Secrets Controller's Github project](https://github.com/bitnami-labs/sealed-secrets/tree/main/helm/sealed-secrets/crds).  When dropping support for a chart version, remove its CRD directory.

## References

* [Sealed Secrets documentation](https://github.com/bitnami-labs/sealed-secrets/blob/main/README.md)
* [Sealed Secrets release notes](https://github.com/bitnami-labs/sealed-secrets/blob/main/RELEASE-NOTES.md)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.11.0 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | ~> 2.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.23.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.11.0 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | ~> 2.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.23.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.sealed_secrets](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubectl_manifest.alerts](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.crd](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [kubernetes_cluster_role.sealed_secret_edit](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role) | resource |
| [kubernetes_cluster_role.sealed_secret_view](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | The version of the 'sealed-secrets' Helm chart to use.  Support versions are 2.13.x.  See https://github.com/bitnami-labs/sealed-secrets/releases for the list of valid versions. | `string` | n/a | yes |
| <a name="input_enable_prometheus_rules"></a> [enable\_prometheus\_rules](#input\_enable\_prometheus\_rules) | Set to true to deploy a PrometheusRule resource to generate alerts based on the metrics scraped by Prometheus. | `bool` | `true` | no |
| <a name="input_grafana_dashboard_config"></a> [grafana\_dashboard\_config](#input\_grafana\_dashboard\_config) | Configures the optional deployment of Grafana dashboards in configmaps.  Set the value to null to disable dashboard installation.  The dashboards will be added to the "General" folder in the Grafana UI.<br><br>The 'folder\_annotation\_key' attribute is the Kubernets annotation that configures the Grafana folder into which the dasboards will appear in the Grafana UI.  It cannot be null or empty.<br>The 'label' attribute is a single element map containing the label the Grafana sidecar uses to discover configmaps containing dashboards.  It cannot be null or empty.<br>The 'namespace' attribute is the namespace where the configmaps are deployed.  It cannot be null or empty.<br><br>* https://github.com/grafana/helm-charts/tree/main/charts/grafana#sidecar-for-dashboards | <pre>object(<br>    {<br>      folder_annotation_key = string<br>      label                 = map(string)<br>      namespace             = string<br>    }<br>  )</pre> | `null` | no |
| <a name="input_image_registry"></a> [image\_registry](#input\_image\_registry) | The hostname of the image registry (or registry proxy) containing the controller's image.  The image must be in the 'bitnami/sealed-secrets-controller' repository. | `string` | `"docker.io"` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | An optional map of kubernetes labels to attach to every resource created by the module. | `map(string)` | `{}` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | The namespace where the controller will be installed.  It must already exist. | `string` | `"kube-system"` | no |
| <a name="input_node_selector"></a> [node\_selector](#input\_node\_selector) | An optional map of Kubernetes labels to use as the controller pod's node selectors. | `map(string)` | `{}` | no |
| <a name="input_node_tolerations"></a> [node\_tolerations](#input\_node\_tolerations) | An optional list of objects to set node tolerations on the controller pod.  The object structure corresponds to the structure of the<br>toleration syntax in the Kubernetes pod spec.<br><br>https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/ | <pre>list(object(<br>    {<br>      key      = string<br>      operator = string<br>      value    = optional(string)<br>      effect   = string<br>    }<br>  ))</pre> | `[]` | no |
| <a name="input_pod_resources"></a> [pod\_resources](#input\_pod\_resources) | CPU and memory settings for the controller pods.  Defaults to the same values as the Helm chart's default values. | <pre>object(<br>    {<br>      limits = optional(<br>        object(<br>          {<br>            cpu    = optional(string, "100m")<br>            memory = optional(string, "128Mi")<br>          }<br>        ),<br>      {})<br>      requests = optional(<br>        object(<br>          {<br>            cpu    = optional(string, "50m")<br>            memory = optional(string, "64Mi")<br>          }<br>        ),<br>      {})<br>    }<br>  )</pre> | `{}` | no |
| <a name="input_release_name"></a> [release\_name](#input\_release\_name) | The name to give to the Helm release. | `string` | `"sealed-secrets-controller"` | no |
| <a name="input_service_monitor"></a> [service\_monitor](#input\_service\_monitor) | Controls deployment and configuration of a ServiceMonitor custom resource to enable Prometheus metrics scraping.  The kube-prometheus-stack CRDs must be available in the k8s cluster if  `enabled` is set to `true`. | <pre>object({<br>    enabled         = optional(bool, true)<br>    scrape_interval = optional(string, "30s")<br>  })</pre> | `{}` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->