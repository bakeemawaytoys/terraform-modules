# Velero

## Overview

Installs and configures Velero 1.11/1.12 using [the official Helm chart](https://github.com/vmware-tanzu/helm-charts/tree/main/charts/velero).  Velero is configured to store backups in an S3 bucket that is also created by this module.  Persistent volume snapshots are disabled.

## Module Maintenance

### Custom Resource Definitions

[A known limitation of Helm 3 is that it doesn't support the full lifecycle of Kubernetes custom resource definitions](https://helm.sh/docs/chart_best_practices/custom_resource_definitions/).  It can install them but does not update or remove them.  The Velero chart implements Helm hooks to work around this limitation.  While the hooks work most of the time, [they contain gotchas](https://github.com/vmware-tanzu/helm-charts/issues/421) and are [limited to running on x86 architectures](https://github.com/vmware-tanzu/helm-charts/issues/339).  To side step these issues, module manages the CRDs with Terraform   The Helm release resources is configured to skip CRD installation and the chart values that control execution of the hooks are configured to disabled the hooks.  While it is possible to dynamically download the CRD files using [the Terraform `http` provider](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http), the rate limiting on the Github API makes this approach impractical.  Instead, the CRD files are bundled in the module.  For each version of the Helm chart supported by the module, [there is a subdirectory](files/crds/) whose name corresponds to the chart version.  The CRDs for the chart version are in the subdirectory with one CRD per file.  When modifying the module to support additional chart versions, create a directory for each new supported version and add the CRD files for that version.  The CRDs files can be downloaded from the Helm chart's Github project.  The simplest way to download them is to [download the tar.gz file of the corresponding Github release](https://github.com/vmware-tanzu/helm-charts/releases).  When dropping support for a chart version, remove its CRD directory.

## References

* <https://velero.io/docs/v1.12/customize-installation/>
* <https://github.com/vmware-tanzu/helm-charts/tree/main/charts/velero>
* <https://github.com/vmware-tanzu/velero-plugin-for-aws>

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.10 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 2.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.23 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.10 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | >= 2.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.23 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_role.service_account](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.service_accounts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_s3_bucket.velero](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_analytics_configuration.velero](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_analytics_configuration) | resource |
| [aws_s3_bucket_lifecycle_configuration.velero](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_logging.velero](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_metric.velero](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_metric) | resource |
| [aws_s3_bucket_ownership_controls.velero](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.velero](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.velero](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.velero](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.velero](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [helm_release.velero](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubectl_manifest.crd](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [kubernetes_cluster_role.admin](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role) | resource |
| [kubernetes_cluster_role.viewer](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role) | resource |
| [kubernetes_config_map_v1.grafana_dashboard](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map_v1) | resource |
| [kubernetes_namespace_v1.velero](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.service_account](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.trust_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_logging"></a> [access\_logging](#input\_access\_logging) | An object whose attributes configures the generation and destination of the S3 access logs.<br><br>The `enabled` attribute determines if access logs are generated for this bucket.  Defaults to false.<br>The `bucket` attribute is the name of the S3 bucket where the access logs will be written.  It cannot be empty if `enabled` is set to true.<br>The `prefix` attribute configures a a string to prepend to the key of every access log object created.  It is optional. | <pre>object({<br>    enabled = optional(bool, false)<br>    bucket  = optional(string)<br>    prefix  = optional(string, "")<br>  })</pre> | `{}` | no |
| <a name="input_aws_plugin_version"></a> [aws\_plugin\_version](#input\_aws\_plugin\_version) | The version of Velero's AWS plugin to use.  Restricted to the version 1.7.x for Velero 1.11.x and version 1.8 for Velero 1.12.<br>Valid values are listed at https://github.com/vmware-tanzu/velero-plugin-for-aws/releases. | `string` | `"1.7.1"` | no |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | The version of the 'velero' Helm chart to use.  Restricted to the versions 4.4.x for Velero 1.11.x and 5.1.x for Velero 1.12.<br>See https://github.com/vmware-tanzu/helm-charts for the list of valid versions. | `string` | n/a | yes |
| <a name="input_create_namespace"></a> [create\_namespace](#input\_create\_namespace) | Set to true to have the module create the namespace.  Set to false if it already exists. | `bool` | n/a | yes |
| <a name="input_custom_bucket_name"></a> [custom\_bucket\_name](#input\_custom\_bucket\_name) | Optionally use a custom bucket name instead of the generated bucket name. | `string` | `""` | no |
| <a name="input_eks_cluster"></a> [eks\_cluster](#input\_eks\_cluster) | Attributes of the EKS cluster on which the controller is deployed.  The names of the attributes match the names of outputs in the eks-cluster module to allow using the module as the argument to this variable.<br><br>The `cluster_name` attribute the the name of the EKS cluster.  It is required.<br>The `service_account_oidc_audience_variable` attribute is the ID of the cluster's IAM OIDC identity provider with the string ":aud" appended to it.  It is required.<br>The `service_account_oidc_subject_variable` attribute is the ID of the cluster's IAM OIDC identity provider with the string ":sub" appended to it.  It is required.<br>The 'service\_account\_oidc\_provider\_arn' attribute is the ARN of the cluster's IAM OIDC identity provider.  It is required. | <pre>object({<br>    cluster_name                           = string<br>    service_account_oidc_audience_variable = string<br>    service_account_oidc_subject_variable  = string<br>    service_account_oidc_provider_arn      = string<br>  })</pre> | n/a | yes |
| <a name="input_enable_goldilocks"></a> [enable\_goldilocks](#input\_enable\_goldilocks) | Determines if Goldilocks monitors the namespace to give recommendations on tuning pod resource requests and limits.<br>https://goldilocks.docs.fairwinds.com/installation/#enable-namespace | `bool` | `true` | no |
| <a name="input_enable_prometheus_rules"></a> [enable\_prometheus\_rules](#input\_enable\_prometheus\_rules) | Set to true to deploy a PrometheusRule resource to generate alerts based on the metrics scraped by Prometheus. | `bool` | `true` | no |
| <a name="input_enable_service_monitor"></a> [enable\_service\_monitor](#input\_enable\_service\_monitor) | Controls installation of a ServiceMonitor resource to enable metrics scraping when the Prometheus Operator is installed in the cluster. | `bool` | `true` | no |
| <a name="input_grafana_dashboard_config"></a> [grafana\_dashboard\_config](#input\_grafana\_dashboard\_config) | Configures the optional deployment of Grafana dashboards in configmaps.  Set the value to null to disable dashboard installation.  The dashboards will be added to the "Cert-Manager" folder in the Grafana UI.<br><br>The 'folder\_annotation\_key' attribute is the Kubernets annotation that configures the Grafana folder into which the dasboards will appear in the Grafana UI.  It cannot be null or empty.<br>The 'label' attribute is a single element map containing the label the Grafana sidecar uses to discover configmaps containing dashboards.  It cannot be null or empty.<br>The 'namespace' attribute is the namespace where the configmaps are deployed.  It cannot be null or empty.<br><br>* https://github.com/grafana/helm-charts/tree/main/charts/grafana#sidecar-for-dashboards | <pre>object(<br>    {<br>      folder_annotation_key = string<br>      label                 = map(string)<br>      namespace             = string<br>    }<br>  )</pre> | `null` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | An optional map of kubernetes labels to attach to every resource created by the module. | `map(string)` | `{}` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Configures the log verbosity.  Must be one of panic, debug, info, warning, error, or fatal. | `string` | `"info"` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | The namespace where Velero's resources, including its Helm chart, will be installed. | `string` | `"velero"` | no |
| <a name="input_node_selector"></a> [node\_selector](#input\_node\_selector) | An optional map of node labels to use the node selector of the Velero pods. | `map(string)` | `{}` | no |
| <a name="input_node_tolerations"></a> [node\_tolerations](#input\_node\_tolerations) | An optional list of objects to set node tolerations on the Velero pods.  The object structure corresponds to the structure of the<br>toleration syntax in the Kubernetes pod spec.<br><br>https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/ | <pre>list(object(<br>    {<br>      key      = string<br>      operator = string<br>      value    = optional(string)<br>      effect   = string<br>    }<br>  ))</pre> | `[]` | no |
| <a name="input_pod_resources"></a> [pod\_resources](#input\_pod\_resources) | CPU and memory settings for the controller pods.  The default values match the default values of the Helm chart | <pre>object(<br>    {<br>      limits = optional(<br>        object(<br>          {<br>            cpu    = optional(string, "1000m")<br>            memory = optional(string, "512Mi")<br>          }<br>        ),<br>      {})<br>      requests = optional(<br>        object(<br>          {<br>            cpu    = optional(string, "500m")<br>            memory = optional(string, "128Mi")<br>          }<br>        ),<br>      {})<br>    }<br>  )</pre> | `{}` | no |
| <a name="input_pod_security_standards"></a> [pod\_security\_standards](#input\_pod\_security\_standards) | Configures the levels of the pod security admission modes.  Defaults to enforcing the restricted standard.<br><br>https://kubernetes.io/docs/concepts/security/pod-security-admission/<br>https://kubernetes.io/docs/tasks/configure-pod-container/enforce-standards-namespace-labels/<br>https://kubernetes.io/docs/concepts/security/pod-security-standards/ | <pre>object({<br>    audit   = optional(string, "restricted")<br>    enforce = optional(string, "restricted")<br>    warn    = optional(string, "restricted")<br>  })</pre> | `{}` | no |
| <a name="input_release_name"></a> [release\_name](#input\_release\_name) | The name to give to the Helm release. | `string` | `"velero"` | no |
| <a name="input_schedules"></a> [schedules](#input\_schedules) | An optional collection of backup schedules that will be managed by Helm.  Only a subset of the template<br>attributes are allowed to be set to ensure valid schedule objects are created.<br>For more details on the template attributes see https://velero.io/docs/v1.9/api-types/backup/. | <pre>map(<br>    object(<br>      {<br>        annotations = optional(map(string), {})<br>        disabled    = optional(bool, false)<br>        labels      = optional(map(string), {})<br>        schedule    = optional(string, "00 11 * * *")<br>        template = optional(<br>          object(<br>            {<br>              includedNamespaces      = optional(list(string), ["*"])<br>              excludedNamespaces      = optional(list(string), [])<br>              includedResources       = optional(list(string), ["*"])<br>              excludedResources       = optional(list(string), [])<br>              includeClusterResources = optional(bool)<br>            }<br>          ),<br>        {})<br>        useOwnerReferencesInBackup = optional(bool, false)<br>      }<br>    )<br>  )</pre> | <pre>{<br>  "default-scheduled-backup": {<br>    "template": {<br>      "excludedNamespaces": [<br>        "default",<br>        "kube-system",<br>        "kube-public",<br>        "kube-node-lease",<br>        "velero"<br>      ],<br>      "excludedResources": [<br>        "storageclasses.storage.k8s.io"<br>      ],<br>      "includedNamespaces": [<br>        "*"<br>      ]<br>    }<br>  }<br>}</pre> | no |
| <a name="input_service_account_name"></a> [service\_account\_name](#input\_service\_account\_name) | The name to give to the k8s service account created for Velero. | `string` | `"velero"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | An optional map of AWS tags to attach to every resource created by the module. | `map(string)` | `{}` | no |
| <a name="input_velero_image_registry"></a> [velero\_image\_registry](#input\_velero\_image\_registry) | The container image registry from which the velero and velero-plugin-for-aws images will be pulled.  The images must be in the velero/velero and velero/velero-plugin-for-aws repositories, respectively.<br>The value can have an optional path suffix to support the use of ECR pull-through caches. | `string` | `"docker.io"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bucket_arn"></a> [bucket\_arn](#output\_bucket\_arn) | The ARN of the S3 bucket where Velero stsores its back up files. |
| <a name="output_bucket_name"></a> [bucket\_name](#output\_bucket\_name) | The name of the S3 bucket where Velero stores its backup files. |
| <a name="output_service_account_role_arn"></a> [service\_account\_role\_arn](#output\_service\_account\_role\_arn) | The ARN of the IAM role created for Velero's k8s service account. |
| <a name="output_service_account_role_name"></a> [service\_account\_role\_name](#output\_service\_account\_role\_name) | The name of the IAM role created for Velero's k8s service account. |
| <a name="output_storage_location_name"></a> [storage\_location\_name](#output\_storage\_location\_name) | The name of the BackupStorageLocation Kubernetes resource corresponding to the S3 bucket managed by this module. |
<!-- END_TF_DOCS -->