# Kubernetes Prometheus Stack

## Overview

A Terraform module to deploy and manage the [kube-prometheus-stack Helm chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack).  The module enables the Helm chart's Prometheus, AlertManager, Grafana, Kube State Metrics, and Prometheus Node Exporter sub-charts.  The CRDs included in the chart are managed by Terraform instead of Helm to ensure their entire life-cycles are managed.  The module currently supports major versions 51, 52, 53, 54, and 55 of the Helm chart.

## Resource Import

Due to the use of both the `kubernetes_manifest` resource and the `kubectrl_manifest` resources, importing the resources they manage requires extra effort.  The following shell scripts can be used to eliminate the guess work involved with importing the resources.

### Custom Resource Definition Resource Import

To import the CRD resources, the following shell script can be used.  Prior to running the commands, replace `example` with the actual name of your module.

```shell
#!/bin/bash
terraform import 'module.example.kubectl_manifest.crd["crd-alertmanagerconfigs.yaml"]' 'apiextensions.k8s.io/v1//CustomResourceDefinition//alertmanagerconfigs.monitoring.coreos.com'
terraform import 'module.example.kubectl_manifest.crd["crd-alertmanagers.yaml"]' 'apiextensions.k8s.io/v1//CustomResourceDefinition//alertmanagers.monitoring.coreos.com'
terraform import 'module.example.kubectl_manifest.crd["crd-podmonitors.yaml"]' 'apiextensions.k8s.io/v1//CustomResourceDefinition//podmonitors.monitoring.coreos.com'
terraform import 'module.example.kubectl_manifest.crd["crd-probes.yaml"]' 'apiextensions.k8s.io/v1//CustomResourceDefinition//probes.monitoring.coreos.com'
terraform import 'module.example.kubectl_manifest.crd["crd-prometheuses.yaml"]' 'apiextensions.k8s.io/v1//CustomResourceDefinition//prometheuses.monitoring.coreos.com'
terraform import 'module.example.kubectl_manifest.crd["crd-prometheusrules.yaml"]' 'apiextensions.k8s.io/v1//CustomResourceDefinition//prometheusrules.monitoring.coreos.com'
terraform import 'module.example.kubectl_manifest.crd["crd-servicemonitors.yaml"]' 'apiextensions.k8s.io/v1//CustomResourceDefinition//servicemonitors.monitoring.coreos.com'
terraform import 'module.example.kubectl_manifest.crd["crd-thanosrulers.yaml"]' 'apiextensions.k8s.io/v1//CustomResourceDefinition//thanosrulers.monitoring.coreos.com'
```

### Vault Integration

