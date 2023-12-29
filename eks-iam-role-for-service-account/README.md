# IAM Role for Kubernetes Service Account

## Overview

A module to manage [AWS IAM roles for Kubernetes service accounts](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html).  The module only manages the AWS IAM role and policy resources required to setup a role for a service account.  It does not create the IAM identity provider for the EKS cluster nor does it add the required annotations to the Kubernetes service account.

## Usage

A common scenario is to use this module in conjunction with the [gitlab-application-k8s-namespace](../gitlab-application-k8s-namespace/) module to create a role for an application deployed through the Gitlab CI/CD pipeline.  The outputs of the namespace module as the inputs for this module.  The `name` and `path` variables, in particular, must be set to the `iam_role_name` and `iam_role_path` outputs of the namespace module to ensure the ARN of the role matches the ARN on the service account annotations added by the namespace module.  Below is a simple example that also utilizes the outputs of the [eks-cluster](../eks-cluster/) module.

```hcl
data "aws_caller_identity" "current" {}

module "eks_cluster" {
  source = "eks-module"
  name = "DevelopmentCluster"
  # Other attributes omitted for clarity
}

module "k8s_namespace" {
  source = "gitlab-application-k8s-namespace"

  # This variable must be set for the module to add the IRSA annotations to the service account
  application_iam_role = {
    account_id   = data.aws_caller_identity.current.account_id
    cluster_name = module.eks_cluster.cluster_name
  }

  project = {
    id    = 1
    group = "example"
    name  = "my-application"
  }
}

module "application_iam_role" {
  source = "eks-iam-role-for-service-account"

  eks_cluster             = module.eks_cluster
  name                    = module.k8s_namespace.iam_role_name
  path                    = module.k8s_namespace.iam_role_path
  service_account         = module.k8s_namespace.application_service_account
  s3_access = {
    writer_buckets = [
        {
            bucket = "my-application-bucket"
        }
    ]
  }
}
```

