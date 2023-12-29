terraform {
  required_providers {

    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.9"
    }

    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.16"
    }
  }
  required_version = ">= 1.4"
}


# Fetch the chart metadata from the Gitlab chart registry to determine the version of the runner deployed by the chart version.
# Equivalent to: curl  https://charts.gitlab.io/index.yaml | yq '.entries.gitlab-runner[] | select(.version == "0.39.0") | .appVersion '
data "http" "gitlab_runner_chart" {
  url = "https://charts.gitlab.io/index.yaml"

  lifecycle {
    postcondition {
      condition     = contains([200], self.status_code)
      error_message = "HTTP ${self.status_code} response when requesting the runner Helm chart from https://charts.gitlab.io/index.yaml."
    }
  }
}

locals {

  runner_charts  = yamldecode(data.http.gitlab_runner_chart.response_body)
  runner_version = [for chart in local.runner_charts["entries"]["gitlab-runner"] : chart.appVersion if chart.version == var.chart_version][0]

  # The unique name for all runners deployed to the k8s cluster
  cluster_runner_name = "${var.runner_scope}-${var.runner_flavor}"
  # The unique name across all k8s clusters
  global_runner_name = "${var.cluster_name}-k8s-cluster-${local.cluster_runner_name}"
  # The unique name for k8s resources.
  k8s_resource_name = "gitlab-runner-${local.cluster_runner_name}"

  all_labels = merge(
    var.labels,
    {
      "app.kubernetes.io/created-by" = "terraform"
      "app.kubernetes.io/instance"   = local.global_runner_name
      "app.kubernetes.io/name"       = "gitlab-runner-executor"
      "app.kubernetes.io/part-of"    = "gitlab"
      "app.kubernetes.io/version"    = local.runner_version
    }
  )
}

# Dedicated namespace for build pods to isolate build pods as much as possible.
resource "kubernetes_namespace_v1" "build" {
  metadata {
    name = local.k8s_resource_name
    labels = merge(
      local.all_labels,
      { for mode, level in var.pod_security_standards : "pod-security.kubernetes.io/${mode}" => level },
      {
        # Golidlocks only monitors namespaces where thise label is true, but explicitly disable Goldilocks just in case.
        "goldilocks.fairwinds.com/enabled" = "false"
      }
    )
  }
}

# Use a data resource to verify that the executor namespace exists.
data "kubernetes_namespace_v1" "executor" {
  metadata {
    name = var.executor_namespace
  }
}

module "registration_token" {
  source = "../sealed-secret"

  encrypted_data = {
    runner-registration-token = var.sealed_runner_registration_token
  }

  labels = local.all_labels

  name      = local.k8s_resource_name
  namespace = data.kubernetes_namespace_v1.executor.metadata[0].name

  templated_secret_data = {
    # Event though the runner token isn't in use, it must be present in the secret because the executor pod always mounts it.
    runner-token = ""
  }
}

resource "kubernetes_service_account_v1" "executor" {
  metadata {
    annotations = {
      "eks.amazonaws.com/role-arn" = var.executor_iam_role_arn
      # Use the regional STS endpoints to support private link endpoints and reduce implicit dependencies on us-east-1
      # The regional endpoint is set to true by default on the latest EKS platforms, but not all clusters on the latest version.
      # https://docs.aws.amazon.com/eks/latest/userguide/platform-versions.html
      # https://github.com/aws/amazon-eks-pod-identity-webhook
      "eks.amazonaws.com/sts-regional-endpoints" = "true"
    }
    name      = local.k8s_resource_name
    namespace = data.kubernetes_namespace_v1.executor.metadata[0].name
    labels    = local.all_labels
  }

  # Required to access the k8s API
  automount_service_account_token = true

  secret {
    name = module.registration_token.name
  }
}

