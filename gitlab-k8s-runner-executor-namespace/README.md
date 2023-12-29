# Gitlab Runner Executor Kubernetes Namespace

## Overview

Designed to be used in conjunction with the [gitlab-k8s-runner-executor module](../gitlab-k8s-runner-executor/), this module creates a standardized shared Kubernetes namespace for the Gitlab runner executor pods.  All executors deployed to the Kubernetse cluster are expected to run in this namespace.  In addition to the namespace, an IAM role is created for the executors to assume.  The role provides access to [the S3 bucket that serves as a distributed cache](https://docs.gitlab.com/runner/configuration/advanced-configuration.html#the-runnerscaches3-section).  In addition to the namespace and role, the module creates an EKS Fargate profile for the namespace.  By running the executors on Fargate, EC2 nodes in the EKS cluster can be upgraded or terminated without risk of interrupting the executor while it is running CI jobs.

Creation and management of the IAM role and Fargate profile is delegated to the [eks-iam-role-for-service-account](../eks-iam-role-for-service-account/) and [eks-fargate-profile](../eks-fargate-profile/) modules, respectively.

## Usage

To reduce code duplication, the namespace module's outputs are designed to be used as the values of the gitlab-k8s-runner-executor-namespace module's variables.  Similarly, the variables of the module are designed to consume the outputs of the [eks-cluster module](../eks-cluster/).  While the module doesn't manage the S3 bucket used as the distributed cache, it does include an output, named `distributed_cache_bucket`, that can be used as the value of the `distributed_cache_bucket` variable of the gitlab-k8s-runner-executor module.  By doing so, it ensures the executors are configured to use the bucket their IAM has permission to access.

```hcl


module "k8s_cluster" {
    source = "eks-cluster"

}

resource "aws_s3_bucket" "gitlab_runner_cache" {
    bucket = "example-cache-bucket"
}

module "gitlab_runner_executor_namespace" {
    source = "gitlab-k8s-runner-executor-namespace"

    distributed_cache_bucket = aws_s3_bucket.gitlab_runner_cache
    eks_cluster              = module.k8s_cluster
    fargate_profile = {
        # The values of these attributes are omitted for brevity.
        pod_execution_role_arn = "..."
        subnet_ids             = ["..."]
    }

}

module "gitlab_runner" {
  source = "gitlab-k8s-runner-executor"


  cluster_name             = module.gitlab_runner_executor_namespace.cluster_name
  chart_version            = "..."

  # The distributed_cache_bucket variable can be set to the distributed_cache_bucket output of the namespace module to ensure
  # the runner uses the bucket in the executor's IAM role's policy.
  distributed_cache_bucket = module.gitlab_runner_executor_namespace.distributed_cache_bucket


  executor_iam_role_arn    = module.gitlab_runner_executor_namespace.iam_role_arn
  executor_namespace               = module.gitlab_runner_executor_namespace.name

  runner_scope                     = "instance"
  sealed_runner_registration_token = "AgB61x..."

}

```

## Assumptions and Limitations

* The module can only be applied once per Kubernetes cluster because the resource names are hardcoded.  There is no reason this limitation cannot be lifted should the need arise.
* Only one S3 bucket is used for caching for all of the executors in the namespace.
* The executors have access to all objects in the S3 bucket.
* The S3 bucket is in the same account as the IAM role managed by the module.
* The S3 bucket does not use an AWS KMS key for server-side encryption.

A useful description of the module goes here.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.4 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.67 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.20 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.20 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_fargate_profile"></a> [fargate\_profile](#module\_fargate\_profile) | ../eks-fargate-profile | n/a |
| <a name="module_iam_role"></a> [iam\_role](#module\_iam\_role) | ../eks-iam-role-for-service-account | n/a |

## Resources

| Name | Type |
|------|------|
| [kubernetes_namespace_v1.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_annotations"></a> [annotations](#input\_annotations) | An optional map containing the namespace's annotations. | `map(string)` | `{}` | no |
| <a name="input_distributed_cache_bucket"></a> [distributed\_cache\_bucket](#input\_distributed\_cache\_bucket) | An object containing the name of the S3 bucket used as the runner's distributed cache as well as the AWS region where the bucket is located. | <pre>object({<br>    bucket = string<br>    region = optional(string, "us-west-2")<br>  })</pre> | n/a | yes |
| <a name="input_eks_cluster"></a> [eks\_cluster](#input\_eks\_cluster) | Attributes of the EKS cluster on which Karpenter is deployed.  The names of the attributes match the names of outputs in the eks-cluster module to allow using the module as the argument to this variable.<br><br>The `cluster_name` attribute the the name of the EKS cluster.  It is required.<br>The 'service\_account\_oidc\_provider\_arn' attribute is the ARN of the cluster's IAM OIDC identity provider.  It is required. | <pre>object({<br>    cluster_name                      = string<br>    service_account_oidc_provider_arn = string<br>  })</pre> | n/a | yes |
| <a name="input_enable_goldilocks"></a> [enable\_goldilocks](#input\_enable\_goldilocks) | Determines if Goldilocks monitors the namespace to give recommendations on tuning pod resource requests and limits.<br>https://goldilocks.docs.fairwinds.com/installation/#enable-namespace | `bool` | `true` | no |
| <a name="input_fargate_profile"></a> [fargate\_profile](#input\_fargate\_profile) | An object whose attributes configure the Fargate profile in which the pods in the namespace run. | <pre>object({<br>    pod_execution_role_arn = string<br>    subnet_ids             = set(string)<br>  })</pre> | n/a | yes |
| <a name="input_labels"></a> [labels](#input\_labels) | An optional map of kubernetes labels to attach to every resource created by the module. | `map(string)` | `{}` | no |
| <a name="input_pod_security_standards"></a> [pod\_security\_standards](#input\_pod\_security\_standards) | Configures the levels of the pod security admission modes.<br><br>https://kubernetes.io/docs/concepts/security/pod-security-admission/<br>https://kubernetes.io/docs/tasks/configure-pod-container/enforce-standards-namespace-labels/<br>https://kubernetes.io/docs/concepts/security/pod-security-standards/ | <pre>object({<br>    audit   = optional(string, "restricted")<br>    enforce = optional(string, "baseline")<br>    warn    = optional(string, "restricted")<br>  })</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | An optional map of AWS tags to attach to every resource created by the module. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | The name of the EKS cluster containing the namespace. |
| <a name="output_distributed_cache_bucket"></a> [distributed\_cache\_bucket](#output\_distributed\_cache\_bucket) | An object containing the attributes of the S3 bucket the executors use as a distributed cache.  The IAM role has<br>full permission to the objects in the bucket.  Can be used as the value of the `distributed_cache_bucket`<br>variable in the gitlab-k8s-runner-executor module. |
| <a name="output_iam_role_arn"></a> [iam\_role\_arn](#output\_iam\_role\_arn) | The ARN of the IAM role the executors are allowed to assume using the EKS IAM Roles for Service Accounts feature. |
| <a name="output_iam_role_name"></a> [iam\_role\_name](#output\_iam\_role\_name) | The name of the IAM role the executors are allowed to assume using the EKS IAM Roles for Service Accounts feature. |
| <a name="output_name"></a> [name](#output\_name) | The name of the namespace. |
<!-- END_TF_DOCS -->