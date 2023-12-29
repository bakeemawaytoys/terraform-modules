# Kubernetes Hashicorp Vault Clients

## Overview

A Terraform module to install and manage the Hashicorp [Vault Agent Sidecar Injector](https://developer.hashicorp.com/vault/docs/platform/k8s/injector) and [Vault CSI Provider](https://developer.hashicorp.com/vault/docs/platform/k8s/csi) in a Kubernetes cluster.  They are both installed using [the official Helm chart](https://github.com/hashicorp/vault-helm) provided by Hashicorp.  The Kubernetes [Secret Store CSI driver](https://secrets-store-csi-driver.sigs.k8s.io/) is also installed by the module as it is a prerequisite of the CSI provider.  It, too, is installed using [an official Helm chart](https://github.com/kubernetes-sigs/secrets-store-csi-driver/tree/main/charts/secrets-store-csi-driver).

## Supported Versions

| Component | Versions |
| --- | --- |
| Vault Agent | 1.14.x, 1.15.x |
| Vault Helm Chart | 0.25.x, 0.26.x |
| Secret Store CSI Driver Helm Chart | 1.3.4 |

## Vault Integration

The module creates a [Kubernetes authentication backend](https://developer.hashicorp.com/vault/docs/auth/kubernetes) on the Vault server and configures it for the cluster onto which the Helm release is applied.  Terraform's Vault credentials must have permission to mount an authentication backend with the name supplied to the module with the `auth_backend` variable as well as permission to tune the backend.

At this time, the module only supports [the use of a short-lived client token as JWT reviewer token](https://developer.hashicorp.com/vault/docs/auth/kubernetes#kubernetes-1-21)  [This means **all Kubernetes workloads authenticating with Vault must use a service account bound to the `system:auth-delegator` cluster role**](https://developer.hashicorp.com/vault/docs/auth/kubernetes#use-the-vault-client-s-jwt-as-the-reviewer-jwt).

## Module Maintenance

### Custom Resource Definitions

Unlike many Helm charts, the secrets-store-csi-driver chart does include hooks to create and update its CRDs.  The module, however, uses Terraform to manage them directly.  The chart hooks that create and update the CRDs have been disabled.  While it is possible to dynamically download the CRD files using [the Terraform `http` provider](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http), the rate limiting on the Github API makes this approach impractical.  Instead, the CRD files are bundled in the module.  For each version of the Helm chart supported by the module, [there is a subdirectory](files/crds/) whose name corresponds to the chart version.  The CRDs for the chart version are in the subdirectory with one CRD per file.  When modifying the module to support additional chart versions, create a directory for each new supported version and add the CRD files for that version.  The CRDs files can be downloaded from [the secrets-store-csi-driver's Github project releases](https://github.com/kubernetes-sigs/secrets-store-csi-driver/releases).  When dropping support for a chart version, remove its CRD directory.

## References

* <https://secrets-store-csi-driver.sigs.k8s.io/>
* <https://github.com/kubernetes-sigs/secrets-store-csi-driver>
* <https://developer.hashicorp.com/vault/docs/platform/k8s>

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.10 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 2.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.23 |
| <a name="requirement_vault"></a> [vault](#requirement\_vault) | >= 3.20 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.10 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | >= 2.0 |
| <a name="provider_vault"></a> [vault](#provider\_vault) | >= 3.20 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.secrets_store_csi](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.vault](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubectl_manifest.crd](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [vault_auth_backend.kubernetes](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/auth_backend) | resource |
| [vault_kubernetes_auth_backend_config.kubernetes](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/kubernetes_auth_backend_config) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_agent_default_configuration"></a> [agent\_default\_configuration](#input\_agent\_default\_configuration) | The default settings for the injected Vault agent containers.  The defaults match the default values in the Helm chart."<br>For details on the template\_config settings, see https://developer.hashicorp.com/vault/docs/agent-and-proxy/agent/template?page=agent&page=template<br>The vault\_version attibute is optional and can be used to override the Helm chart's default version of Vault used in the agent container. | <pre>object(<br>    {<br>      resources = optional(<br>        object({<br>          limits = optional(<br>            object({<br>              cpu               = optional(string, "500m")<br>              ephemeral_storage = optional(string, "512Mi")<br>              memory            = optional(string, "128Mi")<br>            }),<br>          {})<br>          requests = optional(<br>            object({<br>              cpu               = optional(string, "250m")<br>              ephemeral_storage = optional(string, "256Mi")<br>              memory            = optional(string, "64Mi")<br>            }),<br>          {})<br>        }),<br>      {})<br>      template_type = optional(string, "map")<br>      template_config = optional(object({<br>        exit_on_retry_failure         = optional(bool, true)<br>        static_secret_render_interval = optional(string, "5m")<br>      }), {})<br>      vault_version = optional(string)<br>    }<br>  )</pre> | `{}` | no |
| <a name="input_agent_injector_configuration"></a> [agent\_injector\_configuration](#input\_agent\_injector\_configuration) | Settings for the agent injector controller workload.  The default resoures match the default values in the Helm chart. | <pre>object(<br>    {<br>      node_selector = optional(map(string), {})<br>      replicas      = optional(number, 2)<br>      resources = optional(<br>        object({<br>          limits = optional(<br>            object({<br>              cpu    = optional(string, "250m")<br>              memory = optional(string, "256Mi")<br>            }),<br>          {})<br>          requests = optional(<br>            object({<br>              cpu    = optional(string, "250m")<br>              memory = optional(string, "256Mi")<br>            }),<br>          {})<br>        }),<br>      {})<br>    }<br>  )</pre> | `{}` | no |
| <a name="input_auth_backend"></a> [auth\_backend](#input\_auth\_backend) | Settings to configure the Vault Kubernetes authentication backend managed by the module. | <pre>object({<br>    metadata = optional(map(string), {})<br>    path     = optional(string, "kubernetes")<br>  })</pre> | `{}` | no |
| <a name="input_image_registry"></a> [image\_registry](#input\_image\_registry) | The container image registry from which the hashicorp images will be pulled.<br>The images must be in the 'hashicorp/vault', 'hashicorp/vault-k8s', and 'hashicorp/vault-csi-provider' repositories.<br>The value can have an optional path suffix to support the use of ECR pull-through caches. | `string` | `"public.ecr.aws"` | no |
| <a name="input_kubernetes_cluster"></a> [kubernetes\_cluster](#input\_kubernetes\_cluster) | An object containing attributes of the EKS cluster that are required for configuring Vault's Kubernetes authentication backend.<br><br>The certificate\_authority\_pem attribute is the cluster endpoint's certificate authority's root certificate encoded in PEM format.<br>The cluster\_endpoint attribute is the URL of the cluster's Kubernetes API.<br>The cluster\_name attribute is the name of the cluster in EKS. | <pre>object({<br>    certificate_authority_pem = string<br>    cluster_endpoint          = string<br>    cluster_name              = string<br>  })</pre> | n/a | yes |
| <a name="input_labels"></a> [labels](#input\_labels) | An optional map of kubernetes labels to attach to every resource created by the module. | `map(string)` | `{}` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | The name of the namespace where all module's Kubernetes resources, including the Helm releases, are deployed. | `string` | n/a | yes |
| <a name="input_secrets_store_csi_driver_chart_version"></a> [secrets\_store\_csi\_driver\_chart\_version](#input\_secrets\_store\_csi\_driver\_chart\_version) | The version of the Vault Helm chart to deploy.  Valid versions are listed at https://github.com/kubernetes-sigs/secrets-store-csi-driver/releases. | `string` | `"1.3.4"` | no |
| <a name="input_vault_chart_version"></a> [vault\_chart\_version](#input\_vault\_chart\_version) | The version of the Vault Helm chart to deploy.  Valid versions are listed at https://github.com/hashicorp/vault-helm/releases. | `string` | `"0.26.1"` | no |
| <a name="input_vault_csi_provider_configuration"></a> [vault\_csi\_provider\_configuration](#input\_vault\_csi\_provider\_configuration) | Settings for the Vault CSI provider daemonset.  The defaults match the default values in the Helm chart. | <pre>object(<br>    {<br>      resources = optional(<br>        object({<br>          limits = optional(<br>            object({<br>              cpu    = optional(string, "50m")<br>              memory = optional(string, "128Mi")<br>            }),<br>          {})<br>          requests = optional(<br>            object({<br>              cpu    = optional(string, "50m")<br>              memory = optional(string, "128Mi")<br>            }),<br>          {})<br>        }),<br>      {})<br>    }<br>  )</pre> | `{}` | no |
| <a name="input_vault_server_address"></a> [vault\_server\_address](#input\_vault\_server\_address) | The URL of the Vault server. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_vault_auth_backend"></a> [vault\_auth\_backend](#output\_vault\_auth\_backend) | An object containing the attributes of the Kubernetes auth backend.  See https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/auth_backend for the available attributes. |
| <a name="output_vault_auth_backend_accessor"></a> [vault\_auth\_backend\_accessor](#output\_vault\_auth\_backend\_accessor) | The accessor of the Vault Kubernetes backed managed by this module. |
| <a name="output_vault_auth_backend_full_path"></a> [vault\_auth\_backend\_full\_path](#output\_vault\_auth\_backend\_full\_path) | The full path (including the auth/ prefix) to the Vault Kubernetes auth backend managed by this module. |
| <a name="output_vault_auth_backend_path"></a> [vault\_auth\_backend\_path](#output\_vault\_auth\_backend\_path) | The path of the Vault Kubernetes auth backend managed by this module. |
<!-- END_TF_DOCS -->