# Create a role in the build namespace and then bind it to the executor's service account
# This will allow the executor to run in one namespace but spawn the job pods in another.
# The required permissions are described at https://docs.gitlab.com/runner/executors/kubernetes.html#overwriting-kubernetes-namespace
# The permissions implemented here only support the 'attach' job execution strategy.  The legacy 'exec' strategy will not work.
resource "kubernetes_role_v1" "executor" {
  metadata {
    name      = "${local.k8s_resource_name}-executor"
    namespace = kubernetes_namespace_v1.build.metadata[0].name
    labels    = local.all_labels
  }

  rule {
    api_groups = [""]
    resources = [
      "configmaps",
      "secrets",
    ]
    verbs = [
      "create",
      "delete",
      "get",
      "update",
    ]
  }

  rule {
    api_groups = [""]
    resources = [
      "pods",
      "services",
    ]
    verbs = [
      "create",
      "delete",
      "get",
      "watch",
    ]
  }

  rule {
    api_groups = [""]
    resources = [
      "serviceaccounts"
    ]
    verbs = [
      "get",
    ]
  }

  rule {
    api_groups = [""]
    resources = [
      "pods/attach",
      # Required to read the logs on service containers.  The documentation for the kubernetes executor,
      # as of version 16.1, do not list pods/log as a resource in the required permisssions.
      # https://docs.gitlab.com/runner/executors/kubernetes.html#configure-runner-api-permissions
      "pods/log",
      "pods/exec",
    ]
    verbs = [
      "*",
    ]
  }
}

resource "kubernetes_role_binding_v1" "executor" {
  metadata {
    name      = "${local.k8s_resource_name}-executor"
    namespace = kubernetes_namespace_v1.build.metadata[0].name
    labels    = local.all_labels
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.executor.metadata[0].name
  }

  subject {
    name      = kubernetes_service_account_v1.executor.metadata[0].name
    namespace = kubernetes_service_account_v1.executor.metadata[0].namespace
    kind      = "ServiceAccount"
  }
}

locals {
  service_account_annotations = var.build_pod_aws_iam_role == null ? var.build_pod_service_account.annotations : merge(
    var.build_pod_service_account.annotations,
    {
      "eks.amazonaws.com/role-arn"               = "arn:aws:iam::${var.build_pod_aws_iam_role.account_id}:role/${var.build_pod_aws_iam_role.name}"
      "eks.amazonaws.com/sts-regional-endpoints" = "true"
      "eks.amazonaws.com/token-expiration"       = tostring(1 * 60 * 60)
    }
  )
}

# Service account for build pods
resource "kubernetes_service_account_v1" "build" {
  metadata {
    annotations = local.service_account_annotations
    name        = local.k8s_resource_name
    namespace   = kubernetes_namespace_v1.build.metadata[0].name
    labels      = local.all_labels
  }

  automount_service_account_token = var.build_pod_service_account.automount_service_account_token
}

