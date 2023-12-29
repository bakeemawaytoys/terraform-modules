# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## 2.0.0

### Added

- The `kubernetes.io/cluster` tag is now added to all AWS resources managed by the module.
- An inline policy has been added to both node roles to grant them the `ecr:BatchImportUpstreamImage` action.  The action is [required to use ECR pull-through cache repositories](https://docs.aws.amazon.com/AmazonECR/latest/userguide/pull-through-cache.html?icmpid=docs_ecr_hp-registry-private#pull-through-cache-iam).

### Changed

- **Breaking Change**: The minimum supported AWS provider version supported by the module is now 5.0.
- **Breaking Change**: The minimum supported Terraform version supported by the module is now 1.5.
- **Breaking Change**: The `AmazonSSMManagedInstanceCore` IAM managed policy is no longer attached to the EC2 node role by default.  Removing the policy forces the SSM agent to use the role configured for System Manager's new [Default Host Management](https://docs.aws.amazon.com/systems-manager/latest/userguide/managed-instances-default-host-management.html) feature.  The `ssm_agent_credentials_source` variable has been added to allow callers to attach the policy if necessary.
- [A conditional has been added to the Fargate node role's trust policy](https://docs.aws.amazon.com/eks/latest/userguide/pod-execution-role.html#check-pod-execution-role) avoid [the confused deputy problem](https://docs.aws.amazon.com/IAM/latest/UserGuide/confused-deputy.html).
- The `username_prefix` attribute of the `iam_role_mappings` variable has been changed to optional to eliminate the need to set it to an empty string.

### Removed

- **Breaking Change**: The `eks-console-dashboard-full-access` Kubernetes role and and role binding have been removed from the module.  It wasn't used, was difficult to keep up-to-date, and the `view` cluster role deployed in every K8s cluster serves the same purpose.  The `eks_console_sso_permission_sets` variable has been removed as part of this change.
- **Breaking Change**: The `custom_ec2_node_role_arns` variable has been removed to reduce the complexity of the module and because it is no longer needed.  It was used to during the process of transitioning EKS nodes to the IAM roles managed by this module.  Now that all EKS clusters are managed by Terraform, the variable is no longer needed.

## 1.1.0

### Added

- The `custom_ec2_node_role_arns` variable has been added to support applying this module to clusters that already have node roles present in the aws-auth configmap.  Prior to the addition of this variable, it was impossible to add a node role because the module always used the `{{SessionName}}` variable in the username.  For nodes, the `{{EC2PrivateDNSName}}` variable must be used or else the nodes break.
- All IAM role ARNs added to the aws-auth map are now stripped of any path components.  There is a [known issue with the aws-iam-authenticator](https://github.com/kubernetes-sigs/aws-iam-authenticator/issues/268).  Callers of the module no longer have to implement this logic themselves.

## 1.0.0

### Added

- Initial release !1
