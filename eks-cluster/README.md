# EKS Cluster

## Overview

Deploy an EKS cluster and enables the [CoreDNS](https://docs.aws.amazon.com/eks/latest/userguide/managing-coredns.html), [kube-proxy](https://docs.aws.amazon.com/eks/latest/userguide/managing-kube-proxy.html), and [VPC-CNI](https://docs.aws.amazon.com/eks/latest/userguide/managing-vpc-cni.html) managed add-ons in the cluster.  An IAM OIDC provider is also created for the cluster to enable [IAM roles for service accounts](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html).  The module utilizes the OIDC provider to create an IAM for the VPC-CNI's service account. The module creates a IAM role for the cluster to assume unless the `predefined_cluster_role_name` input variable contains a value.  The `predefined_cluster_role_name` variable is only intended to be used for importing existing clusters into Terrform with this modue.  **New clusters should not use the `predefined_cluster_role_name` variable.**

One of the gotchas with EKS is that the IAM entity that creates the cluster is automatically granted the `system:masters` permissions in the cluster's role-based access.  As per [the EKS documentation](https://docs.aws.amazon.com/eks/latest/userguide/add-user-role.html#aws-auth-users), the entity is not visible in any way after the cluster is created outside of digging through CloudTrail logs.  In addition, the entity is an implicit administrator to the entire K8s cluster that can neither be removed nor changed to a different entity.  If the entity is deleted, it can be recreated as long as the name and type of the entity is know.  If the name is unknown, it is possible to be locked out of a cluster with no way of recovering access.  In an effort to avoid the lockout issue, the module creates an IAM role to "own" the cluster.  The role is configured to allow CloudFormation to assume it and it has permission to perform CRUD operations on EKS clusters.  The module delegates creation of the EKS cluster resource by creating a CloudFormation stack using a generated template and passing the IAM role to CloudFormation.  This ensures that the role is the entity that calls the EKS `CreateCluster` action and now the role assumed by Terraform.  The cluster also includes an AWS tag named `cluster_creator_arn` whose value is the ARN of the IAM role as a means of documenting the cluster creator.  Addressing this gotcha is on the [EKS roadmap](https://github.com/aws/containers-roadmap/issues/554), but there is no ETA at this time.

## Importing An Existing Cluster

1. Import the cluster into a new CloudFormation stack.
    1. Construct a CloudFormation JSON template that matches the one that would be generated by this module.
        1. Do not include the outputs in the template as the CloudFormation import operation does not allow it.
        1. Set the `DeletionPolicy` attribute to `Retain` on the `AWS::EKS::Cluster` resource.
        1. Add a `UpdateReplacePolicy` attribute set to `Retain` on the AWS::EKS::Cluster resource.
        1. Save the template to a file named `template.json`.
    1. Create the stack with a change set by running the following command

        ```shell
            aws cloudformation create-change-set \
            --stack-name "<Name Of the Existing Cluster>-eks-cluster" \
            --change-set-name ClusterImport \
            --change-set-type IMPORT \
            --resources-to-import "[{\"ResourceType\":\"AWS::EKS::Cluster\",\"LogicalResourceId\":\"Cluster\",\"ResourceIdentifier\":{\"Name\":\"<Name Of the Existing Cluster>\"}}]" \
            --parameters "ParameterKey=KubernetesVersion,ParameterValue=<The Existing Cluster's Kubernetes version>" \
            --template-body "$(cat template.json)"
        ````

    1. Review the change set in the AWS console and then click execute if it looks correct
1. Add a policy to the stack to prevent accidental deletion of the cluster by running the following command.

    ```shell
        aws cloudformation set-stack-policy --stack-name "<Name Of the Existing Cluster>-eks-cluster" --stack-policy-body '{"Statement":[{"Action":"Update:*","Effect":"Allow","Principal":"*","Resource":"*"},{"Action":["Update:Replace","Update:Delete"],"Condition":{"StringEquals":{"ResourceType":["AWS::EKS::Cluster"]}},"Effect":"Deny","Principal":"*","Resource":"*"}]}'
    ```

1. Add the outputs to the stack template to match the template that the module will produce.  Run the following command to create a change set.

    ```shell
            aws cloudformation create-change-set \
            --stack-name "<Name Of the Existing Cluster>-eks-cluster" \
            --change-set-name AddOutputs \
            --change-set-type UPDATE \
            --parameters "ParameterKey=KubernetesVersion,ParameterValue=<The Existing Cluster's Kubernetes version>" \
            --template-body "$(cat template.json)"
    ```

1. Import the CloudFormation stack along with the other existing resources into the state file.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | >= 3.1.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | >= 3.1.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_accessanalyzer_archive_rule.oidc_provider_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/accessanalyzer_archive_rule) | resource |
| [aws_cloudformation_stack.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack) | resource |
| [aws_cloudwatch_log_group.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ec2_tag.cluster_security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_tag) | resource |
| [aws_eks_addon.coredns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) | resource |
| [aws_eks_addon.kube_proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) | resource |
| [aws_eks_addon.vpc_cni](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) | resource |
| [aws_iam_openid_connect_provider.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_role.cloudformation_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.cluster_service_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.vpc_cni](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.cloudformation_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.vpc_cni](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.cluster_service_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.vpc_cni](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_kms_alias.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_resourcegroups_group.automation_k8s_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/resourcegroups_group) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_default_tags.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/default_tags) | data source |
| [aws_eks_addon_version.coredns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_addon_version) | data source |
| [aws_eks_addon_version.kube_proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_addon_version) | data source |
| [aws_eks_addon_version.vpc_cni](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_addon_version) | data source |
| [aws_eks_cluster.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster) | data source |
| [aws_iam_policy_document.cloudformation_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.cluster_owner_trust_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.eks_trust_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.vpc_cni](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.vpc_cni_trust_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_role.cluster_service_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_role) | data source |
| [aws_iam_roles.sso_permission_set](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_roles) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [tls_certificate.cluster](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/data-sources/certificate) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_analyzer_name"></a> [access\_analyzer\_name](#input\_access\_analyzer\_name) | The name of the IAM Access Analyzer in the same account and region in which the cluster is deployed. | `string` | `"account"` | no |
| <a name="input_additional_security_group_identifiers"></a> [additional\_security\_group\_identifiers](#input\_additional\_security\_group\_identifiers) | An optional set security group identifiers to attach to the cluster's network interfaces. | `set(string)` | `[]` | no |
| <a name="input_administrator_iam_principals"></a> [administrator\_iam\_principals](#input\_administrator\_iam\_principals) | The ARNs of any IAM principals that are allowed to assume the IAM role that creates the cluster. | `set(string)` | `[]` | no |
| <a name="input_administrator_sso_permission_sets"></a> [administrator\_sso\_permission\_sets](#input\_administrator\_sso\_permission\_sets) | The names of any AWS SSO permission sets that are allowed to assume the IAM role that creates the cluster. | `set(string)` | `[]` | no |
| <a name="input_cluster_creator_arn"></a> [cluster\_creator\_arn](#input\_cluster\_creator\_arn) | The ARN of the IAM principal that created the cluster outside of Terraform.  This is the principal with implicit system:masters access to the cluster's k8s API.  DO NOT SET THIS VALUE UNLESS YOU ARE IMPORTING THE CLUSTER INTO TERRAFORM. | `string` | `null` | no |
| <a name="input_cluster_ipv4_cidr_block"></a> [cluster\_ipv4\_cidr\_block](#input\_cluster\_ipv4\_cidr\_block) | The CIDR block to assign to the k8s cluster. | `string` | `"172.20.0.0/16"` | no |
| <a name="input_cluster_log_retention"></a> [cluster\_log\_retention](#input\_cluster\_log\_retention) | The number of days CloudWatch will retain the cluster's control plane logs. | `number` | `731` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The name of the EKS cluster. | `string` | n/a | yes |
| <a name="input_coredns_version"></a> [coredns\_version](#input\_coredns\_version) | The version of the coredns add-on to use.   Can be set to 'default',<br>'latest', 'none', or pinned to a specific version.  Use 'none' as the<br>argument if coredns should not be managed by EKS.  If the cluster does<br>does not have any nodes, then 'none' must be used because the add-on<br>will have the 'DEGRADED' status until nodes are added.  If an add-on<br>has the 'DEGRADED' status, Terraform will fail to apply. | `string` | `"none"` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | When set to true, the policy on the IAM role assumed by CloudFormation will not include the `eks:DeleteCluster` action<br>nor will the CloudFormation stack policy allow the cluster to be deleted.  Unlike services such as RDS, EKS does not<br>have a built-in way to prevent cluster deletion. Removing permission to delete clusters is the only way to implement<br>similar functionality. | `bool` | `true` | no |
| <a name="input_endpoint_private_access"></a> [endpoint\_private\_access](#input\_endpoint\_private\_access) | Enable or disable access to the k8s API endpoint from within the VPC | `bool` | `true` | no |
| <a name="input_endpoint_public_access"></a> [endpoint\_public\_access](#input\_endpoint\_public\_access) | Enable or disable access to the k8s API endpoint from the Internet. | `bool` | `false` | no |
| <a name="input_k8s_version"></a> [k8s\_version](#input\_k8s\_version) | The version of Kubernetes to use in the cluster. | `string` | n/a | yes |
| <a name="input_kube_proxy_version"></a> [kube\_proxy\_version](#input\_kube\_proxy\_version) | The version of the kube-proxy add-on to use.  Can be set to 'default', 'latest', or pinned to a specific version. | `string` | `"default"` | no |
| <a name="input_predefined_cluster_role_name"></a> [predefined\_cluster\_role\_name](#input\_predefined\_cluster\_role\_name) | The name of an existing IAM role the EKS cluster should assume instead of creating a dedicated role.  Do not use this argument for new clusters.  It is intended to be used when importing a cluster created outside of Terraform | `string` | `null` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | The subnets where the cluster will create its network interfaces. | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | An optional map of AWS tags to attach to every resource created by the module. | `map(string)` | `{}` | no |
| <a name="input_vpc_cni_version"></a> [vpc\_cni\_version](#input\_vpc\_cni\_version) | The version of the vpc-cni add-on to use.  Can be set to 'default', 'latest', or pinned to a specific version. | `string` | `"default"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_certificate_authority_base64"></a> [certificate\_authority\_base64](#output\_certificate\_authority\_base64) | The cluster endpoint's certificate authority's root certificate encoded in base64. |
| <a name="output_certificate_authority_pem"></a> [certificate\_authority\_pem](#output\_certificate\_authority\_pem) | The cluster endpoint's certificate authority's root certificate encoded in PEM format. |
| <a name="output_cloudformation_role_arn"></a> [cloudformation\_role\_arn](#output\_cloudformation\_role\_arn) | The ARN of the IAM role assumed by CloudFormation to manage the EKS cluster. |
| <a name="output_cloudformation_role_name"></a> [cloudformation\_role\_name](#output\_cloudformation\_role\_name) | The name of the IAM role assumed by CloudFormation to manage the EKS cluster. |
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | The AWS ARN of the EKS cluster. |
| <a name="output_cluster_creator_arn"></a> [cluster\_creator\_arn](#output\_cluster\_creator\_arn) | The AWS ARN of the IAM principal that created the EKS cluster.  This is the principal with implicit system:masters access to the cluster's k8s API. |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | The URL of the cluster's Kubernetes API. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | The name of the EKS cluster. |
| <a name="output_cluster_security_group_id"></a> [cluster\_security\_group\_id](#output\_cluster\_security\_group\_id) | The unique identifier of the cluster security group created by EKS. |
| <a name="output_k8s_version"></a> [k8s\_version](#output\_k8s\_version) | The version of Kubernetes running in the cluster. |
| <a name="output_log_group_arn"></a> [log\_group\_arn](#output\_log\_group\_arn) | The ARN of the CloudWatch log group containing the Kubernetes control plane logs. |
| <a name="output_service_account_issuer"></a> [service\_account\_issuer](#output\_service\_account\_issuer) | The OpenID issuer of the cluster's service account tokens. |
| <a name="output_service_account_oidc_audience_variable"></a> [service\_account\_oidc\_audience\_variable](#output\_service\_account\_oidc\_audience\_variable) | The name of the OIDC 'audience' variable to use for IAM policy condition keys in the trust policies of IAM roles for k8s service accounts. |
| <a name="output_service_account_oidc_provider_arn"></a> [service\_account\_oidc\_provider\_arn](#output\_service\_account\_oidc\_provider\_arn) | The ARN of the IAM OIDC provider to use for IAM roles for k8s service accounts. |
| <a name="output_service_account_oidc_provider_name"></a> [service\_account\_oidc\_provider\_name](#output\_service\_account\_oidc\_provider\_name) | The name of the IAM OIDC provider to use for IAM roles for k8s service accounts. |
| <a name="output_service_account_oidc_subject_variable"></a> [service\_account\_oidc\_subject\_variable](#output\_service\_account\_oidc\_subject\_variable) | The name of the OIDC 'sub' variable to use for IAM policy condition keys in the trust policies of IAM roles for k8s service accounts. |
| <a name="output_service_role_arn"></a> [service\_role\_arn](#output\_service\_role\_arn) | The ARN of the IAM role assumed by the EKS cluster. |
| <a name="output_service_role_name"></a> [service\_role\_name](#output\_service\_role\_name) | The name of the IAM role assumed by the EKS cluster. |
<!-- END_TF_DOCS -->