The attributes of the `service_account` variable supports the use of the `?` and `*` characters as wildcards for a single character or multiple characters, respectively.  The wildcard characters are used in conjunction with [the `StringLike` IAM condition operator](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements_condition_operators.html#Conditions_String) to grant multiple service accounts permission to assume the role.  Both the `name` and `namespace` attributes of the variable support the wildcards.  Below is a modified version of the previous example that allows any service account in the namespace, whose name starts with `application-*`, to assume the role.

```hcl
data "aws_caller_identity" "current" {}

module "eks_cluster" {
  source = "eks-module"
  name = "DevelopmentCluster"
  # Other attributes ommitted for clarity
}

module "k8s_namespace" {
  source = "gitlab-application-k8s-namespace"

  # This variable must be set for the module to add the IRSA annotations to the service account
  application_iam_role = {
    account_id   = data.aws_caller_identity.current.account_id
    cluster_name = module.eks_cluster.cluster_name
  }

  project = {
    id    = 1
    group = "example"
    name  = "my-application"
  }
}

module "application_iam_role" {
  source = "eks-iam-role-for-service-account"

  eks_cluster             = module.eks_cluster
  name                    = module.k8s_namespace.iam_role_name
  path                    = module.k8s_namespace.iam_role_path
  service_account         = {
    name = "application-*"
    namespace = module.k8s_namespace.application_service_account.namespace
  }
  s3_access = {
    writer_buckets = [
        {
            bucket = "my-application-bucket"
        }
    ]
  }
}
```

## Policies

### Predefined Inline Policies

In an effort to standardize IAM policies and reduce the amount of effort required to set up AWS access, the module provides predefined IAM policies for the role.  The policies cover common use-cases for the most commonly used AWS services.  The concept of providing predefined policies comes from [the connectors concept in the AWS Serverless Application Model](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/managing-permissions-connectors.html).  The policies in the module are based on [the policy templates used to implement the connects in SAM](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-policy-template-list.html).

#### SQS Policies

The `sqs_access` variable is used to grant the role permission to read messages from SQS queues or write messages to SQS queues.  The module does not verify the existence of the queues while constructing the modules.  This is an intentional choice to permit the policies to reference SQS queues in other AWS accounts.  The module, at this time, does not support queues that use KMS CMK to encrypt messages.  Support for such queues will be added as the need arises.

#### S3 Policies

The `s3_access` variable is used to grant the role permissions write and read objects in S3 buckets.  The role is automatically granted read permission for the buckets specified in the `writer_buckets` attribute of the variable.  By default, the role is granted permission to access all objects in the configured buckets.  The object access can be scoped down to specific object keys using the `prefixes` attribute on the variables.  The variables also support buckets that use a KMS CMK for server-side encryption.  For those buckets, the ARN of the key must be specified using the `sse_kms_key_arn` attribute.  The role will be granted the required KMS permissions to access objects in the bucket.  The KMS permissions created by the module only support buckets that [use the CMK as a bucket key](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucket-key.html) due to the difference in the [encryption key context](https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingKMSEncryption.html#encryption-context).

The module does not attempt to access the buckets to read their attributes or verify their existence.  This allows the module to support granting access to S3 buckets in other AWS accounts.

Actions on object metadata are limited to tagging and versioning in an effort to minimize the size of the policy.  Additional actions can be added as the need arises.

#### SES Policies

The `ses_access` variable is used to grant the role permission to send email from verified email addresses. The module does not verify the existence of the SES identities while constructing the modules. This is an intentional choice to permit the policies to reference SES identities in other AWS accounts.

### Custom Permissions

For services that aren't covered by the predefined policies, the `custom_inline_policies` and `managed_policy_names` variables are available for attaching inline and managed policies, respectively.

## Future Work

* Add predefined policies for additional services such as SES, SNS, and RDS IAM authentication
* Add additional tagging to identify the application that assumes the role.
* Add support for KMS encrypted SQS queues.
* Add support for additional S3 object actions.

## Assumptions and Limitations

* To prevent accidentally granting access to AWS, neither the name nor the namespace of the service account can consist solely of the `*` wildcard character.
* The module does not allow the `default` service account to be provided as the value of the `service_account` variable.  The `default` service account is automatically assigned to any pod that doesn't specify a service account.  The possibility of accidentally granting access to AWS through the `default` service account is it too great of a risk to allow it.

## References

* <https://github.com/aws/amazon-eks-pod-identity-webhook>
* <https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html>
* <https://aws.amazon.com/jp/blogs/containers/diving-into-iam-roles-for-service-accounts/>
* <https://mjarosie.github.io/dev/2021/09/15/iam-roles-for-kubernetes-service-accounts-deep-dive.html>

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.50 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.50 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy) | data source |
| [aws_iam_policy_document.s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ses](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.sqs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.trust_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_custom_inline_policies"></a> [custom\_inline\_policies](#input\_custom\_inline\_policies) | A map whose entries are custom inline policies to attach to the role.  The keys are the name of the policies and the values are strings containing the policy JSON. | `map(string)` | `{}` | no |
| <a name="input_eks_cluster"></a> [eks\_cluster](#input\_eks\_cluster) | Attributes of the EKS cluster in which the application is deployed.  The names of the attributes match the names of outputs in the eks-cluster module to allow using the module as the argument to this variable.<br><br>The `cluster_name` attribute the the name of the EKS cluster.  It is required.<br>The 'service\_account\_oidc\_provider\_arn' attribute is the ARN of the cluster's IAM OIDC identity provider.  It is required. | <pre>object({<br>    cluster_name                      = string<br>    service_account_oidc_provider_arn = string<br>  })</pre> | n/a | yes |
| <a name="input_managed_policy_names"></a> [managed\_policy\_names](#input\_managed\_policy\_names) | An optional set of the names of managed IAM policies to attach to the role. | `set(string)` | `[]` | no |
| <a name="input_name"></a> [name](#input\_name) | The name of the role managed by this module. | `string` | n/a | yes |
| <a name="input_path"></a> [path](#input\_path) | The path of the role managed by this module. | `string` | `"/"` | no |
| <a name="input_s3_access"></a> [s3\_access](#input\_s3\_access) | An optional object containing S3 buckets the role has permission to either read from or write to. An inline policy<br>is attached to the role to grant access to the queues.  At least one bucket must be provided if the variable is<br>not set to null.  The `writer_buckets` attribute contains the list of buckets to which the role has permission to read<br>and write objects.  The `read_buckets` attribute contains the list of buckets to which the role only has permission<br>to read objects.  All buckets must be in the same AWS account as the role.<br><br>Both lists contain objects with the following properites.  Each object corresponds to one bucket.<br>The `arn` attribute is the ARN of the bucket.  It is required if the `bucket` attribute is not set.<br>The `bucket` attribute is the name of the bucket.  It is required if the `arn` attribute is not set.<br>The `sse_kms_key_arn` attribute is the ARN of the KMS key used to encrypt objects in the bucket, if the bucket is configured with an SSE key.<br>The `prefixes` attribute is a list of object key prefixes in the bucket the role can access.  By default, the role has access to all objects. | <pre>object({<br>    writer_buckets = optional(list(<br>      object({<br>        arn             = optional(string)<br>        bucket          = optional(string)<br>        sse_kms_key_arn = optional(string)<br>        prefixes        = optional(list(string), ["*"])<br>      })<br>    ), [])<br>    reader_buckets = optional(list(<br>      object({<br>        arn             = optional(string)<br>        bucket          = optional(string)<br>        sse_kms_key_arn = optional(string)<br>        prefixes        = optional(list(string), ["*"])<br>      })<br>    ), [])<br>  })</pre> | `null` | no |
| <a name="input_service_account"></a> [service\_account](#input\_service\_account) | The name and namespace of the Kubernetes service account that can assume the role.  Either value may contain the `?` and `*`<br>wildcard characters to configure the roles trust policy to allow multiple service accounts to assume the role.  For more<br>details on the wildcards, see the IAM documentation on the `StringLike` condition operator at https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements_condition_operators.html#Conditions_String. | <pre>object({<br>    name      = string<br>    namespace = string<br>  })</pre> | n/a | yes |
| <a name="input_ses_access"></a> [ses\_access](#input\_ses\_access) | An optional object containing SES identities the role has permission to send email from. An inline policy<br>is attached to the role to grant access to the identities.  At least one identity must be provided if the variable is<br>not set to null.  The existence of the identities is not checked by the module to allow for cross-account access to identities.<br><br>The `email_identity_arns` attribute is the set of ARNs of the email identities the role has permission to send email from. | <pre>object({<br>    email_identity_arns = optional(set(string), [])<br>  })</pre> | `null` | no |
| <a name="input_sqs_access"></a> [sqs\_access](#input\_sqs\_access) | An optional object containing sets of SQS queues the role has permission to either read from or send to. An inline policy<br>is attached to the role to grant access to the queues.  At least one queue ARN must be provided if the variable is not<br>set to null. The existence of the queues is not checked by the module to allow for cross-account access to queues.<br><br>The `consumer_queue_arns` attribute is the set of ARNs of the queues the role has permission to read from.<br>The `producer_queue_arns` attribute is the set of ARNs of the queues the role has permission to write to. | <pre>object({<br>    consumer_queue_arns = optional(set(string), [])<br>    producer_queue_arns = optional(set(string), [])<br>  })</pre> | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | An optional map of AWS tags to attach to every resource created by the module. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arn"></a> [arn](#output\_arn) | The ARN of the IAM role managed by this module. |
| <a name="output_name"></a> [name](#output\_name) | The name of the IAM role managed by this module. |
| <a name="output_unique_id"></a> [unique\_id](#output\_unique\_id) | The unique identifier assigned to the role by AWS. |
<!-- END_TF_DOCS -->
