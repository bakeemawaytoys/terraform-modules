# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 3.0.0

### Added

- The node group capacity type can now be configured using the new `capacity_type` variable.

### Changed

- **Breaking Change**: The `instance_type` variable has been replaced with the `instance_types` variable to allow the node group to contain mixed instance types.
- **Breaking Change**: The `cluster_name` variable has been replaced with the `eks_cluster` variable to eliminate the use of the `aws_eks_cluster` data resource in the module.  The variable's type is an object whose attribute names match the outputs of the [eks-cluster module](../eks-cluster).  Certain situations, such as a cluster upgrade, would cause the data resource to be read at apply time instead of plan time.  As a result, the plan couldn't provide all of the changes that would occur.  A side affect of passing in the cluster attributes is that the K8s version set on the node group can be pinned to control when it is upgraded.
- **Breaking Change**: The minimum Terraform version is now 1.3.
- **Breaking Change**: The minimum AWS provider version is now 4.50.
- The root volume on the instances will now be of type gp3 instead of gp2.
- The module no longer depends on the [EKS Managed Node Group module from the Terraform registry](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest/submodules/eks-managed-node-group).  The module didn't provide much benefit and it ignored changes to the desired size of the node group.  Terraform [`moved` blocks](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring#moved-block-syntax) have been added to the module to handle the resource address changes.

### Fixed

- Changes to the `desired` attribute of the `size` variable actually result in a change to the desired size of the group in AWS.  Sorry for the inconvenience.

## 2.0.0

### Added

- Introduced `container_registry_mirrors` variable to allow configuration of containerd registry mirrors.  Bottlerocket has supported this feature for a while but EKS used to generate invalid userdata in managed node group launch templates when registry mirrors were included.  The EKS issue appears to have been fixed.

### Changed

- Configured the `registryPullQPS` and `registryBurst` Kubelet settings to 50 and 100, respectively to avoid pull failures when a burst of pods are created.  Gitlab CI pipelines that spawn a large number of jobs, for example, can cause pull failures if the values are too low (i.e. the default values).  For more details on the settings, refer to the [Kubelet settings documentation](https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/#kubelet-config-k8s-io-v1beta1-KubeletConfiguration).
- The `instance_type` is now restricted to those types that use [the Nitro hypervisor](https://aws.amazon.com/ec2/nitro/), support [EBS encryption](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EBSEncryption.html), are [EBS optimized](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-optimized.html), and support [ENA](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/enhanced-networking-ena.html).  The required attributes are necessary for advanced EKS network features such as [pod security groups](https://docs.aws.amazon.com/eks/latest/userguide/security-groups-for-pods.html) and [increased node IP addresses](https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html).
- The `instance_type` variable is now limited to the instances types that can be launched in all of the availability zones assigned to the subnets specified in the `subnet_ids` variable.  While this can potentially limit the available instance types, it helps to ensure the cluster can survive availability zones outages.
- **Breaking Change**: The minimum Terraform version is now 1.2 due to the use of [custom post-condition checks](https://www.terraform.io/language/expressions/custom-conditions#preconditions-and-postconditions).

## Fixed

- Corrected the name of the SSM parameters used to look up the AMIs for arm64 instance types.

## 1.0.0

### Added

- Initial release
