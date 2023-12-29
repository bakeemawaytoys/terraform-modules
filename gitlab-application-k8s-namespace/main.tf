terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23"
    }
  }
  required_version = ">= 1.5"
}

locals {
  # Convert the project name and group to k8s-friendly values
  # The logic is the same as the CI_PROJECT_PATH_SLUG
  # predefined CI/CD variables https://docs.gitlab.com/ee/ci/variables/predefined_variables.html
  # https://gitlab.com/gitlab-org/gitlab/-/blob/16-1-stable-ee/lib/gitlab/utils.rb?ref_type=heads#L60
  replacement_pattern = "/[^a-z0-9]/"
  # Regex to match any leading or trailing dashses
  dash_removal_pattern = "/(^-+|-+$)/"
  project_name_slug    = replace(substr(replace(lower(var.project.name), local.replacement_pattern, "-"), 0, 62), local.dash_removal_pattern, "")
  group_name_slug      = replace(substr(replace(lower(var.project.group), local.replacement_pattern, "-"), 0, 62), local.dash_removal_pattern, "")
  resource_name        = "${local.project_name_slug}-${var.project.id}"

  required_labels = {
    "app.kubernetes.io/name"       = local.project_name_slug
    "app.kubernetes.io/managed-by" = "terraform"
  }
  labels = merge(
    var.labels,
    local.required_labels,
  )

  # https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/deploy/pod_readiness_gate/
  pod_readiness_gate_annotation = var.enable_aws_loadbalancer_controller_pod_readiness_gate ? { "elbv2.k8s.aws/pod-readiness-gate-inject" = "enabled" } : {}

  # constants for the K8s RBAC resources
  rbac_api_group          = "rbac.authorization.k8s.io"
  kubernetes_cluster_role = "ClusterRole"
  kubernetes_role         = "Role"

  kubernetes_service_account = "ServiceAccount"
  kubernetes_group           = "Group"

  apps_api_group        = "apps"
  autoscaling_api_group = "autoscaling"
  batch_api_group       = "batch"
  core_api_group        = ""
  networking_api_group  = "networking.k8s.io"

  all_verbs  = ["*"]
  read_verbs = ["get", "list", "watch"]
}


resource "kubernetes_namespace_v1" "this" {
  metadata {
    annotations = merge(
      var.metadata.annotations,
      local.pod_readiness_gate_annotation,
    )

    labels = merge(
      # The common labels are the lowest priority
      var.labels,
      # The namespace labels are next to allow overriding the common labels
      var.metadata.labels,
      # The required labels are next.
      local.required_labels,
      { for mode, level in var.pod_security_standards : "pod-security.kubernetes.io/${mode}" => level },
      {
        "app.gitlab.com/app" = "${local.group_name_slug}-${local.project_name_slug}"
        "goldilocks.fairwinds.com/enabled" : tostring(var.enable_goldilocks)
      }
    )
    name = local.resource_name
  }
}

locals {
  compute_limits_quotas   = { for k, v in var.compute_quotas.limits : "limits.${k}" => v if v != null }
  compute_requests_quotas = { for k, v in var.compute_quotas.requests : "requests.${k}" => v if v != null }
  object_quotas           = { for k, v in var.object_quotas : replace(k, "_", "") => tostring(v) if v != null }
}

resource "kubernetes_resource_quota_v1" "this" {
  metadata {
    labels    = local.labels
    name      = local.resource_name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    hard = merge(
      # Add any of the optional quotas.
      local.compute_limits_quotas,
      local.compute_requests_quotas,
      local.object_quotas,
      {
        # Block the creation of additional resource quotas
        "resourcequotas" = "1"
        # Prevent the creation of ELBs and NLBs.  Only ingresses should be used.
        "services.loadbalancers" = "0"
        # Node ports aren't needed in EKS because every pod has its own IP address in the VPC.
        "services.nodeports" = "0"
      }
    )
  }
}

