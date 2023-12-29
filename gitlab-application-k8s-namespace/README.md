# Gitlab CI/CD Kubernetes Namespace

## Overview

Manages a Kubernetes namespace that serves as the deployment target for Gitlab projects deployed by a Gitlab Auto DevOps pipeline.  It enforces resource limits, resource and object quotas, pod security standard settings, and the service account used by the application.  Under normal circumstances, Gitlab creates the namespace prior to the first deployment of the application.  The module aims to replace that behavior while also enforcing standards and reducing the steps required to setup new projects.

## Assumptions and Limitations

* The namespace is managed by the Gitlab instance with [the Gitlab Kubernetes Agent](https://docs.gitlab.com/ee/user/clusters/agent/install/index.html).
* Only one Gitlab project is deployed to the namespace.
* The Gitlab project is not deployed to any other namespace.
* The module can only be used once per Kubernetes cluster.
* The namespace can contain multiple versions of the application in separate deployments.
* The namespace can contain deployments running in different environment scopes.
* The CI/CD pipeline uses [the Gitlab auto deploy image and its Helm chart](https://gitlab.com/gitlab-org/cluster-integration/auto-deploy-image) for deployments.
* All application pods in the namespace can share a Kubernetes service account even if the pods are for separate deployments in separate environments.

## Application Service Account

The module includes a Kubernetes service account to use with the project's application pods.  The service account is named `application` to simplify project configuration and to eliminate differences across projects and environments.  The module binds the `system:auth-delegator` cluster role to the service account to support [Vault authentication with short lived Kubernetes tokens](https://developer.hashicorp.com/vault/docs/auth/kubernetes#kubernetes-1-21).

The module also supports the EKS [IAM roles for service accounts feature](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html).  If the  `application_iam_role` variable is not null, the module adds [the required annotations to the service account](https://docs.aws.amazon.com/eks/latest/userguide/associate-service-account-role.html).  The module does not create the IAM role.  Instead, it generates the IAM role name and exposes it through the `iam_role_name` output.  By not managing the IAM resources, the module maintains its focus on managing Kubernetes resources.

## Gitlab CI/CD Access

For projects using the Gitlab Kubernetes agent, [the Kubernetes impersonation token injected into their CI/CD jobs](https://docs.gitlab.com/ee/user/clusters/agent/ci_cd_workflow.html#impersonate-the-cicd-job-that-accesses-the-cluster) are only permitted to access a subset of Kubernetes resources.  The chart below lists the resource kinds that are allowed along with the verbs permitted for each resource kind.  The `additional_ci_cd_role_rules` variable allows additional rules to be added to the Kubernetes role that defines access for the CI/CD jobs.

| API Group | Kind | Get | List | Watch | Create | Patch | Update | Delete |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| bitnami.com | sealedsecrets | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| bitnami.com | sealedsecrets | ✅ | ✅ | ✅  | ❌ | ❌ | ❌ | ❌ |
| apps | deployments | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| apps | deployments/scale | ✅ | ✅ | ✅  | ❌ | ❌ | ❌ | ❌ |
| apps | deployments/status | ✅ | ✅ | ✅  | ❌ | ❌ | ❌ | ❌ |
| apps | replicasets | ✅ | ✅ | ✅  | ❌ | ❌ | ❌ | ❌ |
| apps | replicasets/scale | ✅ | ✅ | ✅  | ❌ | ❌ | ❌ | ❌ |
| apps | replicasets/status | ✅ | ✅ | ✅  | ❌ | ❌ | ❌ | ❌ |
| apps | statefulsets | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| apps | statefulsets/scale | ✅ | ✅ | ✅  | ❌ | ❌ | ❌ | ❌ |
| apps | statefulsets/status | ✅ | ✅ | ✅  | ❌ | ❌ | ❌ | ❌ |
| autoscaling | horizontalpodautoscalers | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| autoscaling | horizontalpodautoscalers/status | ✅ | ✅ | ✅  | ❌ | ❌ | ❌ | ❌ |
| batch | cronjobs | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| batch | cronjobs/status | ✅ | ✅ | ✅  | ❌ | ❌ | ❌ | ❌ |
| batch | jobs | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| batch | jobs/status | ✅ | ✅ | ✅  | ❌ | ❌ | ❌ | ❌ |
| core | configmaps | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| core | namespaces | ✅ | ✅ | ✅  | ❌ | ❌ | ❌ | ❌ |
| core | namespaces/status | ✅ | ✅ | ✅  | ❌ | ❌ | ❌ | ❌ |
| core | persistentvolumeclaims | ✅ | ✅ | ✅  | ❌ | ❌ | ❌ | ✅  |
| core | persistentvolumeclaims/status | ✅ | ✅ | ✅  | ❌ | ❌ | ❌ | ❌  |
| core | pods | ✅ | ✅ | ✅  | ❌ | ❌ | ❌ | ❌ |
| core | pods/status | ✅ | ✅ | ✅  | ❌ | ❌ | ❌ | ❌ |
| core | secrets | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| core | services | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| core | services/status | ✅ | ✅ | ✅  | ❌ | ❌ | ❌ | ❌ |
| flagger.app | canaries | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| flagger.app | canaries/status | ✅ | ✅ | ✅  | ❌ | ❌ | ❌ | ❌ |
| flagger.app | metrictemplates | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| flagger.app | metrictemplates/status | ✅ | ✅ | ✅  | ❌ | ❌ | ❌ | ❌ |
| monitoring.coreos.com | prometheusrules | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| monitoring.coreos.com | servicemonitors | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| networking.k8s.io | ingresses | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| networking.k8s.io | ingresses/status | ✅ | ✅ | ✅  | ❌ | ❌ | ❌ | ❌ |

## Gitlab User Access

In Gitlab 16, functionality was added to the Kubernetes agent [that allows it grant Gitlab users access to the Kubernetes cluster](https://docs.gitlab.com/ee/user/clusters/agent/user_access.html).  The module enables this feature by binding the Kubernetes `view` cluster role to [Kubernetes groups assigned to the impersonation tokens generated by the agent](https://docs.gitlab.com/16.4/ee/user/clusters/agent/user_access.html#configure-access-with-user-impersonation).  Gitlab users assigned either the `developer` role or the `maintainer` role in either the project or the project's group are permitted to view the resources in the namespace using this feature.

## Future work

* Additional labels and annotations containing project metadata.
* Additional Kubernetes roles and bindings for fine-grained access controls.
* Multiple application service accounts.
* Customizing the application service account's Kubernetes permissions.

## References

* [The Gitlab code that manages the resources for certificate-based integration](https://gitlab.com/gitlab-org/gitlab/-/tree/master/app/services/clusters/kubernetes)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.23 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.23 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [kubernetes_cluster_role_binding_v1.auth_delegator](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding_v1) | resource |
| [kubernetes_limit_range_v1.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/limit_range_v1) | resource |
| [kubernetes_namespace_v1.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_resource_quota_v1.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/resource_quota_v1) | resource |
| [kubernetes_role_binding_v1.ci_cd_job_access](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_binding_v1) | resource |
| [kubernetes_role_binding_v1.user_read_access](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_binding_v1) | resource |
| [kubernetes_role_v1.ci_cd_job_access](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_v1) | resource |
| [kubernetes_service_account_v1.application](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account_v1) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_ci_cd_role_rules"></a> [additional\_ci\_cd\_role\_rules](#input\_additional\_ci\_cd\_role\_rules) | A list of Kubernetes role rules allow Gitlab CI/CD jobs to manage additional resources beyond those defined by the module. | <pre>list(object({<br>    api_groups     = optional(set(string), [""])<br>    resources      = optional(set(string), [])<br>    resource_names = optional(set(string), [])<br>    verbs          = set(string)<br>  }))</pre> | `[]` | no |
| <a name="input_application_iam_role"></a> [application\_iam\_role](#input\_application\_iam\_role) | When not null, the application's Kubernetes service account is annotated to enable IAM roles for service accounts.  The module<br>generates the name for the role but IT DOES NOT create the role.  The role name is instead exposed in the outputs of the module.<br>See https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html for more details.<br><br>The account\_id attribute is the numeric identifier of the AWS account of the IAM role.<br>The cluster\_name attribute is the name of the EKS cluster containing the resources managed by this module.<br>The name attribute is an optional string that is used as the name of the role instead of the name generated by the module.<br>The path attribute is an optional string to customize the path of the IAM role.  It must start and end with a `/` character. | <pre>object(<br>    {<br>      account_id   = string<br>      cluster_name = string<br>      name         = optional(string)<br>      path         = optional(string)<br>    }<br>  )</pre> | `null` | no |
| <a name="input_compute_quotas"></a> [compute\_quotas](#input\_compute\_quotas) | Quotas to limit the total sum of compute resources that can be requested in the namespace.  All attributes are optional.<br>For more details see https://kubernetes.io/docs/concepts/policy/resource-quotas/#compute-resource-quota | <pre>object(<br>    {<br>      limits = optional(<br>        object(<br>          {<br>            cpu    = optional(string)<br>            memory = optional(string)<br>          }<br>        ),<br>      {})<br>      requests = optional(<br>        object(<br>          {<br>            cpu    = optional(string)<br>            memory = optional(string)<br>          }<br>        ),<br>      {})<br>    }<br>  )</pre> | `{}` | no |
| <a name="input_default_container_resources"></a> [default\_container\_resources](#input\_default\_container\_resources) | The default resource requests and limits for containers that don't specify any.  The values are used to configure the namespace's limit range.<br>https://kubernetes.io/docs/concepts/policy/limit-range/ | <pre>object(<br>    {<br>      limits = optional(<br>        object(<br>          {<br>            cpu               = optional(string, "250m")<br>            ephemeral-storage = optional(string, "8Gi")<br>            memory            = optional(string, "256Mi")<br>          }<br>        ),<br>      {})<br>      requests = optional(<br>        object(<br>          {<br>            cpu               = optional(string, "250m")<br>            ephemeral-storage = optional(string, "8Gi")<br>            memory            = optional(string, "256Mi")<br>          }<br>        ),<br>      {})<br>    }<br>  )</pre> | `{}` | no |
| <a name="input_enable_aws_loadbalancer_controller_pod_readiness_gate"></a> [enable\_aws\_loadbalancer\_controller\_pod\_readiness\_gate](#input\_enable\_aws\_loadbalancer\_controller\_pod\_readiness\_gate) | Determines if the AWS load balancer controller will inject a readiness gate in the pods created in the namespace.<br>https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/deploy/pod_readiness_gate/ | `bool` | `true` | no |
| <a name="input_enable_goldilocks"></a> [enable\_goldilocks](#input\_enable\_goldilocks) | Determines if Goldilocks monitors the namespace to give recommendations on tuning pod resource requests and limits.<br>https://goldilocks.docs.fairwinds.com/installation/#enable-namespace | `bool` | `true` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | An optional map of kubernetes labels to attach to every resource created by the module. | `map(string)` | `{}` | no |
| <a name="input_maximum_limit_request_ratio"></a> [maximum\_limit\_request\_ratio](#input\_maximum\_limit\_request\_ratio) | Specifies the maximum allowed ration between a resource request and its corresponding limit.  It this represents the max burst<br>for the resource.  The default for all resource types caps the limit to twice the request. | <pre>object({<br>    cpu               = optional(number, 2)<br>    ephemeral-storage = optional(number, 2)<br>    memory            = optional(number, 2)<br>  })</pre> | `{}` | no |
| <a name="input_maximum_pod_resources"></a> [maximum\_pod\_resources](#input\_maximum\_pod\_resources) | Specifies the maximum CPU and memory any one pod can use. | <pre>object(<br>    {<br>      cpu    = optional(string, "2")<br>      memory = optional(string, "2Gi")<br>    }<br>  )</pre> | `{}` | no |
| <a name="input_metadata"></a> [metadata](#input\_metadata) | An optional object for specifying additional annotations and labels to add to the namespace resource. | <pre>object({<br>    annotations = optional(map(string), {})<br>    labels      = optional(map(string), {})<br>  })</pre> | `{}` | no |
| <a name="input_object_quotas"></a> [object\_quotas](#input\_object\_quotas) | An object whose attributes are used to set resource quotas for API objects in the namespace.<br>All attributes are optional.  If an attribute is null, no quota is enforced.<br>For more details see https://kubernetes.io/docs/concepts/policy/resource-quotas/#object-count-quota | <pre>object({<br>    configmaps               = optional(number)<br>    persistent_volume_claims = optional(number)<br>    pods                     = optional(number)<br>    replication_controllers  = optional(number)<br>    secrets                  = optional(number)<br>    services                 = optional(number)<br>  })</pre> | `{}` | no |
| <a name="input_pod_security_standards"></a> [pod\_security\_standards](#input\_pod\_security\_standards) | Configures the levels of the pod security admission modes.<br><br>https://kubernetes.io/docs/concepts/security/pod-security-admission/<br>https://kubernetes.io/docs/tasks/configure-pod-container/enforce-standards-namespace-labels/<br>https://kubernetes.io/docs/concepts/security/pod-security-standards/ | <pre>object({<br>    audit   = optional(string, "restricted")<br>    enforce = optional(string, "baseline")<br>    warn    = optional(string, "restricted")<br>  })</pre> | `{}` | no |
| <a name="input_project"></a> [project](#input\_project) | The name of the Gitlab project, the name of the project's Gitlab group, and the unique numeric identifier of the group. | <pre>object({<br>    id    = number<br>    name  = string<br>    group = string<br>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_application_service_account"></a> [application\_service\_account](#output\_application\_service\_account) | An object containing the name and namespace attributes of the application's Kubernetes service account metadata. |
| <a name="output_application_service_account_name"></a> [application\_service\_account\_name](#output\_application\_service\_account\_name) | The name of the application's Kubernetes service account. |
| <a name="output_application_token_oidc_subject_claim"></a> [application\_token\_oidc\_subject\_claim](#output\_application\_token\_oidc\_subject\_claim) | The full value of the OIDC sub claim on the application service account's token. |
| <a name="output_gitlab_group_developer_member_k8s_group_name"></a> [gitlab\_group\_developer\_member\_k8s\_group\_name](#output\_gitlab\_group\_developer\_member\_k8s\_group\_name) | The name of the Kubernetes group containing members of the Gitlab project's Gitlab group assigned the developer role. |
| <a name="output_gitlab_group_maintainer_member_k8s_group_name"></a> [gitlab\_group\_maintainer\_member\_k8s\_group\_name](#output\_gitlab\_group\_maintainer\_member\_k8s\_group\_name) | The name of the Kubernetes group containing members of the Gitlab project's Gitlab group assigned the maintainer role. |
| <a name="output_gitlab_project_developer_member_k8s_group_name"></a> [gitlab\_project\_developer\_member\_k8s\_group\_name](#output\_gitlab\_project\_developer\_member\_k8s\_group\_name) | The name of the Kubernetes group containing members of the Gitlab project assigned the developer role. |
| <a name="output_gitlab_project_maintainer_member_k8s_group_name"></a> [gitlab\_project\_maintainer\_member\_k8s\_group\_name](#output\_gitlab\_project\_maintainer\_member\_k8s\_group\_name) | The name of the Kubernetes group containing members of the Gitlab project assigned the maintainer role. |
| <a name="output_group_name_slug"></a> [group\_name\_slug](#output\_group\_name\_slug) | The name of the project converted to a URL friendly value. |
| <a name="output_iam_eks_role_module_service_account_value"></a> [iam\_eks\_role\_module\_service\_account\_value](#output\_iam\_eks\_role\_module\_service\_account\_value) | A map suitable for use as the value of the cluster\_service\_accounts variable of version 5.2+ of the terraform-aws-modules/iam-eks-role public module. |
| <a name="output_iam_role_arn"></a> [iam\_role\_arn](#output\_iam\_role\_arn) | The arn of the IAM role associated with the build pod service account or null if the build\_pod\_aws\_iam\_role variable was not assigned a value. |
| <a name="output_iam_role_name"></a> [iam\_role\_name](#output\_iam\_role\_name) | The name of the IAM role associated with the build pod service account or null if the build\_pod\_aws\_iam\_role variable was not assigned a value. |
| <a name="output_iam_role_path"></a> [iam\_role\_path](#output\_iam\_role\_path) | The path of the IAM role associated with the build pod service account or null if the build\_pod\_aws\_iam\_role variable was not assigned a value. |
| <a name="output_name"></a> [name](#output\_name) | The name of the namespace. |
| <a name="output_project"></a> [project](#output\_project) | The value of the project variable augmented with the group and project name slugs. |
| <a name="output_project_name_slug"></a> [project\_name\_slug](#output\_project\_name\_slug) | The name of the project converted to a URL friendly value. |
<!-- END_TF_DOCS -->