locals {

  global_environment_variables = {
    # Enable fast zip for reduced resource consumption when packaging caches and artifacts
    FF_USE_FASTZIP = true
    # Enable artifact atestation https://docs.gitlab.com/ee/ci/runners/configure_runners.html#artifact-attestation
    RUNNER_GENERATE_ARTIFACTS_METADATA = true
  }

  # Format the map as a list of items appropriate for TOML
  global_environment_variables_list = [for k, v in local.global_environment_variables : "'${k}=${v}'"]

  build_pod_annotations = merge(
    var.build_pod_annotations.static,
    {
      "karpenter.sh/do-not-evict" = "true"
      "fluentbit.io/exclude"      = "true"
    }
  )

  kubernetes_arch = var.architecture == "x86_64" ? "amd64" : var.architecture

  build_pod_node_selector = merge(
    var.build_pod_node_selector,
    {
      "kubernetes.io/arch" = local.kubernetes_arch
      "kubernetes.io/os"   = "linux"
    }
  )

  # https://docs.gitlab.com/runner/executors/kubernetes.html#the-available-configtoml-settings
  # https://docs.gitlab.com/runner/configuration/advanced-configuration.html#the-runners-section
  # Use single quotes to disable character escapes when references Terraform values in the TOML.
  # It will prevent slashes in the Terraform values from accidentally breaking the config file.
  gitlab_runner_config_toml = <<-EOF
  [[runners]]
    environment = [${join(",", local.global_environment_variables_list)}]
    output_limit = ${16 * 1024}
    [runners.kubernetes]

      allow_privilege_escalation = false
      %{if 0 < length(var.allowed_images)}
      allowed_images = [${join(",", formatlist("\"%s\"", var.allowed_images))}]
      %{endif}

      cpu_limit = '${var.build_container_resources.limits.cpu.default}'
      cpu_limit_overwrite_max_allowed = '${var.build_container_resources.limits.cpu.max}'
      cpu_request = '${var.build_container_resources.requests.cpu.default}'
      cpu_request_overwrite_max_allowed = '${var.build_container_resources.requests.cpu.max}'

      ephemeral_storage_limit = '${var.build_container_resources.limits.ephemeral_storage.default}'
      ephemeral_storage_limit_overwrite_max_allowed = '${var.build_container_resources.limits.ephemeral_storage.max}'
      ephemeral_storage_request = '${var.build_container_resources.requests.ephemeral_storage.default}'
      ephemeral_storage_request_overwrite_max_allowed = '${var.build_container_resources.requests.ephemeral_storage.max}'

      image = '${var.default_build_image}'

      # Override the helper image to pull from the configured registry
      # https://docs.gitlab.com/runner/configuration/advanced-configuration.html#override-the-helper-image
      # https://gitlab.com/gitlab-org/gitlab-runner/blob/11-3-stable/common/version.go#L48-50
      helper_image = "${var.runner_image_registry}/gitlab/gitlab-runner-helper:${var.architecture}-v$${CI_RUNNER_VERSION}"

      helper_cpu_limit = '${var.helper_container_resources.limits.cpu}'
      helper_cpu_request = '${var.helper_container_resources.requests.cpu}'
      helper_ephemeral_storage_limit = '${var.helper_container_resources.limits.ephemeral_storage}'
      helper_ephemeral_storage_request = '${var.helper_container_resources.requests.ephemeral_storage}'
      helper_memory_limit = '${var.helper_container_resources.limits.memory}'
      helper_memory_request = '${var.helper_container_resources.requests.memory}'

      memory_limit = '${var.build_container_resources.limits.memory.default}'
      memory_limit_overwrite_max_allowed = '${var.build_container_resources.limits.memory.max}'
      memory_request = '${var.build_container_resources.requests.memory.default}'
      memory_request_overwrite_max_allowed = '${var.build_container_resources.requests.memory.max}'

      namespace = '${kubernetes_namespace_v1.build.metadata[0].name}'
      pod_annotations_overwrite_allowed = '${var.build_pod_annotations.overwrite_allowed}'
      privileged = false
      pull_policy = ["always"]

      # Ensure all resources configured for job pods are available.
      resource_availability_check_max_attempts = 5

      service_account = '${kubernetes_service_account_v1.build.metadata[0].name}'

      service_cpu_limit = '${var.service_container_resources.limits.cpu.default}'
      service_cpu_limit_overwrite_max_allowed = '${var.service_container_resources.limits.cpu.max}'
      service_cpu_request = '${var.service_container_resources.requests.cpu.default}'
      service_cpu_request_overwrite_max_allowed = '${var.service_container_resources.requests.cpu.max}'

      service_ephemeral_storage_limit = '${var.service_container_resources.limits.ephemeral_storage.default}'
      service_ephemeral_storage_limit_overwrite_max_allowed = '${var.service_container_resources.limits.ephemeral_storage.max}'
      service_ephemeral_storage_request = '${var.service_container_resources.requests.ephemeral_storage.default}'
      service_ephemeral_storage_request_overwrite_max_allowed = '${var.service_container_resources.requests.ephemeral_storage.max}'

      service_memory_limit = '${var.service_container_resources.limits.memory.default}'
      service_memory_limit_overwrite_max_allowed = '${var.service_container_resources.limits.memory.max}'
      service_memory_request = '${var.service_container_resources.requests.memory.default}'
      service_memory_request_overwrite_max_allowed = '${var.service_container_resources.requests.memory.max}'

    %{if 0 < length(var.build_pod_node_tolerations)}
    [runners.kubernetes.node_tolerations]
      "kubernetes.io/arch=${local.kubernetes_arch}" = "NoSchedule"
    %{for t in var.build_pod_node_tolerations}
      %{if t.operator == "Exists"}"${t.key}"%{else}"${t.key}=${t.value}"%{endif} = "${t.effect}"
    %{endfor}
    %{endif}

    [runners.kubernetes.pod_labels]
      "app.kubernetes.io/created-by" = '${local.cluster_runner_name}'
      "app.kubernetes.io/instance" = "gitlab-runner-job-$CI_JOB_ID"
      "app.kubernetes.io/managed-by" = '${local.cluster_runner_name}'
      "app.kubernetes.io/name"       = "gitlab-runner-job"
      "app.kubernetes.io/part-of"    = "gitlab"
      "app.kubernetes.io/version" = '${local.runner_version}'
      "gitlab.com/commit-sha" = "$CI_COMMIT_SHA"
      "gitlab.com/commit-ref-slug" = "$CI_COMMIT_REF_SLUG"
      "gitlab.com/environment" = "$CI_ENVIRONMENT_SLUG"
      "gitlab.com/job-id" = "$CI_JOB_ID"
      "gitlab.com/merge-request-id" = "$CI_MERGE_REQUEST_ID"
      "gitlab.com/project-id" = "$CI_PROJECT_ID"
      "gitlab.com/project-merge-request-id" = "$CI_MERGE_REQUEST_IID"
      "gitlab.com/project-path" = "$CI_PROJECT_PATH_SLUG"
      "gitlab.com/project-pipeline-id" = "$CI_PIPELINE_IID"
      "gitlab.com/pipeline-id" = "$CI_PIPELINE_ID"
      "gitlab.com/runner-id" = "$CI_RUNNER_ID"

    [runners.kubernetes.pod_annotations]
    %{for k, v in local.build_pod_annotations}
      '${k}' = '${v}'
    %{endfor}

    [runners.kubernetes.node_selector]
    %{for k, v in local.build_pod_node_selector}
      '${k}' = '${v}'
    %{endfor}

    [runners.kubernetes.build_container_security_context]
      run_as_group = ${var.build_container_security_context.run_as_group}
      run_as_non_root = ${var.build_container_security_context.run_as_user != 0}
      run_as_user = ${var.build_container_security_context.run_as_user}
      [runners.kubernetes.build_container_security_context.capabilities]
        drop = [${join(",", formatlist("\"%s\"", var.build_container_security_context.drop_capabilities))}]
        add = [${join(",", formatlist("\"%s\"", var.build_container_security_context.add_capabilities))}]

    [runners.kubernetes.service_container_security_context]
      run_as_non_root = true
      [runners.kubernetes.service_container_security_context.capabilities]
        drop = ["ALL"]

    [runners.cache]
      Type = "s3"
      Shared = true
      Path = "runner"
      [runners.cache.s3]
        AuthenticationType = "iam"
        BucketLocation = '${var.distributed_cache_bucket.region}'
        BucketName = '${var.distributed_cache_bucket.name}'
        ServerAddress = "s3.amazonaws.com"

  EOF
}