resource "kubernetes_limit_range_v1" "this" {
  metadata {
    labels    = local.labels
    name      = local.resource_name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {

    limit {
      default                 = var.default_container_resources.limits
      default_request         = var.default_container_resources.requests
      max_limit_request_ratio = var.maximum_limit_request_ratio
      type                    = "Container"
    }

    limit {
      max  = var.maximum_pod_resources
      type = "Pod"
    }

    limit {
      min = {
        # The minimum EBS volume size is 1GB.
        storage = "1Gi"
      }
      type = "PersistentVolumeClaim"
    }
  }
}


#################################################################
# Service account for the application deployed in the namespace
################################################################
locals {
  iam_role_suffix = "-eks-cluster-gitlab-project-${var.project.id}"
  # Construct a name for the role that is unique across multiple clusters in the same account.  The cluster name is truncated if necessary because EKS supports names up to 100 characters.
  iam_role_name = var.application_iam_role == null ? null : coalesce(var.application_iam_role.name, "${substr(var.application_iam_role.cluster_name, 0, 64 - length(local.iam_role_suffix))}${local.iam_role_suffix}")
  iam_role_path = var.application_iam_role == null ? null : coalesce(var.application_iam_role.path, "/")
  iam_role_arn  = var.application_iam_role == null ? null : join("", ["arn:aws:iam::${var.application_iam_role.account_id}:role", local.iam_role_path, local.iam_role_name])
  iam_role_annotations = var.application_iam_role == null ? {} : {
    "eks.amazonaws.com/role-arn" = local.iam_role_arn
  }
}

resource "kubernetes_service_account_v1" "application" {
  metadata {
    annotations = local.iam_role_annotations
    labels      = local.labels
    name        = "application"
    namespace   = kubernetes_namespace_v1.this.metadata[0].name
  }
}

# Bind the service account to the system:auth-delegator cluster role so that the service account tokens can be used as the as the Vault k8s auth backend's token reviewer JWT.
resource "kubernetes_cluster_role_binding_v1" "auth_delegator" {

  metadata {
    labels = local.labels
    name   = "${local.resource_name}-auth-delegator"
  }

  role_ref {
    api_group = local.rbac_api_group
    kind      = local.kubernetes_cluster_role
    name      = "system:auth-delegator"
  }

  subject {
    kind      = local.kubernetes_service_account
    name      = kubernetes_service_account_v1.application.metadata[0].name
    namespace = kubernetes_service_account_v1.application.metadata[0].namespace
  }
}

###########################################################
# Gitlab K8s agent CI/CD job impersonation RBAC resources
# https://docs.gitlab.com/ee/user/clusters/agent/ci_cd_workflow.html
###########################################################

locals {
  # Define locals for the K8s groups assigned to the K8s tokens generated by the agent
  gitlab_k8s_group_name_prefix = "gitlab"

  # K8s groups for CI/CD job impersonation
  # https://docs.gitlab.com/ee/user/clusters/agent/ci_cd_workflow.html#impersonate-the-cicd-job-that-accesses-the-cluster
  project_k8s_group_name = join(":", [local.gitlab_k8s_group_name_prefix, "project", var.project.id])
}

# Create a least-privileged role for the CI/CD jobs
# The rules were derived from the last six months of the activity (as of 9/29/2023) for the service accounts used by the Gitlab cert-based integration.
resource "kubernetes_role_v1" "ci_cd_job_access" {
  metadata {
    labels    = local.labels
    name      = "gitlab-ci-cd-job-access"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  # core group read-only permissions
  rule {
    api_groups = [local.core_api_group]
    resources = [
      "namespaces",
      "namespaces/status",
      "persistentvolumeclaims",
      "persistentvolumeclaims/status",
      "pods",
      "pods/status",
      "services/status",
    ]
    verbs = local.read_verbs
  }

  # core group full permissions
  rule {
    api_groups = [local.core_api_group]
    resources = [
      "configmaps",
      "secrets",
      "services",
    ]
    verbs = local.all_verbs
  }

  # PVC clean-up permissions
  rule {
    api_groups = [local.core_api_group]
    resources = [
      "persistentvolumeclaims",
    ]
    verbs = ["delete"]
  }

  # apps group read-only permissions
  rule {
    api_groups = [local.apps_api_group]
    resources = [
      # According the K8s audit logs, the Gitlab cert-based integration service account lists replicasets
      "replicasets",
      "replicasets/scale",
      "replicasets/status",
      "deployments/scale",
      "deployments/status",
      "statefulsets/scale",
      "statefulsets/status",
    ]
    verbs = local.read_verbs
  }

  # apps group full permissions
  rule {
    api_groups = [local.apps_api_group]
    resources = [
      "deployments",
      "statefulsets",
    ]
    verbs = local.all_verbs
  }

  # autoscaling group full permissions
  rule {
    api_groups = [local.autoscaling_api_group]
    resources = [
      "horizontalpodautoscalers",
    ]
    verbs = local.all_verbs
  }

  # autoscaling group read permissions
  rule {
    api_groups = [local.autoscaling_api_group]
    resources = [
      "horizontalpodautoscalers/status",
    ]
    verbs = local.read_verbs
  }

  # batch group full permissions
  rule {
    api_groups = [local.batch_api_group]
    resources = [
      "cronjobs",
      "jobs",
    ]
    verbs = local.all_verbs
  }

  # batch group read permissions
  rule {
    api_groups = [local.batch_api_group]
    resources = [
      "cronjobs/status",
      "jobs/status",
    ]
    verbs = local.read_verbs
  }

  # networking group full permissions
  rule {
    api_groups = [local.networking_api_group]
    resources  = ["ingresses"]
    verbs      = local.all_verbs
  }


  # networking group full permissions
  rule {
    api_groups = [local.networking_api_group]
    resources  = ["ingresses/status"]
    verbs      = local.read_verbs
  }

  # Flagger resources for Canary deployments
  rule {
    api_groups = ["flagger.app"]
    resources = [
      "canaries",
      "metrictemplates",
    ]
    verbs = local.all_verbs
  }

  rule {
    api_groups = ["flagger.app"]
    resources = [
      "canaries/status",
      "metrictemplates/status",
    ]
    verbs = local.read_verbs
  }

  rule {
    api_groups = ["monitoring.coreos.com"]
    resources = [
      "prometheusrules",
      "servicemonitors",
    ]
    verbs = local.all_verbs
  }

  rule {
    api_groups = ["bitnami.com"]
    resources  = ["sealedsecrets"]
    verbs      = local.all_verbs
  }

  rule {
    api_groups = ["bitnami.com"]
    resources  = ["sealedsecrets/status"]
    verbs      = local.read_verbs
  }

  dynamic "rule" {
    for_each = var.additional_ci_cd_role_rules
    content {
      api_groups     = rule.value.api_groups
      resource_names = rule.value.resource_names
      resources      = rule.value.resources
      verbs          = rule.value.verbs
    }
  }
}

resource "kubernetes_role_binding_v1" "ci_cd_job_access" {
  metadata {
    labels    = local.labels
    name      = "gitlab-ci-cd-job-access"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  role_ref {
    api_group = local.rbac_api_group
    kind      = local.kubernetes_role
    name      = kubernetes_role_v1.ci_cd_job_access.metadata[0].name

  }

  subject {
    kind = local.kubernetes_group
    name = local.project_k8s_group_name
  }
}

######################################################################
# Gitlab K8s agent user impersonation RBAC resources
# https://docs.gitlab.com/16.4/ee/user/clusters/agent/user_access.html
######################################################################

locals {
  gitlab_developer_role_name  = "developer"
  gitlab_maintainer_role_name = "maintainer"
  all_gitlab_roles = [
    local.gitlab_developer_role_name,
    local.gitlab_maintainer_role_name,
  ]

  # K8s groups for Gitlab users
  # https://docs.gitlab.com/ee/user/clusters/agent/user_access.html#user-impersonation-workflow
  project_memeber_k8s_groups = { for gitlab_role in local.all_gitlab_roles : gitlab_role => join(":", [local.gitlab_k8s_group_name_prefix, "project_role", var.project.id, gitlab_role]) }
  group_member_k8s_groups    = { for gitlab_role in local.all_gitlab_roles : gitlab_role => join(":", [local.gitlab_k8s_group_name_prefix, "group_role", var.project.id, gitlab_role]) }
}

resource "kubernetes_role_binding_v1" "user_read_access" {
  metadata {
    labels    = local.labels
    name      = "gitlab-user-read-access"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  role_ref {
    api_group = local.rbac_api_group
    kind      = local.kubernetes_cluster_role
    name      = "view"
  }

  dynamic "subject" {
    for_each = local.project_memeber_k8s_groups
    content {
      kind = local.kubernetes_group
      name = subject.value
    }
  }

  dynamic "subject" {
    for_each = local.group_member_k8s_groups
    content {
      kind = local.kubernetes_group
      name = subject.value
    }
  }
}
