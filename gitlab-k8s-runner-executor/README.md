# Gitlab Kubernetes Runner Executor

## Overview

Deploys the [Gitlab Kubernetes runner executor](https://docs.gitlab.com/runner/install/kubernetes.htmlhttps://docs.gitlab.com/runner/install/kubernetes.html) into the specified namespace using [the official Helm chart](https://gitlab.com/gitlab-org/charts/gitlab-runner).  The executor is configured to run all of its jobs in a dedicated namespace managed by this module.  The executor itself runs in a separate namespace managed outside of this module.

## Supported Runner Versions

While the module attempts to support the widest range of chart versions, it does make use of chart values that are only available in some versions of the chart.  The table below lists the currently supported chart versions and their corresponding runner versions.

| Chart Version | Runner Version |
| ---      | ---      |
| [0.53.2](https://gitlab.com/gitlab-org/charts/gitlab-runner/-/blob/v0.53.2/CHANGELOG.md) | [16.0.2](https://gitlab.com/gitlab-org/gitlab-runner/-/blob/v16.0.2/CHANGELOG.md) |
| [0.54.0](https://gitlab.com/gitlab-org/charts/gitlab-runner/-/blob/v0.54.0/CHANGELOG.md) | [16.1.0](https://gitlab.com/gitlab-org/gitlab-runner/-/blob/v16.1.0/CHANGELOG.md) |
| [0.55.0](https://gitlab.com/gitlab-org/charts/gitlab-runner/-/blob/v0.55.0/CHANGELOG.md) | [16.2.0](https://gitlab.com/gitlab-org/gitlab-runner/-/blob/v16.2.0/CHANGELOG.md) |
| [0.56.0](https://gitlab.com/gitlab-org/charts/gitlab-runner/-/blob/v0.56.0/CHANGELOG.md) | [16.3.0](https://gitlab.com/gitlab-org/gitlab-runner/-/blob/v16.3.0/CHANGELOG.md) |

## Usage

### Preparing The Registration Token

The module utilizes the [Bitnami Sealed Secrets controller](https://github.com/bitnami-labs/sealed-secrets) to allow installation and management of the runner's registration token using GitOps.  By encrypting the token as a sealed secret, it can be safely stored in Git as well as in the Terraform state file.  It removes the risks of storing the token in version control while maintaining the benefits of GitOps.

The token is sealed using the the controller's client, [the `kubeseal` CLI tool](https://github.com/bitnami-labs/sealed-secrets#homebrew).  The module expects the secret to be sealed using `kubeseal`'s [raw mode](https://github.com/bitnami-labs/sealed-secrets#raw-mode-experimental) because the module will construct and manage the Sealed Secret resource in Kubernetes.  To use raw mode, it is necessary to know the name of the Sealed Secret resource the module manages.  The name is constructed by joining the string _gitlab-runner_ with the `runner_scope` and the `runner_flavor` variables with a dash between each value.  For example, if the `runner_scope` is set to _group-10_ and the `runner_flavor` is set to _tagged_, the name of the Sealed Secret resource will be _gitlab-runner-group-10-tagged_.  If the `runner_flavor` variable is not set, its default value is _default_.

Using the example values, the full `kubeseal` command for deploying the runner in the _gitlab-runner-executors_ namespace would like the following.

```shell
kubeseal \
    --name gitlab-runner-group-10-tagged \
    --namespace gitlab-runner-executors \
    --raw
```

Note that, by default, `kubeseal` uses `kubectl`'s current context to connect to the Sealed Secrets controller.  To specify a context when executing `kubeseal`, use the `--context` option.

### Configuring an IAM Role For Build Pods

The module supports the [IAM Roles for Service Accounts](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html) feature to grant AWS permissions to build pods.  To associate an IAM role with the build pod's, use the `build_pod_aws_iam_role` variable to specify the name of the role and the role's AWS account number.  The module will add [the required annotations](https://docs.aws.amazon.com/eks/latest/userguide/specify-service-account-role.html) to the build pod's service account to enable the [IAM Roles for Service Accounts](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html) feature in EKS.  The module does not manage any AWS resources and therefore **does not create the IAM role**.  The role must be created outside of the module.  To ease the creation of the trust policy on the roles, the `build_pod_token_oidc_subject_claim`, `iam_eks_role_module_service_account_value`, `build_pod_service_account`, and `build_pod_iam_role_name` outputs are made available.  The `iam_eks_role_module_service_account_value` variable exists specifically for use with the [version 5.2+ of the iam-eks-role module in the terraform-aws-modules project](https://github.com/terraform-aws-modules/terraform-aws-iam/tree/master/examples/iam-eks-role).

### Example Using The _iam-eks-role_ Module

```hcl
module "aws_deployment_runner" {
    source = "gitlab-k8s-runner-executor"

    build_pod_aws_iam_role = {
        name = "aws-deployment-job"
        account_id = "111122223333"
    }

    // Other variables omitted
}

module "aws_deployment_job_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-eks-role"
  version = "~> 5.2.0"

  role_name = module.aws_deployment_runner.build_pod_iam_role_name

  cluster_service_accounts = module.aws_deployment_runner.iam_eks_role_module_service_account_value

}

```

### Example Using Terraform Resources

```hcl

module "k8s_cluster" {
    source = "eks-cluster"

    // Variables omitted for brevity
}

module "aws_deployment_runner" {
    source = "gitlab-k8s-runner-executor"

    build_pod_aws_iam_role = {
        name = "aws-deployment-job"
        account_id = "111122223333"
    }

    // Other variables omitted for brevity
}

data "aws_iam_policy_document" "aws_deployment_runner_trust_policy" {
  statement {
    principals {
      identifiers = [module.k8s_cluster.service_account_oidc_provider_arn]
      type        = "Federated"
    }
    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]
    condition {
      test     = "StringEquals"
      values   = [module.aws_deployment_runner.build_pod_token_oidc_subject_claim]
      variable = module.k8s_cluster.service_account_oidc_subject_variable
    }
    condition {
      test     = "StringEquals"
      values   = ["sts.amazonaws.com"]
      variable = module.k8s_cluster.service_account_oidc_audience_variable
    }
  }
}

resource "aws_iam_role" "aws_deployment_runner" {
  assume_role_policy = data.aws_iam_policy_document.aws_deployment_runner_trust_policy.json
  description        = "AWS Deployment Jobs"
  name               = module.aws_deployment_runner.build_pod_iam_role_name
}

```

## References

* <https://docs.gitlab.com/ee/ci/runners/configure_runners.html>
* <https://docs.gitlab.com/runner/executors/kubernetes.html>
* <https://gitlab.com/gitlab-org/charts/gitlab-runner>

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.4 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.9 |
| <a name="requirement_http"></a> [http](#requirement\_http) | ~> 3.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.16 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.9 |
| <a name="provider_http"></a> [http](#provider\_http) | ~> 3.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.16 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_registration_token"></a> [registration\_token](#module\_registration\_token) | ../sealed-secret | n/a |

## Resources

| Name | Type |
|------|------|
| [helm_release.runner](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace_v1.build](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_role_binding_v1.executor](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_binding_v1) | resource |
| [kubernetes_role_v1.executor](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_v1) | resource |
| [kubernetes_service_account_v1.build](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account_v1) | resource |
| [kubernetes_service_account_v1.executor](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account_v1) | resource |
| [terraform_data.config](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [http_http.gitlab_runner_chart](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |
| [kubernetes_namespace_v1.executor](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/data-sources/namespace_v1) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allowed_images"></a> [allowed\_images](#input\_allowed\_images) | Restricts the images that may be used in build jobs to those that match the the patterns in the list.  If the list is empty, any image is allowed (the default).<br>See also: https://docs.gitlab.com/runner/configuration/advanced-configuration.html#restricting-docker-images-and-services | `list(string)` | `[]` | no |
| <a name="input_architecture"></a> [architecture](#input\_architecture) | The CPU architecture on which the exectuor and the jobs will run. | `string` | `"x86_64"` | no |
| <a name="input_build_container_resources"></a> [build\_container\_resources](#input\_build\_container\_resources) | CPU and memory settings for the build container that runs the job script.  Sets default request and limit values as well as the maximum<br>allowed values that can be set in the job variables.  See https://docs.gitlab.com/runner/executors/kubernetes.html#overwriting-container-resources<br>for more on using the job variables. | <pre>object(<br>    {<br>      limits = optional(<br>        object({<br>          cpu = optional(<br>            object({<br>              default = optional(string, "500m")<br>              max     = optional(string, "")<br>            }),<br>          {})<br>          ephemeral_storage = optional(<br>            object({<br>              default = optional(string, "20Gi")<br>              max     = optional(string, "")<br>            }),<br>          {})<br>          memory = optional(<br>            object({<br>              default = optional(string, "1Gi")<br>              max     = optional(string, "")<br>            }),<br>          {})<br>        }),<br>      {})<br>      requests = optional(<br>        object({<br>          cpu = optional(<br>            object({<br>              default = optional(string, "250m")<br>              max     = optional(string, "")<br>            }),<br>          {})<br>          ephemeral_storage = optional(<br>            object({<br>              default = optional(string, "20Gi")<br>              max     = optional(string, "")<br>            }),<br>          {})<br>          memory = optional(<br>            object({<br>              default = optional(string, "512Mi")<br>              max     = optional(string, "")<br>            }),<br>          {})<br>        }),<br>      {})<br>    }<br>  )</pre> | `{}` | no |
| <a name="input_build_container_security_context"></a> [build\_container\_security\_context](#input\_build\_container\_security\_context) | Specifies the Linux user ID, group ID, and capabilites to add or remove on the build container's security context. | <pre>object(<br>    {<br>      run_as_user       = optional(number, 1000)<br>      run_as_group      = optional(number, 1000)<br>      add_capabilities  = optional(set(string), [])<br>      drop_capabilities = optional(set(string), ["ALL"])<br>    }<br>  )</pre> | `{}` | no |
| <a name="input_build_pod_annotations"></a> [build\_pod\_annotations](#input\_build\_pod\_annotations) | Kubernetes annotations to apply to every build pod created by the runner.  Annotation values can contain Gitlab CI variables.<br>See https://docs.gitlab.com/ee/ci/variables/predefined_variables.html for the list of available variables.  The module automatically<br>includes the 'karpenter.sh/do-not-evict' annotation to prevent Karpenter from evicting pods while jobs are running.  For more<br>details, see https://karpenter.sh/preview/tasks/deprovisioning/#pod-set-to-do-not-evict. | <pre>object(<br>    {<br>      static            = optional(map(string), {})<br>      overwrite_allowed = optional(string, "")<br>    }<br>  )</pre> | `{}` | no |
| <a name="input_build_pod_aws_iam_role"></a> [build\_pod\_aws\_iam\_role](#input\_build\_pod\_aws\_iam\_role) | The required annotations for the IAM Roles for Service Accounts feature are added to the build pod's service account to allow it to assume the specified IAM role in the<br>specified account.  The OIDC tokens projected into the pods are configured to expire after 1 hour.  The annotations are merged with any annotations specified in the<br>build\_pod\_service\_account variable with the annotations generated by this variable taking precedence.  Role paths are not supported.    The IAM role is NOT created by the module.<br>See https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html for more details. | <pre>object(<br>    {<br>      name       = string<br>      account_id = string<br>    }<br>  )</pre> | `null` | no |
| <a name="input_build_pod_node_selector"></a> [build\_pod\_node\_selector](#input\_build\_pod\_node\_selector) | An optional map of Kubernetes labels to use as the build pods' node selectors.  The module automatically<br>includes the 'kubernetes.io/arch' and 'kubernetes.io/os' labels in the selector.<br>https://docs.gitlab.com/runner/executors/kubernetes.html#using-node-selectors | `map(string)` | `{}` | no |
| <a name="input_build_pod_node_tolerations"></a> [build\_pod\_node\_tolerations](#input\_build\_pod\_node\_tolerations) | An optional list of objects to set node tolerations on the build pods.  The object structure corresponds to the structure of the<br>toleration syntax in the Kubernetes pod spec.  The module converts the objects to the equivalent TOML in the runner configurataion file.<br><br>https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/<br>https://docs.gitlab.com/runner/executors/kubernetes.html | <pre>list(object(<br>    {<br>      key      = string<br>      operator = string<br>      value    = string<br>      effect   = string<br>    }<br>  ))</pre> | `[]` | no |
| <a name="input_build_pod_service_account"></a> [build\_pod\_service\_account](#input\_build\_pod\_service\_account) | An object containing optional attribute values to apply to the service account used for the build pods. | <pre>object(<br>    {<br>      annotations                     = optional(map(string), {})<br>      automount_service_account_token = optional(bool, false)<br>    }<br>  )</pre> | `{}` | no |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | The version of the runner Helm chart to use for the release. Must be a 0.57.x or 0.58.x version. | `string` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The name of the target EKS cluster. | `string` | n/a | yes |
| <a name="input_default_build_image"></a> [default\_build\_image](#input\_default\_build\_image) | The default image to use if the CI job does not specify one. | `string` | `"public.ecr.aws/docker/library/alpine:3.17.3"` | no |
| <a name="input_distributed_cache_bucket"></a> [distributed\_cache\_bucket](#input\_distributed\_cache\_bucket) | An object containing the name of the S3 bucket used as the runner's distributed cache as well as the AWS region where the bucket is located. | <pre>object(<br>    {<br>      name   = string<br>      region = string<br>    }<br>  )</pre> | n/a | yes |
| <a name="input_executor_iam_role_arn"></a> [executor\_iam\_role\_arn](#input\_executor\_iam\_role\_arn) | The ARN of the AWS IAM role the executor can assume.  Must have permission to access the distributed cache bucket. | `string` | n/a | yes |
| <a name="input_executor_namespace"></a> [executor\_namespace](#input\_executor\_namespace) | The name of the Kubernets namespace where the executor pod will run.  The namespace must already exist. | `string` | n/a | yes |
| <a name="input_executor_pod_annotations"></a> [executor\_pod\_annotations](#input\_executor\_pod\_annotations) | An optional map of annotations to assign to the executor pod. | `map(string)` | `{}` | no |
| <a name="input_executor_pod_resources"></a> [executor\_pod\_resources](#input\_executor\_pod\_resources) | CPU and memory settings for the executor pod. | <pre>object({<br>    limits = optional(<br>      object({<br>        cpu    = optional(string, "200m")<br>        memory = optional(string, "512Mi")<br>      }),<br>    {})<br>    requests = optional(<br>      object({<br>        cpu    = optional(string, "100m")<br>        memory = optional(string, "256Mi")<br>      }),<br>    {})<br>  })</pre> | `{}` | no |
| <a name="input_gitlab_url"></a> [gitlab\_url](#input\_gitlab\_url) | The URL the runner will use to access the Gitlab API. | `string` | `"https://gitlab.com"` | no |
| <a name="input_helper_container_resources"></a> [helper\_container\_resources](#input\_helper\_container\_resources) | CPU and memory settings for the helper container that runs in the build pod. | <pre>object({<br>    limits = optional(<br>      object({<br>        cpu               = optional(string, "1")<br>        ephemeral_storage = optional(string, "5Gi")<br>        memory            = optional(string, "1Gi")<br><br>      }),<br>    {})<br>    requests = optional(<br>      object({<br>        cpu               = optional(string, "500m")<br>        ephemeral_storage = optional(string, "5Gi")<br>        memory            = optional(string, "512Mi")<br>      }),<br>    {})<br>  })</pre> | `{}` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | An optional map of kubernetes labels to attach to every resource created by the module. | `map(string)` | `{}` | no |
| <a name="input_pod_security_standards"></a> [pod\_security\_standards](#input\_pod\_security\_standards) | Configures the levels of the pod security admission modes on the build pod namespace<br><br>https://kubernetes.io/docs/concepts/security/pod-security-admission/<br>https://kubernetes.io/docs/tasks/configure-pod-container/enforce-standards-namespace-labels/<br>https://kubernetes.io/docs/concepts/security/pod-security-standards/ | <pre>object({<br>    audit   = optional(string, "restricted")<br>    enforce = optional(string, "baseline")<br>    warn    = optional(string, "restricted")<br>  })</pre> | `{}` | no |
| <a name="input_protected_branches"></a> [protected\_branches](#input\_protected\_branches) | Set to 'true' to only run jobs on protected branches or 'false' to run jobs for any branch. | `bool` | `false` | no |
| <a name="input_runner_flavor"></a> [runner\_flavor](#input\_runner\_flavor) | An additional value for constructing resource names to differentiate between multiple runners in the same scope. | `string` | `"default"` | no |
| <a name="input_runner_image_registry"></a> [runner\_image\_registry](#input\_runner\_image\_registry) | The container image registry from which the runner and runner-helper images will be pulled.  The images must be in the gitlab/gitlab-runner and the gitlab/gitlab-runner-helper repositories, respectively.<br>The value can have an optional path suffix to support the use of ECR pull-through caches. | `string` | `"public.ecr.aws"` | no |
| <a name="input_runner_job_tags"></a> [runner\_job\_tags](#input\_runner\_job\_tags) | https://docs.gitlab.com/ee/ci/runners/configure_runners.html#use-tags-to-control-which-jobs-a-runner-can-run | `set(string)` | `[]` | no |
| <a name="input_runner_scope"></a> [runner\_scope](#input\_runner\_scope) | The scope (project, group, or instance) of jobs the runner will handle. | `string` | n/a | yes |
| <a name="input_sealed_runner_registration_token"></a> [sealed\_runner\_registration\_token](#input\_sealed\_runner\_registration\_token) | The runner's registration token as secret value sealed using kubeseal's raw mode. https://github.com/bitnami-labs/sealed-secrets#raw-mode-experimental | `string` | n/a | yes |
| <a name="input_service_container_resources"></a> [service\_container\_resources](#input\_service\_container\_resources) | CPU and memory settings for the service containers that runs the job script.  Sets default request and limit values as well as the maximum<br>allowed values that can be set in the job variables.  See https://docs.gitlab.com/runner/executors/kubernetes.html#overwriting-container-resources<br>for more on using the job variables. | <pre>object({<br>    limits = optional(<br>      object({<br>        cpu = optional(<br>          object({<br>            default = optional(string, "500m")<br>            max     = optional(string, "")<br>          }),<br>        {})<br>        ephemeral_storage = optional(<br>          object({<br>            default = optional(string, "1Gi")<br>            max     = optional(string, "")<br>          }),<br>        {})<br>        memory = optional(<br>          object({<br>            default = optional(string, "1Gi")<br>            max     = optional(string, "")<br>          }),<br>        {})<br>      }),<br>    {})<br>    requests = optional(object({<br>      cpu = optional(<br>        object({<br>          default = optional(string, "250m")<br>          max     = optional(string, "")<br>        }),<br>      {})<br>      ephemeral_storage = optional(<br>        object({<br>          default = optional(string, "1Gi")<br>          max     = optional(string, "")<br>        }),<br>      {})<br>      memory = optional(<br>        object({<br>          default = optional(string, "512Mi")<br>          max     = optional(string, "")<br>        }),<br>      {})<br>      }),<br>    {})<br>  })</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_build_pod_iam_role_name"></a> [build\_pod\_iam\_role\_name](#output\_build\_pod\_iam\_role\_name) | The name of the IAM role associated with the build pod service account or null if the build\_pod\_aws\_iam\_role variable was not assigned a value. |
| <a name="output_build_pod_namespace"></a> [build\_pod\_namespace](#output\_build\_pod\_namespace) | The name of the k8s namespace where the build pods run. |
| <a name="output_build_pod_service_account"></a> [build\_pod\_service\_account](#output\_build\_pod\_service\_account) | A map containing the name and namespace of the k8s service account created for the build pods. |
| <a name="output_build_pod_token_oidc_subject_claim"></a> [build\_pod\_token\_oidc\_subject\_claim](#output\_build\_pod\_token\_oidc\_subject\_claim) | The full value of the OIDC sub claim on the build pod service account's token. |
| <a name="output_cluster_runner_name"></a> [cluster\_runner\_name](#output\_cluster\_runner\_name) | The name of the runner that is unique within the k8s cluster. |
| <a name="output_global_runner_name"></a> [global\_runner\_name](#output\_global\_runner\_name) | The name of the runner that is globally unique across all runners registered with the Gitlab instance. |
| <a name="output_iam_eks_role_module_service_account_value"></a> [iam\_eks\_role\_module\_service\_account\_value](#output\_iam\_eks\_role\_module\_service\_account\_value) | A map suitable for use as the value of the cluster\_service\_accounts variable of version 5.2+ of the terraform-aws-modules/iam-eks-role public module. |
| <a name="output_runner_scope"></a> [runner\_scope](#output\_runner\_scope) | The value of the `runner_scope` variable. |
<!-- END_TF_DOCS -->
