# Kubernetes Cert Manager

## Overview

Deploys the Kubernetes [cert-manager](https://github.com/cert-manager/cert-manager) controller using the Helm chart provided by Jetstack.  The controller is preconfigured to use Route53 for resolving DNS01 challenges.  The module creates an IAM role for the controller to assume using [IAM roles for service accounts](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html).  The supported cert-manager versions are 1.12.6 and 1.13.2.

## Usage

The following example is for the simple use case, where cert-manager is permitted to validate certificates for any domain name in the Route53 zone.

```hcl
module "cert_manager" {
  source = "cert-manager"

  acme_dns01_route53_solvers = {
    "example.com" = {}
  }
  chart_version                     = "v1.13.2"
  cluster_name                      = "example-cluster"
  namespace                         = "cert-manager"
  service_account_oidc_provider_arn = "arn:aws:iam::111111111:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/ABC123..."
}
```

The following example is for a more elaborate use case, where cert-manager is permitted to validate certificates for select names in the Route53 zone.   In this configuration, it is allowed to validate `www.example.com` or any name within the `services.example.com` and `prod.kube.example.com` zones.  Validation of any other name would fail because IAM will prevent the creation of the TXT validation record in Route53.

```hcl
module "cert_manager" {
  source = "cert-manager"

  acme_dns01_route53_solvers = {
    "example.com" = {
        dns_names = ["www"]
        dns_zones = ["services", "prod.kube"]
    }
  }
  chart_version                     = "v1.13.2"
  cluster_name                      = "example-cluster"
  namespace                         = "cert-manager"
  service_account_oidc_provider_arn = "arn:aws:iam::111111111:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/ABC123..."
}
```

## Custom Resource Definitions

Unlike many Helm charts, the cert-manager does include hooks to create and update its CRDs.  The module, however, uses Terraform to manage them directly.  The chart hooks that create and update the CRDs have been disabled.  While it is possible to dynamically download the CRD file using [the Terraform `http` provider](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http), the rate limiting on the Github API makes this approach impractical.  Instead, the CRD files are bundled in the module.  For each version of the Helm chart supported by the module, [there is a subdirectory](files/crds/) whose name corresponds to the chart version.  The file contining the CRDs for the chart version are in the subdirectory..  When modifying the module to support additional chart versions, create a directory for each new supported version and add the CRDs file for that version.  The CRDs file can be downloaded from [the Karpenter Github project releases](https://github.com/cert-manager/cert-manager/releases).  The file is named `cert-manager.crds.yaml`.  When dropping support for a chart version, remove its CRD directory.

### Importing CRDs

If it is necessary to import the CRD resources into the Terraform state, the following script can be used by replacing `example` with the actual name of your module.

```shell
#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

terraform import 'module.example.kubectl_manifest.crd["/apis/apiextensions.k8s.io/v1/customresourcedefinitions/certificaterequests.cert-manager.io"]' apiextensions.k8s.io/v1//CustomResourceDefinition//certificaterequests.cert-manager.io
terraform import 'module.example.kubectl_manifest.crd["/apis/apiextensions.k8s.io/v1/customresourcedefinitions/certificates.cert-manager.io"]' apiextensions.k8s.io/v1//CustomResourceDefinition//certificates.cert-manager.io
terraform import 'module.example.kubectl_manifest.crd["/apis/apiextensions.k8s.io/v1/customresourcedefinitions/challenges.acme.cert-manager.io"]' apiextensions.k8s.io/v1//CustomResourceDefinition//challenges.acme.cert-manager.io
terraform import 'module.example.kubectl_manifest.crd["/apis/apiextensions.k8s.io/v1/customresourcedefinitions/clusterissuers.cert-manager.io"]' apiextensions.k8s.io/v1//CustomResourceDefinition//clusterissuers.cert-manager.io
terraform import 'module.example.kubectl_manifest.crd["/apis/apiextensions.k8s.io/v1/customresourcedefinitions/issuers.cert-manager.io"]' apiextensions.k8s.io/v1//CustomResourceDefinition//issuers.cert-manager.io
terraform import 'module.example.kubectl_manifest.crd["/apis/apiextensions.k8s.io/v1/customresourcedefinitions/orders.acme.cert-manager.io"]' apiextensions.k8s.io/v1//CustomResourceDefinition//orders.acme.cert-manager.io

```

The module sets the `installCRDs` value on the Helm release to `false`.  If the CRD resources are currently managed with a Helm release, then the CRD resources will be deleted when the module is applied for the first time.  To prevent this from happening, the `"helm.sh/resource-policy" = "keep"` annotations can be added to the CRDs using the `kubernetes_annotations` resource.  The annotations must be applied **prior to applying the module**.  In other words, `terraform apply` must be run twice to import the CRDs into the Terraform state without data loss.  Once the module has been applied, the `kuberenetes_annotations` resource can be removed.

```hcl
resource "kubernetes_annotations" "cert_manager_crd" {
  for_each = toset([
    "certificaterequests.cert-manager.io",
    "certificates.cert-manager.io",
    "challenges.acme.cert-manager.io",
    "clusterissuers.cert-manager.io",
    "issuers.cert-manager.io",
    "orders.acme.cert-manager.io",
  ])
  api_version = "apiextensions.k8s.io/v1"
  kind        = "CustomResourceDefinition"
  metadata {
    name = each.key
  }
  annotations = {
    "helm.sh/resource-policy"        = "keep"
    "meta.helm.sh/release-name"      = "cert-manager"
    "meta.helm.sh/release-namespace" = "cert-manager"
  }
  force = true
}
```

## Limitations

* [The CA injector is restricted to injecting CA certs into cert-manager components](https://cert-manager.io/docs/release-notes/release-notes-1.12/#cainjector).
* The `serviceType` setting on [ACME HTTP01 challenge solvers](https://cert-manager.io/v1.10-docs/reference/api-docs/#acme.cert-manager.io/v1.ACMEChallengeSolverHTTP01) must be set to `ClusterIP` if the solver pod is configured to run in a namespace managed by the [gitlab-application-k8s-namespace](../gitlab-application-k8s-namespace/) module.  By default, the K8s service created for the pod is of type `NodePort`.  The namespace module contains a K8s quota resource that does not allow any `NodePort` services.  As a result, the service will never be created and the certificate(s) will never be validated.   EKS clusters that use the VPC-CNI driver, `ClusterIP` works correctly because every pod has its own VPC IP address.

## References

* <https://artifacthub.io/packages/helm/cert-manager/cert-manager>
* <https://cert-manager.io/docs/>
* <https://cert-manager.io/docs/configuration/acme/>
* <https://cert-manager.io/docs/configuration/acme/dns01/route53/>

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6 |
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
| [aws_iam_role_policy.service_account](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [helm_release.cert_manager](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubectl_manifest.alerts](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.crd](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [kubernetes_config_map_v1.grafana_dashboard](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map_v1) | resource |
| [kubernetes_namespace_v1.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [aws_iam_policy_document.service_account](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.trust_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_route53_zone.zones](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |
| [kubectl_file_documents.crd](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/data-sources/file_documents) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_acme_dns01_route53_solvers"></a> [acme\_dns01\_route53\_solvers](#input\_acme\_dns01\_route53\_solvers) | A map whose keys are the names of the public Route53 public zones cert-manager can use for ACME DNS01 challenges  The objects in the map are<br>the partially qualified domain names inside the Route53 zone that are allowed to be used for DNS01 challenges.  The values are used to construct<br>the IAM policy attached to cert-manager's role.<br><br>The `dns_names`attribute defines a list of DNS names that must match exactly to be used with DNS01 challenges.  The `dns_zones` attribue define<br>a list of subdomains under which any domain name can be used with DNS01 challenges.  The values in both attributes must be relative to the<br>Route53 zone's name.  The attributes are analogus to the DNS name selctors in cert-manager's issuer resources.<br><br>The if neither the `dns_names`nor the `dns_zones` attributes contain any values, then any name in the Route53 zone, including the apex is permitted.<br><br>See also: https://cert-manager.io/docs/reference/api-docs/#acme.cert-manager.io/v1.CertificateDNSNameSelector | <pre>map(<br>    object({<br>      dns_names = optional(list(string), [])<br>      dns_zones = optional(list(string), [])<br>    })<br>  )</pre> | n/a | yes |
| <a name="input_ca_injector_pod_configuration"></a> [ca\_injector\_pod\_configuration](#input\_ca\_injector\_pod\_configuration) | Specifies the replica count, resource requests, and resource limits of the CA injector pods. | <pre>object(<br>    {<br>      node_selector = optional(map(string), {})<br>      replicas      = optional(number, 2)<br>      resources = optional(<br>        object({<br>          limits = optional(<br>            object({<br>              cpu    = optional(string, "100m")<br>              memory = optional(string, "256Mi")<br>            }),<br>          {})<br>          requests = optional(<br>            object({<br>              cpu    = optional(string, "50m")<br>              memory = optional(string, "128Mi")<br>            }),<br>          {})<br>        }),<br>      {})<br>    }<br>  )</pre> | `{}` | no |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | The version of the Helm chart to install.  The supported versions are v1.12.6 and v1.13.2. | `string` | n/a | yes |
| <a name="input_cluster_resource_namespace"></a> [cluster\_resource\_namespace](#input\_cluster\_resource\_namespace) | The Kubernetes namespace in which cert-manager will create the TLS secrets for certificates issued by ClusterIssuer resources.<br>Defaults to the value of the `namespace` variable.<br>See https://cert-manager.io/docs/configuration/#cluster-resource-namespace for more details. | `string` | `null` | no |
| <a name="input_controller_pod_configuration"></a> [controller\_pod\_configuration](#input\_controller\_pod\_configuration) | Specifies the replica count, resource requests, and resource limits of the controller pods. | <pre>object(<br>    {<br>      node_selector = optional(map(string), {})<br>      replicas      = optional(number, 2)<br>      resources = optional(<br>        object({<br>          limits = optional(<br>            object({<br>              cpu    = optional(string, "100m")<br>              memory = optional(string, "512Mi")<br>            }),<br>          {})<br>          requests = optional(<br>            object({<br>              cpu    = optional(string, "50m")<br>              memory = optional(string, "256Mi")<br>            }),<br>          {})<br>        }),<br>      {})<br>    }<br>  )</pre> | `{}` | no |
| <a name="input_default_ingress_issuer"></a> [default\_ingress\_issuer](#input\_default\_ingress\_issuer) | An optional object for configuring the default issuer to use if an ingress does not specify one.<br>The values are used to set the `--default-issuer-group`, `--default-issuer-kind`, and CLI arguments on the controller.<br>For more details see https://cert-manager.io/docs/cli/controller/ | <pre>object({<br>    group = optional(string, "cert-manager.io")<br>    kind  = optional(string, "ClusterIssuer")<br>    name  = string<br>  })</pre> | `null` | no |
| <a name="input_eks_cluster"></a> [eks\_cluster](#input\_eks\_cluster) | Attributes of the EKS cluster on which the controller is deployed.  The names of the attributes match the names of outputs in the eks-cluster module to allow using the module as the argument to this variable.<br><br>The `cluster_name` attribute the the name of the EKS cluster.  It is required.<br>The `service_account_oidc_audience_variable` attribute is the ID of the cluster's IAM OIDC identity provider with the string ":aud" appended to it.  It is required.<br>The `service_account_oidc_subject_variable` attribute is the ID of the cluster's IAM OIDC identity provider with the string ":sub" appended to it.  It is required.<br>The 'service\_account\_oidc\_provider\_arn' attribute is the ARN of the cluster's IAM OIDC identity provider.  It is required. | <pre>object({<br>    cluster_name                           = string<br>    service_account_oidc_audience_variable = string<br>    service_account_oidc_subject_variable  = string<br>    service_account_oidc_provider_arn      = string<br>  })</pre> | n/a | yes |
| <a name="input_enable_goldilocks"></a> [enable\_goldilocks](#input\_enable\_goldilocks) | Determines if Goldilocks monitors the namespace to give recommendations on tuning pod resource requests and limits.<br>https://goldilocks.docs.fairwinds.com/installation/#enable-namespace | `bool` | `true` | no |
| <a name="input_enable_prometheus_rules"></a> [enable\_prometheus\_rules](#input\_enable\_prometheus\_rules) | Set to true to deploy a PrometheusRule resource to generate alerts based on the metrics scraped by Prometheus. | `bool` | `true` | no |
| <a name="input_grafana_dashboard_config"></a> [grafana\_dashboard\_config](#input\_grafana\_dashboard\_config) | Configures the optional deployment of Grafana dashboards in configmaps.  Set the value to null to disable dashboard installation.  The dashboards will be added to the "Cert-Manager" folder in the Grafana UI.<br><br>The 'folder\_annotation\_key' attribute is the Kubernets annotation that configures the Grafana folder into which the dasboards will appear in the Grafana UI.  It cannot be null or empty.<br>The 'label' attribute is a single element map containing the label the Grafana sidecar uses to discover configmaps containing dashboards.  It cannot be null or empty.<br>The 'namespace' attribute is the namespace where the configmaps are deployed.  It cannot be null or empty.<br><br>* https://github.com/grafana/helm-charts/tree/main/charts/grafana#sidecar-for-dashboards | <pre>object(<br>    {<br>      folder_annotation_key = string<br>      label                 = map(string)<br>      namespace             = string<br>    }<br>  )</pre> | `null` | no |
| <a name="input_http_challenge_solver_pod_configuration"></a> [http\_challenge\_solver\_pod\_configuration](#input\_http\_challenge\_solver\_pod\_configuration) | Customizes the resource requests and limits on the pods created by cert-manager to solve ACME HTTPS01 challenges. | <pre>object({<br>    resources = optional(<br>      object({<br>        limits = optional(<br>          object({<br>            cpu    = optional(string, "100m")<br>            memory = optional(string, "64Mi")<br>          }),<br>        {})<br>        requests = optional(<br>          object({<br>            # The default CPU request used by the controller is 10m with a CPU limit of 100m.  This far exceeds the<br>            # default 2:1 limit-to-request ratio enforced by the gitlab-application-k8s-namespace module.  To prevent<br>            # the defaults from preventing the pod to spawn, the default request is bumped to half the default limit.<br>            cpu    = optional(string, "50m")<br>            memory = optional(string, "64Mi")<br>          }),<br>        {})<br>      }),<br>    {})<br>  })</pre> | `{}` | no |
| <a name="input_image_registry"></a> [image\_registry](#input\_image\_registry) | The container image registry from which the controller, CA injector, webhook, and Helm hook images will be pulled.<br>The images must be under the 'jetstack/cert-manager-controller', 'jetstack/cert-manager-cainjector', 'jetstack/cert-manager-webhook' and 'jetstack/cert-manager-ctl' repositories, respectively.<br>The value can have an optional path suffix to support the use of ECR pull-through caches. | `string` | `"quay.io"` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | An optional map of kubernetes labels to attach to every resource created by the module. | `map(string)` | `{}` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Configures the the verbosity of cert-manager. Range of 0 - 6 with 6 being the most verbose. | `number` | `2` | no |
| <a name="input_node_tolerations"></a> [node\_tolerations](#input\_node\_tolerations) | An optional list of objects to set node tolerations on all pods deployed by the chart.  The object structure corresponds to the structure of the<br>toleration syntax in the Kubernetes pod spec.<br><br>https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/ | <pre>list(object(<br>    {<br>      key      = string<br>      operator = string<br>      value    = optional(string)<br>      effect   = string<br>    }<br>  ))</pre> | `[]` | no |
| <a name="input_pod_security_standards"></a> [pod\_security\_standards](#input\_pod\_security\_standards) | Configures the levels of the pod security admission modes.  Defaults to enforcing the restricted standard.<br><br>https://kubernetes.io/docs/concepts/security/pod-security-admission/<br>https://kubernetes.io/docs/tasks/configure-pod-container/enforce-standards-namespace-labels/<br>https://kubernetes.io/docs/concepts/security/pod-security-standards/ | <pre>object({<br>    audit   = optional(string, "restricted")<br>    enforce = optional(string, "restricted")<br>    warn    = optional(string, "restricted")<br>  })</pre> | `{}` | no |
| <a name="input_release_name"></a> [release\_name](#input\_release\_name) | The name to give to the Helm release. | `string` | `"cert-manager"` | no |
| <a name="input_service_monitor"></a> [service\_monitor](#input\_service\_monitor) | Controls deployment and configuration of a ServiceMonitor custom resource to enable Prometheus metrics scraping.  The kube-prometheus-stack CRDs must be available in the k8s cluster if  `enabled` is set to `true`. | <pre>object({<br>    enabled         = optional(bool, true)<br>    scrape_interval = optional(string, "30s")<br>  })</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | An optional map of AWS tags to attach to every resource created by the module. | `map(string)` | `{}` | no |
| <a name="input_webhook_pod_configuration"></a> [webhook\_pod\_configuration](#input\_webhook\_pod\_configuration) | Specifies the replica count, node selector, resource requests, and resource limits of the webhook pods. | <pre>object(<br>    {<br>      node_selector = optional(map(string), {})<br>      replicas      = optional(number, 2)<br>      resources = optional(<br>        object({<br>          limits = optional(<br>            object({<br>              cpu    = optional(string, "200m")<br>              memory = optional(string, "256Mi")<br>            }),<br>          {})<br>          requests = optional(<br>            object({<br>              cpu    = optional(string, "100m")<br>              memory = optional(string, "128Mi")<br>            }),<br>          {})<br>        }),<br>      {})<br>    }<br>  )</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_issuer_acme_dns01_route53_solvers"></a> [issuer\_acme\_dns01\_route53\_solvers](#output\_issuer\_acme\_dns01\_route53\_solvers) | A list of objects suitable for use as the list of solvers on a cert-bot ClusterIssuer or Issuer resource.  The list containts items for every entry in the acme\_dns01\_route53\_solvers variable.<br>https://cert-manager.io/docs/reference/api-docs/#acme.cert-manager.io/v1.ACMEIssuerDNS01ProviderRoute53 |
| <a name="output_issuer_acme_dns01_route53_solvers_by_zone"></a> [issuer\_acme\_dns01\_route53\_solvers\_by\_zone](#output\_issuer\_acme\_dns01\_route53\_solvers\_by\_zone) | A map whose values are lists of objects suitable for use as elments in the list of solvers on a cert-bot ClusterIssuer or Issuer resource.<br>Each entry in the map corresponds to an entry in the acme\_dns01\_route53\_solvers variable.<br>https://cert-manager.io/docs/reference/api-docs/#acme.cert-manager.io/v1.ACMEIssuerDNS01ProviderRoute53 |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | The name of the namespace containing all of the cert-manager resources. |
| <a name="output_route53_zone_ids"></a> [route53\_zone\_ids](#output\_route53\_zone\_ids) | The unique identifiers of the Route53 public zones cert-manager has permission to use. |
| <a name="output_route53_zone_names"></a> [route53\_zone\_names](#output\_route53\_zone\_names) | The names of the Route53 public zones cert-manager has permission to use. |
| <a name="output_route53_zones"></a> [route53\_zones](#output\_route53\_zones) | A list of objects contatining the attributes of the Route53 public zones cert-manager has permission to use. |
| <a name="output_service_account_role_arn"></a> [service\_account\_role\_arn](#output\_service\_account\_role\_arn) | The ARN of the IAM role created for the cert-manager k8s service account. |
| <a name="output_service_account_role_name"></a> [service\_account\_role\_name](#output\_service\_account\_role\_name) | The name of the IAM role created for the cert-manager k8s service account. |
<!-- END_TF_DOCS -->