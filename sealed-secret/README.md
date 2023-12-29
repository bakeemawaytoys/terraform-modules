# Sealed Secret

## Overview

Standardizes and simplifies management [SealedSecret resources in Kubernetes](https://github.com/bitnami-labs/sealed-secrets).  It is a companion module to the [sealed-secrets-controller module](../sealed-secrets-controller/).

## Usage

### Sealing Secrets

Secrets are encrypted using a the `kubeseal` CLI tool.  To use `kubeseal` with the controller deployed by this module, the `--controller-name` argument must be set to the same value as the module's `release_name` and the `--controller-namespace` argument must be set to the same value as the module's `namespace` argument.  Note that the default values for the `release_name` and `namespace` module correspond to `kubeseal`'s default values for the corresponding arguments (sealed-secrets-controller and kube-system, respectively).

To create a sealed secret resource with Terraform, use either the [`manifest` resource in the _kubernetes_ provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) or the [`kubectl_manifest` resource in the _kubectl_ provider](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/kubectl_manifest).  When encrypting the secret value(s), use `kubeseal` in [raw mode](https://github.com/bitnami-labs/sealed-secrets#raw-mode-experimental) to avoid the need to create a raw Kubernetes secret manifest just to encrypt the value(s).

### Templated Secrets

#### Example

The Sealed Secrets controller supports [an under-documented feature for injecting the sealed values into other values in the resulting Secret resource](https://github.com/bitnami-labs/sealed-secrets/tree/main/docs/examples/config-template).  The feature makes it easier to include complex values, such as configuration files, in the Secret resource without the need to seal the entire configuration file.  The `templated_secret_data` variable is exposed by the module for specifying such values.  When processing the `templated_secret_data` values, the Sealed Secrets controller looks for the pattern `{{ index . "<sealed value key>" }}`, where the "sealed value key" is the key in the `encrypted_data` variable map of the sealed value to inject.  Note that **the double quotes around the key are required**.  The processed templated values will appear in the Secret resource's `data` attribute with the same keys as those specified in the `templated_secret_data` variable.

The `templated_secret_data` variable values do not have to include any injected secrets.  They can be used to add arbitrary key/value pairs into the resulting Secret resource.

The following example shows how to use the `templated_secret_data` variable.

```hcl
module "example {
    source = "sealed-secret"

    encrypted_data =  {
        password = "AgA29wIEvBbzDLHS6KnWkm0BTdGW...."
    }

    templated_secret_data = {

        "secrets.properties" = <<-EOF
        username = "root"
        password = "{{ index . "password" }}"
        EOF


        "config.properties" = <<-EOF
        api_root_url = https://example.com/api/v1/
        client_id = 34243423
        EOF
    }

    name = "example"
    namespace = "default"
}
```

The resulting Secret resource will look like the following (with the base64 data values decoded).

```yaml
apiVersion: v1
data:
  password: supersecret
  secrets.properties: |
    username = "root"
    password = "supersecret"
  config.properties: |
    api_root_url = https://example.com/api/v1/
    client_id = 34243423
kind: Secret
metadata:
  labels:
    app.kubernetes.io/managed-by: sealed-secrets
  name: example
  namespace: default
type: Opaque

```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.16.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.16.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [kubernetes_manifest.sealed_secret](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_resource.sealed_secret](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/data-sources/resource) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_annotations"></a> [annotations](#input\_annotations) | An optional map of kubernetes annotations to attach to the SealedSecret resource created by the module. | `map(string)` | `{}` | no |
| <a name="input_encrypted_data"></a> [encrypted\_data](#input\_encrypted\_data) | A map of strings that is used to populate the 'spec.encryptedData' attribute of the SealedSecret resource. | `map(string)` | n/a | yes |
| <a name="input_labels"></a> [labels](#input\_labels) | An optional map of kubernetes labels to attach to the SealedSecret resource created by the module. | `map(string)` | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | The name to use for both the SealedSecret resource and the generated Secret resource. | `string` | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | The namespace where both the SealedSecret and Secret resources will be created. | `string` | n/a | yes |
| <a name="input_scope"></a> [scope](#input\_scope) | Specifies the scope of the sealed secret  The module will add the appropriate scope annotation to the SealedSecret resource based on this variable.<br>Must be one of 'strict', 'namespace-wide', or 'cluster-wide'.  The default is 'strict'." | `string` | `"strict"` | no |
| <a name="input_secret_metadata"></a> [secret\_metadata](#input\_secret\_metadata) | An optional object containing labels and/or annotations to apply to the generated Secret resource. | <pre>object(<br>    {<br>      annotations = optional(map(string), {})<br>      labels      = optional(map(string), {})<br>    }<br>  )</pre> | `{}` | no |
| <a name="input_secret_type"></a> [secret\_type](#input\_secret\_type) | The secret type of the generated Secret resource.  Defaults to Opaque. | `string` | `"Opaque"` | no |
| <a name="input_templated_secret_data"></a> [templated\_secret\_data](#input\_templated\_secret\_data) | A map containing additional plaintext values to include in the spec.template.data attribute of the generated Secret resource.  The values in the map support injection<br>of secret values defined in the 'encrypted\_data' variable.  To inject a value use the following Go template function.<br><br>{{ index . "The key in the encrypted\_data variable that maps to the secret value to inject.  It must be wrapped in double quotes" }}<br><br>The primary use case is to store configuration files in the Generated secret without encrypting the entire configuration file.<br>For more details, see https://github.com/bitnami-labs/sealed-secrets/tree/main/docs/examples/config-template | `map(string)` | `{}` | no |
| <a name="input_timeouts"></a> [timeouts](#input\_timeouts) | Configures the create, update, and delete timeouts (in seconds) on the SealedSecret's Terraform resource. | <pre>object({<br>    create = optional(number, 30)<br>    delete = optional(number, 30)<br>    update = optional(number, 30)<br>  })</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_name"></a> [name](#output\_name) | The name of both the SealdSecret resource and the Secret resource. |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | The namespace in which both the Secret and SealedSecret resource exist. |
<!-- END_TF_DOCS -->