resource "terraform_data" "config" {
  input = {
    gitlab_runner_config_toml = local.gitlab_runner_config_toml
  }
}

resource "helm_release" "runner" {
  atomic           = true
  chart            = "gitlab-runner"
  cleanup_on_fail  = true
  create_namespace = false
  description      = "Gitlab runner ${local.global_runner_name}"
  max_history      = 5
  name             = local.cluster_runner_name
  namespace        = data.kubernetes_namespace_v1.executor.metadata[0].name
  repository       = "https://charts.gitlab.io"
  version          = var.chart_version

  values = [
    yamlencode(
      {
        checkInterval = 15
        concurrent    = 25
        # Override the fullname so that the resources created by the chart follow the naming convention of the
        # resources created by Terraform.  By default, the chart uses <release-name>-gitlab-runner as the fullname.
        # The override sets 'gitlab-runner' as a prefix instead of a suffix.  The result is that the naming convention
        # used for the override groups the runner resources together when listing them alphabetically.
        fullnameOverride = local.k8s_resource_name
        gitlabUrl        = var.gitlab_url
        image = {
          registry = var.runner_image_registry
          image    = "gitlab/gitlab-runner"
        }
        logFormat = "json"
        logLevel  = "debug"
        metrics = {
          enabled = true
        }
        podAnnotations = var.executor_pod_annotations
        podLabels      = local.all_labels
        rbac = {
          create             = false
          serviceAccountName = kubernetes_service_account_v1.executor.metadata[0].name
        }
        resources = var.executor_pod_resources
        runners = {
          config    = local.gitlab_runner_config_toml
          name      = local.global_runner_name
          protected = var.protected_branches
          secret    = module.registration_token.name
          tags      = join(",", tolist(var.runner_job_tags))
        }

        unregisterRunners = true

      }
    )
  ]

  # Ensure all dependencies have been created prior to deployment
  depends_on = [
    kubernetes_role_binding_v1.executor,
    kubernetes_service_account_v1.build,
  ]
}
