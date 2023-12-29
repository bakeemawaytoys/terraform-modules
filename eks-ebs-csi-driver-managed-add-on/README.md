# EKS EBS CSI Driver Managed Add-On

## Overview

Installs the [AWS EBS CSI driver](https://github.com/kubernetes-sigs/aws-ebs-csi-driver) in an EKS cluster as a managed add-on.  The module is modeled after [the driver installation instructions in the EKS documentation](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html).  Neither the add-on nor the module installs [the resources](https://github.com/kubernetes-csi/external-snapshotter) required to enable the driver's snapshot functionality.

EKS clusters have an [in-tree EBS storage provisioner](https://kubernetes.io/docs/concepts/storage/volumes/#awselasticblockstore) that [has been superceeded by the CSI driver](https://docs.aws.amazon.com/eks/latest/userguide/storage-classes.html).  When the cluster is created, a storage class named _gp2_ is also created.  It is configured to use the in-tree provisioner.  It also has the `storageclass.kubernetes.io/is-default-class` annotation set to true to make it the default storage class to use for [dynamic volume provisioning](https://kubernetes.io/docs/concepts/storage/dynamic-provisioning/).  The module replaces the _gp2_ storage class as the default by creating a new storage class named _ebs-default_ that also as the `storageclass.kubernetes.io/is-default-class` annotation set to true.  It then forcibly sets the `storageclass.kubernetes.io/is-default-class` annotation to false on the _gp2_ storage class.  Ideally the _gp2_ storage class would be deleted but there isn't a clean way to do that in Terraform with a resource it didn't create.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.4 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.10 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.10 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_eks_addon.driver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) | resource |
| [aws_iam_role.service_account](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.cmk](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [kubernetes_annotations.cluster_provisioner_default](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/annotations) | resource |
| [kubernetes_storage_class_v1.ebs_default](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/storage_class_v1) | resource |
| [aws_eks_addon_version.driver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_addon_version) | data source |
| [aws_eks_cluster.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster) | data source |
| [aws_iam_openid_connect_provider.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_openid_connect_provider) | data source |
| [aws_iam_policy.aws_managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy) | data source |
| [aws_iam_policy_document.cmk](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.trust_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_kms_key.cmk](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/kms_key) | data source |
| [aws_kms_key.volume_encryption](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/kms_key) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_addon_version"></a> [addon\_version](#input\_addon\_version) | The version of the EBS CNI driver add-on to use.  Can be set to 'default', 'latest', or pinned to a specific version. | `string` | `"default"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The name of the target EKS cluster. | `string` | n/a | yes |
| <a name="input_labels"></a> [labels](#input\_labels) | An optional map of kubernetes labels to attach to every resource created by the module. | `map(string)` | `{}` | no |
| <a name="input_node_selector"></a> [node\_selector](#input\_node\_selector) | An optional map of node labels to use the node selector of controller pods. | `map(string)` | `{}` | no |
| <a name="input_preserve_on_delete"></a> [preserve\_on\_delete](#input\_preserve\_on\_delete) | Indicates if you want to preserve the created resources when deleting the EKS add-on. | `bool` | `false` | no |
| <a name="input_resolve_conflicts"></a> [resolve\_conflicts](#input\_resolve\_conflicts) | Define how to resolve parameter value conflicts when applying version updates to the add-on. | `string` | `"OVERWRITE"` | no |
| <a name="input_service_account_oidc_provider_arn"></a> [service\_account\_oidc\_provider\_arn](#input\_service\_account\_oidc\_provider\_arn) | The ARN of the IAM OIDC provider associated with the target EKS cluster. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | An optional map of AWS tags to attach to every resource created by the module. | `map(string)` | `{}` | no |
| <a name="input_volume_encryption_key"></a> [volume\_encryption\_key](#input\_volume\_encryption\_key) | An KMS CMK alias, ARN, or  key ID of that will be used to encrypt volumes.  Permission to use the key will be granted to the driver's IAM role. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_addon_version"></a> [addon\_version](#output\_addon\_version) | The deployed version of the driver. |
| <a name="output_default_storage_class_name"></a> [default\_storage\_class\_name](#output\_default\_storage\_class\_name) | The name of the storage class that is annotated as the default. |
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | The ARN of the IAM role assumed by the driver. |
| <a name="output_role_name"></a> [role\_name](#output\_role\_name) | The name of the IAM role assumed by the driver. |
<!-- END_TF_DOCS -->