Static secrets stored in Vault's K/V secrets engine are mounted as volumes in the Alertmanager and Grafana pods.  The volumes are [Secret Store CSI volumes](https://secrets-store-csi-driver.sigs.k8s.io/introduction.html) backed by [the Vault CSI provider](https://developer.hashicorp.com/vault/docs/platform/k8s/csi).  The CSI provider was chosen over the [Agent Injector](https://developer.hashicorp.com/vault/docs/platform/k8s/injector) because the Grafana Helm chart only supports injecting its admin credentials as environment variables.  Unlike the Vault agent, [the CSI driver supports environment variables](https://secrets-store-csi-driver.sigs.k8s.io/topics/set-as-env-var.html) in addition to volume mounts.  The module binds the Alertmanager and Grafana service accounts to the `system:auth-delegator` Kubernetes `ClusterRole`.  This allows their service account tokens to be used as [the JWT reviewer token on the Vault server's Kubernetes auth backend](https://developer.hashicorp.com/vault/docs/auth/kubernetes#kubernetes-1-21).  The module manages the roles and policies in Vault and, therefore, requires the Terraform Vault provider be granted the correct permissions to do so.

## Module Maintenance

### Custom Resource Definitions

The module manages the Prometheus Operator custom resource definitions with Terraform   The Helm release resource is configured to skip CRD installation.  While it is possible to dynamically download the CRD files using [the Terraform `http` provider](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http), the rate limiting on the Github API makes this approach impractical.  Instead, the CRD files are bundled in the module.  The kube-prometheus-stack chart [only updates the CRDs files when the major version changes](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack#upgrading-chart).  For each major version of the Helm chart supported by the module, [there is a subdirectory](files/crds/) whose name corresponds to the Prometheus Operator version supported by the chart.  Each CRD is in its own file in the subdirectory.  When modifying the module to support additional chart versions, create a directory for each Prometheus Operator version supported by the new chart versions and then add the CRD files for that version.  The Helm chart versions are mapped to their supported Prometheus Operator version using a local value named `crd_version_mapping`.  The local value must be modified when adding or removing CRD versions.  The CRDs files can be downloaded from [the Helm chart's Github project](https://github.com/prometheus-community/helm-charts).  The simplest way to download them is to [download the tar.gz file of the corresponding Github release](https://github.com/prometheus-community/helm-charts/releases?q=kube-prometheus-stack-&expanded=true).  When dropping support for chart versions, be sure to remove any CRD versions that are no longer needed as well.

## References

* <https://prometheus-operator.dev/>
* <https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack>
* <https://github.com/grafana/helm-charts/tree/main/charts/grafana>
* <https://grafana.com/docs/grafana/latest/>
* <https://github.com/kiwigrid/k8s-sidecar>

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.11 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 2.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.23 |
| <a name="requirement_vault"></a> [vault](#requirement\_vault) | >= 3.20 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.11 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | >= 2.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.23 |
| <a name="provider_vault"></a> [vault](#provider\_vault) | >= 3.20 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.prometheus_stack](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubectl_manifest.alertmanager_secret_provider](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.crd](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.grafana_secret_provider](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [kubernetes_cluster_role_binding_v1.static_secrets](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding_v1) | resource |
| [kubernetes_namespace_v1.grafana_dashboards](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_resource_quota_v1.grafana_dashboards](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/resource_quota_v1) | resource |
| [kubernetes_role_binding_v1.grafana_dashboards](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_binding_v1) | resource |
| [kubernetes_role_v1.grafana_dashboards](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_v1) | resource |
| [kubernetes_service_account_v1.static_secrets](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account_v1) | resource |
| [vault_identity_entity.static_secrets](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/identity_entity) | resource |
| [vault_identity_entity_alias.static_secrets](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/identity_entity_alias) | resource |
| [vault_kubernetes_auth_backend_role.static_secrets](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/kubernetes_auth_backend_role) | resource |
| [vault_policy.static_secrets](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/policy) | resource |
| [vault_auth_backend.kubernetes](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/data-sources/auth_backend) | data source |
| [vault_policy_document.static_secrets](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/data-sources/policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alertmanager_pod_configuration"></a> [alertmanager\_pod\_configuration](#input\_alertmanager\_pod\_configuration) | An object whose attributes configure the image registry, persistent volume size (in gigabytes), node selector, tolerations, resource requests and resource limits for<br>the Alertmanager pods.  The image is pulled from the registry specified in the `image_registry` attribute.  It must be in the 'prometheus/alertmanager' repository.<br>The value can have an optional path suffix to support the use of ECR pull-through caches. | <pre>object({<br>    image_registry = optional(string, "quay.io")<br>    node_selector  = optional(map(string), {})<br>    node_tolerations = optional(<br>      list(<br>        object(<br>          {<br>            key      = string<br>            operator = string<br>            value    = optional(string)<br>            effect   = string<br>          }<br>        )<br>      ),<br>    [])<br>    resources = optional(<br>      object({<br>        limits = optional(<br>          object({<br>            cpu    = optional(string, "250m")<br>            memory = optional(string, "256Mi")<br>          }),<br>        {})<br>        requests = optional(<br>          object({<br>            cpu    = optional(string, "250m")<br>            memory = optional(string, "256Mi")<br>          }),<br>        {})<br>      }),<br>    {})<br>    volume_size = optional(number, 10)<br>  })</pre> | `{}` | no |
| <a name="input_alertmanager_slack_vault_kv_secret"></a> [alertmanager\_slack\_vault\_kv\_secret](#input\_alertmanager\_slack\_vault\_kv\_secret) | The path to the Vault k/v secret containing the Slack API URL to use for sending alerts. | <pre>object(<br>    {<br>      path              = string<br>      slack_api_url_key = optional(string, "alertmanager_slack_api_url")<br>      slack_channel     = string<br>    }<br>  )</pre> | n/a | yes |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | The version of the kube-prometheus-stack chart to deploy.  It must be one of the 51.x, 52.x, 53.x, 54.x, or 55.x releases. | `string` | n/a | yes |
| <a name="input_cluster_cert_issuer_name"></a> [cluster\_cert\_issuer\_name](#input\_cluster\_cert\_issuer\_name) | The value to use for the'cert-manager.io/cluster-issuer' annotation on every Kubernetes ingress resource. | `string` | `"letsencrypt-prod"` | no |
| <a name="input_grafana_admin_user_vault_kv_secret"></a> [grafana\_admin\_user\_vault\_kv\_secret](#input\_grafana\_admin\_user\_vault\_kv\_secret) | The Vault K/V secret used to construct the VaultSecret Kubernetes resource containing the default Grafana admin account.<br>The default admin account should only be used for emergencies when LDAP authentication is not an option. | <pre>object(<br>    {<br>      path         = string<br>      username_key = optional(string, "ADMIN_USER")<br>      password_key = optional(string, "ADMIN_PASS")<br>    }<br>  )</pre> | n/a | yes |
| <a name="input_grafana_ldap_config_vault_kv_secret"></a> [grafana\_ldap\_config\_vault\_kv\_secret](#input\_grafana\_ldap\_config\_vault\_kv\_secret) | The path to the Vault k/v secret containing the LDAP settings to use for configuring Grafana's authentication settings.<br>For details on the LDAP configuration file see https://grafana.com/docs/grafana/v8.4/auth/ldap/ | <pre>object(<br>    {<br>      path     = string<br>      toml_key = string<br>    }<br>  )</pre> | n/a | yes |
| <a name="input_grafana_pod_configuration"></a> [grafana\_pod\_configuration](#input\_grafana\_pod\_configuration) | An object whose attributes configure the image registry, node selector, tolerations, resource requests and resource limits for the Grafana pods.<br>The image must be in the `grafana/grafana` repository in the specified image registry. | <pre>object({<br>    image_registry = optional(string, "docker.io")<br>    node_selector  = optional(map(string), {})<br>    node_tolerations = optional(<br>      list(<br>        object(<br>          {<br>            key      = string<br>            operator = string<br>            value    = optional(string)<br>            effect   = string<br>          }<br>        )<br>      ),<br>    [])<br>    resources = optional(<br>      object({<br>        limits = optional(<br>          object({<br>            cpu    = optional(string, "500m")<br>            memory = optional(string, "512Mi")<br>          }),<br>        {})<br>        requests = optional(<br>          object({<br>            cpu    = optional(string, "500m")<br>            memory = optional(string, "512Mi")<br>          }),<br>        {})<br>      }),<br>    {})<br>  })</pre> | `{}` | no |
| <a name="input_ingress_class_name"></a> [ingress\_class\_name](#input\_ingress\_class\_name) | The name of the ingress class to use for every Kubernetes ingress resource created by the Helm release. | `string` | `"nginx"` | no |
| <a name="input_kube_base_domain"></a> [kube\_base\_domain](#input\_kube\_base\_domain) | The base domain to use when constructing the hostnames in the module. | `string` | n/a | yes |
| <a name="input_kube_state_metrics_pod_configuration"></a> [kube\_state\_metrics\_pod\_configuration](#input\_kube\_state\_metrics\_pod\_configuration) | An object whose attributes configure the image registry, node selector, tolerations, resource requests and resource limits for the Kube State Metrics pods.<br>The image must be in the `kube-state-metrics/kube-state-metrics repository` in the specified image registry. | <pre>object({<br>    image_registry = optional(string, "registry.k8s.io")<br>    node_selector  = optional(map(string), {})<br>    node_tolerations = optional(<br>      list(<br>        object(<br>          {<br>            key      = string<br>            operator = string<br>            value    = optional(string)<br>            effect   = string<br>          }<br>        )<br>      ),<br>    [])<br>    replica_count = optional(number, 2)<br>    resources = optional(<br>      object({<br>        limits = optional(<br>          object({<br>            cpu    = optional(string, "100m")<br>            memory = optional(string, "256Mi")<br>          }),<br>        {})<br>        requests = optional(<br>          object({<br>            cpu    = optional(string, "100m")<br>            memory = optional(string, "256Mi")<br>          }),<br>        {})<br>      }),<br>    {})<br>  })</pre> | `{}` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | An optional map of kubernetes labels to attach to every resource created by the module. | `map(string)` | `{}` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | The name of the namespace where all module's Kubernetes resources, including the Helm release, are deployed. | `string` | n/a | yes |
| <a name="input_prometheus_operator_pod_configuration"></a> [prometheus\_operator\_pod\_configuration](#input\_prometheus\_operator\_pod\_configuration) | An object whose attributes configure the container image registry, node selector, tolerations, resource requests and resource limits for the Prometheus Operator pods.<br>The prometheus-operator and the prometheus-config-reloader images are pulled from the registry specified in the `image_registry` attribute.  The images must be under the<br>`prometheus-operator/prometheus-operator` repository and the `prometheus-config-reloader` repository, respectively.  The value can have an optional path suffix<br>to support the use of ECR pull-through caches. | <pre>object({<br>    image_registry = optional(string, "quay.io")<br>    node_selector  = optional(map(string), {})<br>    node_tolerations = optional(<br>      list(<br>        object(<br>          {<br>            key      = string<br>            operator = string<br>            value    = optional(string)<br>            effect   = string<br>          }<br>        )<br>      ),<br>    [])<br>    resources = optional(<br>      object({<br>        limits = optional(<br>          object({<br>            cpu    = optional(string, "100m")<br>            memory = optional(string, "256Mi")<br>          }),<br>        {})<br>        requests = optional(<br>          object({<br>            cpu    = optional(string, "100m")<br>            memory = optional(string, "256Mi")<br>          }),<br>        {})<br>      }),<br>    {})<br>  })</pre> | `{}` | no |
| <a name="input_prometheus_pod_configuration"></a> [prometheus\_pod\_configuration](#input\_prometheus\_pod\_configuration) | An object whose attributes configure the image registry, persistent volume size (in gigabytes), node selector, tolerations, resource requests and resource limits for the Prometheus pods.<br>The prometheus and node-exporter images are pulled from the registry specified in the `image_registry` attribute.<br>The images must be in the 'prometheus/prometheus' and 'prometheus/node-exporter' repositories, respectively.<br>The value can have an optional path suffix to support the use of ECR pull-through caches. | <pre>object({<br>    image_registry = optional(string, "quay.io")<br>    node_selector  = optional(map(string), {})<br>    node_tolerations = optional(<br>      list(<br>        object(<br>          {<br>            key      = string<br>            operator = string<br>            value    = optional(string)<br>            effect   = string<br>          }<br>        )<br>      ),<br>    [])<br>    resources = optional(<br>      object({<br>        limits = optional(<br>          object({<br>            cpu    = optional(string, "1")<br>            memory = optional(string, "2Gi")<br>          }),<br>        {})<br>        requests = optional(<br>          object({<br>            cpu    = optional(string, "1")<br>            memory = optional(string, "2Gi")<br>          }),<br>        {})<br>      }),<br>    {})<br>    volume_size = optional(number, 150)<br>  })</pre> | `{}` | no |
| <a name="input_vault_auth_backend_path"></a> [vault\_auth\_backend\_path](#input\_vault\_auth\_backend\_path) | The Vault Kubernetes backend configured for the K8s cluster where the module resources are deployed.  Any Vault roles created by the module will be added to this backend. | `string` | n/a | yes |
| <a name="input_vault_metadata"></a> [vault\_metadata](#input\_vault\_metadata) | A map containing data to add to every Vault resource as metadata. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_dashboard_config"></a> [dashboard\_config](#output\_dashboard\_config) | An object containing the values required for Grafana to load a dashboard from a Kubernetes configmap.  It is intended to be consumed as an argument in other modules. |
| <a name="output_dashboard_folder_annotation_key"></a> [dashboard\_folder\_annotation\_key](#output\_dashboard\_folder\_annotation\_key) | The Kubernetes annotation to add to Grafana dashboard configmaps to specify the folder for the dashboards. |
| <a name="output_dashboard_label"></a> [dashboard\_label](#output\_dashboard\_label) | A map containing the Kubernetes label that must be present on a configmap for its data to be loaded as Granfana dashboard. |
| <a name="output_dashboard_label_key"></a> [dashboard\_label\_key](#output\_dashboard\_label\_key) | The key of the Kubernetes label that must be present on a configmap for its data to be loaded as Granfana dashboard. |
| <a name="output_dashboard_label_value"></a> [dashboard\_label\_value](#output\_dashboard\_label\_value) | The value of the Kubernetes label that must be present on a configmap for its data to be loaded as Granfana dashboard. |
| <a name="output_dashboard_namespace"></a> [dashboard\_namespace](#output\_dashboard\_namespace) | The name of the Kubernetes namespace that Grafana monitors for configmaps containing Grafana dashboard definitions. |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | The name of the Kubernetes namespace where the stack resources are deployed. |
| <a name="output_prometheus_service_url"></a> [prometheus\_service\_url](#output\_prometheus\_service\_url) | The URL of the Prometheus service in the Kubernetes cluster. |
<!-- END_TF_DOCS -->