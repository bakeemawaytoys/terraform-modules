# EKS Cluster AWS Authentication

## Overview

A module to manage the [aws-auth](https://docs.aws.amazon.com/eks/latest/userguide/add-user-role.html) config map in an EKS cluster.  The config map is used by the [aws-iam-authenticator-for-kubernetes](https://github.com/kubernetes-sigs/aws-iam-authenticator#aws-iam-authenticator-for-kubernetes) to enable authentication to a Kubernetes cluster with AWS IAM entities.  The module also creates two IAM roles.  One is for cluster nodes to assume and one is for Fargate nodes to assume.  By creating them in the module, Terraform can add them to the map and avoid state drift that would occur when the EKS cluster adds the role mappings itself.

For new EKS clusters, the module must be applied prior to add any nodes so that the module can create the _aws-auth_ configmap. If the config map already exists, it must be imported prior to running `terraform apply`.

  The module intentionally does not provide a way to add IAM users to the map to discourage the use of IAM access keys.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.23 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.23 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_instance_profile.node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.fargate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.fargate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.fargate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [kubernetes_config_map_v1.aws_auth](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map_v1) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.ec2_trust_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ecr_pull_through_cache](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.fargate_trust_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The name of the target EKS cluster. | `string` | n/a | yes |
| <a name="input_iam_role_mappings"></a> [iam\_role\_mappings](#input\_iam\_role\_mappings) | A list of objects containing the ARN of an IAM role, the k8s groups to assign to the role, and an<br>optional prefix to use with the `{{SessionName}}` variable to construct the k8s usernames assigned to the k8s role. | <pre>list(<br>    object(<br>      {<br>        role_arn        = string<br>        rbac_groups     = optional(set(string), [])<br>        username_prefix = optional(string)<br>      }<br>    )<br>  )</pre> | `[]` | no |
| <a name="input_ssm_agent_credentials_source"></a> [ssm\_agent\_credentials\_source](#input\_ssm\_agent\_credentials\_source) | Determines which credentials the Systems Manager agent will use.  When set to the default value of `default-host-management`, the agent will use credentials supplied by<br>System Manager's [Default Host Management feature](https://docs.aws.amazon.com/systems-manager/latest/userguide/managed-instances-default-host-management.html).  To use<br>the EC2 instance profile credentials, set this variable to `instance-profile`  The module will attach the `AmazonSSMManagedInstanceCore` IAM managed policy to the EC2 node role. | `string` | `"default-host-management"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | An optional map of AWS tags to attach to every resource created by the module. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_fargate_role_arn"></a> [fargate\_role\_arn](#output\_fargate\_role\_arn) | The ARN of the IAM role to use as the cluster's Fargate pod execution role |
| <a name="output_fargate_role_name"></a> [fargate\_role\_name](#output\_fargate\_role\_name) | The name of the IAM role to use as the cluster's Fargate pod execution role |
| <a name="output_node_instance_profile_arn"></a> [node\_instance\_profile\_arn](#output\_node\_instance\_profile\_arn) | The ARN of the instance profile attached to the  cluster's node group role |
| <a name="output_node_instance_profile_name"></a> [node\_instance\_profile\_name](#output\_node\_instance\_profile\_name) | The name of the instance profile attached to the  cluster's node group role |
| <a name="output_node_role_arn"></a> [node\_role\_arn](#output\_node\_role\_arn) | The ARN of the IAM role to use as the cluster's node group role |
| <a name="output_node_role_name"></a> [node\_role\_name](#output\_node\_role\_name) | The name of the IAM role to use as the cluster's node group role |
<!-- END_TF_DOCS -->