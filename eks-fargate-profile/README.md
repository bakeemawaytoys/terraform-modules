# EKS Fargate Profile

## Overview

A wrapper around the [`aws_eks_fargate_profile` resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_fargate_profile) to work around the immutability limitation of EKS Fargate profiles.  It uses a [`time_static` resource](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/static) to generate a new fargate profile name suffix any time one of the profile's static attributes changes.  This allow the resource to use the create_before_destroy lifecycle attribute so that a new profile will be available for pods scheduled on the profile before the old one is destroyed. See <https://docs.aws.amazon.com/eks/latest/userguide/fargate-profile.html#delete-fargate-profile> for details on Fargate's scheduling behavior to understand why this is necessary.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.40 |
| <a name="requirement_time"></a> [time](#requirement\_time) | ~> 0.9 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.40 |
| <a name="provider_time"></a> [time](#provider\_time) | ~> 0.9 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_eks_fargate_profile.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_fargate_profile) | resource |
| [time_static.fargate_profile](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/static) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The name of the target EKS cluster. | `string` | n/a | yes |
| <a name="input_fargate_profile_name"></a> [fargate\_profile\_name](#input\_fargate\_profile\_name) | The value to use as the name of the profile.  It will be suffixed with a dynamically generated value to ensure it is unique.  AWS allows names to be up to 63 characters in length but to account for the suffix, arguments are limited to 48 characters. | `string` | n/a | yes |
| <a name="input_pod_execution_role_arn"></a> [pod\_execution\_role\_arn](#input\_pod\_execution\_role\_arn) | Amazon Resource Name (ARN) of the IAM Role that provides permissions for the EKS Fargate Profile. | `string` | n/a | yes |
| <a name="input_selectors"></a> [selectors](#input\_selectors) | The selectors to determine which pods will be scheduled in the onto Fargate nodes with this profile.  See https://docs.aws.amazon.com/eks/latest/userguide/fargate-profile.html for more details on valid values. | <pre>list(object({<br>    namespace = string<br>    labels    = optional(map(string), {})<br>  }))</pre> | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | The subnets in which the ENIs of the pods scheduled on the profile will be created. | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | An optional map of AWS tags to attach to every resource created by the module. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_profile_name"></a> [profile\_name](#output\_profile\_name) | The full name, including the generated suffix, of the profile. |
<!-- END_TF_DOCS -->