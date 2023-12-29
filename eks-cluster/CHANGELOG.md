# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## 4.0.0

### Changed

- Removed the AWS provider version restrictions added in module version 3.0.1.  The module has been refactored to work around the change in version 5.13 that marked the `aws_cloudformation_stack` resource's outputs as computed.  The dependency on the `aws_cloudformation_stack`  has been removed from as many resources and values as possible.
- **Breaking Change**: As part of the refactoring to support version 5.13+ of the AWS provider, a number of the module outputs have been modified to refer to module variables instead of the `aws_cloudformation_stack` resource's outputs.  As a result, the dependency between the EKS cluster and resources outside of this module no longer exist.  While this won't matter in most cases, it can result in resource changes appearing plans when they wouldn't have in the previous version of this module.  The `k8s_version` output, in particular, will now trigger upgrades to EKS managed node groups that depend on it in the same plan as changes to the EKS cluster's control plan version.  This is considered a breaking change due to the change in Terraform's behavior.
- **Breaking Change**:

## 3.0.1

### Changed

- Set the maximum supported AWS provider version to 5.12 due to [a change in version 5.13](https://github.com/hashicorp/terraform-provider-aws/blob/main/CHANGELOG.md#5130-august-18-2023) that effectively breaks cluster upgrades.  In 5.13, the `outputs` attribute of the `aws_cloudformation_stack` resource was marked as computed.  As a result, Terraform plans to modify any resource that depends on the stack outputs.  For many resources, it results in recreation of the resource.

## 3.0.0

### Changed

- **Breaking Change**: The minium supported version of the AWS provider has been changed from 4.67 to 5.0.  The `aws_eks_addon` resource contains deprecations in version 5.0.  The module has been modified to remove the use of those deprecations.

## 2.3.0

### Added

- The module now supports Kubernetes 1.25, 1.26, and 1.27.
- The `"kubernetes.io/cluster" = "<cluster name>"` tag is now applied to every AWS resource in the module to provide a consistent tag for [ABAC](https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction_attribute-based-access-control.html) in IAM policies.
- The `deletion_protection` variable has been added to control the inclusion cluster deletion actions in both the CloudFormation IAM role's policy and the CloudFormation stack policy.  When set to true, the `eks:DeleteCluster` action is omitted from the role's policy and a statement to deny both `Update:Replace` and `Update:Delete` is added to the stack policy.

### Removed

- Dropped support for Kubernetes 1.22 because EKS no longer supports it.  This has not been marked as a breaking change because we don't have any clusters on 1.22 and it is impossible to create a cluster with that version.

## 2.2.0

### Added

- An IAM Access Analyzer archive rule has been added to the module to automatically archive findings for IAM roles that use the cluster's OIDC provider in their trust policy.  The module assumes that the analyzer is in the same region and account as the EKS cluster.
- The AWS provider's set of default tags and tags supplied in the `tags` variable are now added to the cluster's security group that is created and managed by EKS.

### Changed

- Refactored the module to reduce the number of resources that depend on data resources that are read at apply time.  Hopefully this will result in smaller, clearer plans when upgrading clusters.

### Removed

- The module no longer supports K8s 1.20 and 1.21 because EKS no longer supports those versions for new clusters.  Also, we don't have any clusters running on those versions.

## 2.1.2

### Fixed

- Fixed the `cluster_creator_arn` tag on the CloudFormation stack.

## 2.1.1

### Fixed

- The Kubernetes version parameter validation on the CloudFormation template correctly matches the versions allowed by the `k8s_version` variable.

## 2.1.0

### Added

- The module now supports Kubernetes 1.23 and 1.24.

### Fixed

- The `cluster_creator_arn` tag has been added to the CloudFormation stack to ensure it is applied to clusters that were imported into CloudFormation.  Prior to this change, the tag was only specified in the stack template.
- The IAM role assumed by CloudFormation is now tagged with the tags specified in the `tag` variable.

### Changed

- Updated the policy on the CloudFormation role to limit the `eks:ListTagsForResource` action to the cluster managed by the module.  The change was made base on a recommendation by the tfsec tool.
- The `subnet_ids` and `cluster_log_retention` variables now include validation checks.

## 2.0.0

### IMPORTANT UPGRADE NOTES

- You must upgrade to 1.2.x or later before upgrading to 2.0 due to the use of a new CloudFormation stack output.
- Terraform 1.2 is now the minimum required version.
- Module outputs have been renamed see the _Changed_ section below for details.

### Added

- Added the optional `cluster_creator_arn` variable to support importing EKS clusters that were created outside of this module.  If the variable is not null, the name and description of the cluster owner IAM role resource will be modified to reflect that it doesn't own the cluster.  The role is only used by CloudFormation to managed the cluster resource.  The value of the variable is also used for the _cluster_creator_arn_ tag that is applied to the cluster.
- Added an AWS Resource Group resource that groups together all resources that are tagged with the `kubernetes.io/cluster/<cluster name>` tag with the value of "owned".
- The `cluster_creator_arn` output has been added to expose the ARN of the IAM principal that has implicit administrator access to the cluster's k8s API.

### Changed

- The minimum Terraform version is now set to 1.2 to allow the use of [custom condition checks on resources](https://www.terraform.io/language/meta-arguments/lifecycle#custom-condition-checks).
- Renamed the `aws_iam_role.cluster_owner` resource to `aws_iam_role.cloudformation` to reflect the fact that the role isn't necessarily the create/owner of the cluster.
- Renamed the `aws_iam_role_policy.cluster_owner` resource to `aws_iam_role_policy.cloudformation` to reflect the fact that the role isn't necessarily the create/owner of the cluster.
- Renamed the `owner_role_arn` output to `cloudformation_role_arn` to reflect the fact that the role isn't necessarily the create/owner of the cluster.
- Renamed the `owner_role_name` output to `cloudformation_role_name` to reflect the fact that the role isn't necessarily the create/owner of the cluster.

### Fixed

- Fixed the issue where Terraform would try to recreate the IAM OIDC identity provider every time the CloudFormation stack was modified.  The cluster's OIDC issuer URL is now read from a stack output at plan time instead of the `aws_eks_cluster` data resource during apply time.

## 1.2.0

### Added

- Added the `OpenIdConnectIssuerUrl` output to the CloudFormation template generated by the module.  The output will be used in the next major release to fix a bug.
- Added the `KubernetesVersion` output to the CloudFormation template generated by the module.

## 1.0.1

### Fixed

- Removed the `aws:SourceArn` condition from the cluster role trust policy because it prevents EKS from assuming the role. !7

## 1.0.0

### Added

- Initial release
