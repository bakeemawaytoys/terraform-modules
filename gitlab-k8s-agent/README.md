# Gitlab Kubernetes Agent

## Overview

Deploys the Gitlab Kubernetes Agent using the official Helm chart.

## Installation

Prior to applying this module, [the agent configuration file must be created](https://docs.gitlab.com/ee/user/clusters/agent/install/#create-an-agent-configuration-file) and then [the agent's access token must be created](https://docs.gitlab.com/ee/user/clusters/agent/install/#register-the-agent-with-gitlab).  The access token is supplied to the module as a [sealed secret](https://github.com/bitnami-labs/sealed-secrets).  To create the sealed secret, use the [`kubeseal` CLI tool in raw mode](https://github.com/bitnami-labs/sealed-secrets#raw-mode-experimental).  The value to pass to `kubeseal`'s `--namespace` option is the same value supplied to the module's `namespace` variable.  The value to use for the `--name` option is `gitlab-agent-project-{project_id}-{agent_name}` where `{project_id}` is numeric identifier of the Gitlab project the agent will be registered with and the `{agent_name}` is the name selected when creating the agent configuration file.  For example, if the project's ID is `234`, the agent's name is `production`, and the agent will run in the `gitlab` namespace, then the basic command to seal the agent's token will look like the following.

```shell
 echo -n 'generated agent token' | kubeseal --raw --namespace gitlab --name gitlab-agent-project-234-production
```

## References

* [Agent end-user documentation](https://docs.gitlab.com/ee/user/clusters/agent/)
* [Agent Helm chart repository](https://gitlab.com/gitlab-org/charts/gitlab-agent)
* [Agent source repository](https://gitlab.com/gitlab-org/cluster-integration/gitlab-agent)
* [Agent architecture](https://gitlab.com/gitlab-org/cluster-integration/gitlab-agent/-/blob/master/doc/architecture.md)
* [Solutions to the "rpc error: code = Internal desc = stream terminated by RST_STREAM with error code: PROTOCOL_ERROR" error in the agent logs.](https://gitlab.com/gitlab-org/cluster-integration/gitlab-agent/-/issues/19)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.4 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.9.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.23 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.9.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.23 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_access_token"></a> [access\_token](#module\_access\_token) | ../sealed-secret | n/a |

## Resources

| Name | Type |
|------|------|
| [helm_release.agent](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_cluster_role_binding_v1.user_impersonation_cluster_resources](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding_v1) | resource |
| [kubernetes_cluster_role_v1.user_impersonation_cluster_resources](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_v1) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_agent_name"></a> [agent\_name](#input\_agent\_name) | The name of the agent as it appears in the Gitlab UI.  Corresponds to the name of the directory in the project's repository under the path .gitlab/agents that was used to generate the access token. | `string` | n/a | yes |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | The version of the agent's Helm chart to use for the release. Supported versions are 1.20.x and 1.21.x | `string` | n/a | yes |
| <a name="input_gitlab_hostname"></a> [gitlab\_hostname](#input\_gitlab\_hostname) | The hostname of the Gitlab instance the agent will connect to. | `string` | `"gitlab.com"` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | An optional map of kubernetes labels to attach to every resource created by the module. | `map(string)` | `{}` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | The existing namespace where the agent will be deployed. | `string` | `"gitlab-agent"` | no |
| <a name="input_node_selector"></a> [node\_selector](#input\_node\_selector) | An optional map of node labels to use the node selector of all pods. | `map(string)` | `{}` | no |
| <a name="input_node_tolerations"></a> [node\_tolerations](#input\_node\_tolerations) | An optional list of objects to set node tolerations on all pods.  The object structure corresponds to the structure of the<br>toleration syntax in the Kubernetes pod spec.<br><br>https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/ | <pre>list(object(<br>    {<br>      key      = string<br>      operator = string<br>      value    = optional(string)<br>      effect   = string<br>    }<br>  ))</pre> | `[]` | no |
| <a name="input_pod_resources"></a> [pod\_resources](#input\_pod\_resources) | CPU and memory settings for the pods. | <pre>object(<br>    {<br>      limits = optional(object(<br>        {<br>          cpu    = optional(string, "200m")<br>          memory = optional(string, "256Mi")<br>        }<br>        ),<br>      {})<br>      requests = optional(<br>        object(<br>          {<br>            cpu    = optional(string, "100m")<br>            memory = optional(string, "128Mi")<br>          }<br>        ),<br>      {})<br>    }<br>  )</pre> | `{}` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The unique numeric identifier of the Gitlab project that was used to generate the access token. | `number` | n/a | yes |
| <a name="input_sealed_access_token"></a> [sealed\_access\_token](#input\_sealed\_access\_token) | The access token the agent uses to register with Gitlab.  Must be sealed with the Bitnami Sealed Secrets<br>controller using the kubeseal tool in raw mode.  The name of the secret is the value of the 'name' variable<br>and the namespace of the secert is the value of the 'namespace' variable. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_service_account"></a> [service\_account](#output\_service\_account) | The name and namespace of the k8s service account created for the agent. |
<!-- END_TF_DOCS -->
