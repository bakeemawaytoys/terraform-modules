terraform {
  required_providers {
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.11"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23"
    }
  }
  required_version = ">= 1.6"
}

locals {
  crd_version = join(".", slice(split(".", var.chart_version), 0, 2))


  chart_name   = "flagger"
  release_name = "flagger"

  labels = merge(
    {
      "app.kubernetes.io/name"       = local.chart_name
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/instance"   = local.release_name
      "app.kubernetes.io/version"    = var.chart_version
    },
    var.labels,
  )

}

data "kubectl_file_documents" "crd" {
  content = file("${path.module}/files/crds/${local.crd_version}/crd.yaml")
}

resource "kubectl_manifest" "crd" {
  for_each = data.kubectl_file_documents.crd.manifests

  force_conflicts   = true
  server_side_apply = true
  wait              = true
  yaml_body         = each.value
}

###################################################
# Cluster roles to simplify permissions management
###################################################
locals {
  api_groups              = toset([for k, crd in kubectl_manifest.crd : yamldecode(crd.yaml_body_parsed)["spec"]["group"]])
  crd_resources           = [for k, crd in kubectl_manifest.crd : yamldecode(crd.yaml_body_parsed)["spec"]["names"]["plural"]]
  crd_status_subresources = formatlist("%s/status", local.crd_resources)

  # AlertProviders are limited to admins because they can contain senstive values in webhook URLs
  admin_resources = ["alertproviders"]

  edit_resources           = [for r in local.crd_resources : r if !contains(local.admin_resources, r)]
  edit_status_subresources = formatlist("%s/status", local.edit_resources)

  read_only_verbs = ["get", "list", "watch"]
}

resource "kubernetes_cluster_role_v1" "view_aggregate" {
  metadata {
    labels = merge(
      local.labels,
      {
        "rbac.authorization.k8s.io/aggregate-to-view" = "true"
      }
    )
    name = "flagger-view"
  }

  rule {
    api_groups = local.api_groups
    resources = concat(
      local.edit_resources,
      local.edit_status_subresources
    )
    verbs = local.read_only_verbs
  }
}

resource "kubernetes_cluster_role_v1" "edit_aggregate" {
  metadata {
    labels = merge(
      local.labels, {
        "rbac.authorization.k8s.io/aggregate-to-edit" = "true"
      }
    )
    name = "flagger-edit"
  }

  rule {
    api_groups = local.api_groups
    resources  = local.edit_resources
    verbs      = ["*"]
  }

  rule {
    api_groups = local.api_groups
    resources  = local.edit_status_subresources
    verbs      = local.read_only_verbs
  }
}

resource "kubernetes_cluster_role_v1" "admin_aggregate" {
  metadata {
    labels = merge(
      local.labels, {
        "rbac.authorization.k8s.io/aggregate-to-admin" = "true"
      }
    )
    name = "flagger-admin"
  }

  rule {
    api_groups = local.api_groups
    resources  = local.crd_resources
    verbs      = ["*"]
  }

  rule {
    api_groups = local.api_groups
    resources  = local.crd_status_subresources
    verbs      = local.read_only_verbs
  }
}

# Configmap is used along with a k8s lease resource to facilitate leader election.
# The configmap is managed by Terraform because it is not included in the Helm chart.
resource "kubernetes_config_map_v1" "leader_election" {
  metadata {
    labels    = local.labels
    name      = "${local.release_name}-leader-election"
    namespace = var.namespace
  }

  # Make the config map immutable because it should never contain data.
  immutable = true

  lifecycle {
    # Ignore the annotations because they are modified at runtime during leader election.
    ignore_changes = [metadata[0].annotations]
  }
}

locals {

  node_selector = merge(
    var.node_selector,
    {
      "kubernetes.io/os" = "linux"
    },
  )

  node_tolerations = concat(
    [
      # Include default tolerations for the standard architecture label to support clusters with mixed architectures
      {
        effect   = "NoSchedule"
        key      = "kubernetes.io/arch"
        operator = "Equal"
        value    = "amd64"
      },
      {
        effect   = "NoSchedule"
        key      = "kubernetes.io/arch"
        operator = "Equal"
        value    = "arm64"
      },
    ],
    var.node_tolerations,
  )
}

resource "helm_release" "this" {
  atomic           = true
  cleanup_on_fail  = true
  create_namespace = false
  chart            = local.chart_name
  description      = "Flagger is a progressive delivery Kubernetes operator"
  max_history      = 2
  name             = "flagger"
  namespace        = var.namespace
  skip_crds        = true
  recreate_pods    = true
  repository       = "https://flagger.app"
  version          = var.chart_version
  wait             = true
  wait_for_jobs    = true

  values = [
    yamlencode({
      clusterName = var.cluster_name
      leaderElection = {
        enabled      = true
        replicaCount = var.replica_count
      }
      metricsServer = var.prometheus_url
      meshProvider  = "nginx"
      nodeSelector  = local.node_selector
      logLevel      = var.log_level
      podDisruptionBudget = {
        enabled = 1 < var.replica_count
      }
      podPriorityClassName = "system-cluster-critical"
      resources            = var.pod_resources
      securityContext = {
        enabled = true
        context = {
          # The default chart values already set readOnlyRootFilesystem = true and runAsUser = 10001
          allowPrivilegeEscalation = false
          capabilities = {
            drop = ["ALL"]
          }
          seccompProfile = {
            type = "RuntimeDefault"
          }
        }
      }
      # Override the selector labels to add "tier" and "track" because they are used, in addition to "app", in the deployments created by the Gitlab auto devops chart.
      selectorLabels = join(",", ["tier", "track", "app", "name", "app.kubernetes.io/name"])
      serviceMonitor = {
        enabled     = var.service_monitor.enabled
        honorLabels = var.service_monitor.honor_labels
      }
      tolerations = local.node_tolerations
    })
  ]

  depends_on = [
    kubectl_manifest.crd,
    kubernetes_config_map_v1.leader_election,
  ]
}

locals {
  prometheus_rule_namespace_label = var.service_monitor.honor_labels ? "namespace" : "exported_namespace"
}

# https://docs.flagger.app/usage/alerting#prometheus-alert-manager
resource "kubectl_manifest" "prometheus_rule" {
  for_each = toset(var.prometheus_rule.enabled ? ["enabled"] : [])

  force_conflicts   = true
  server_side_apply = true
  wait              = true
  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      labels    = local.labels
      name      = local.release_name
      namespace = var.namespace
    }
    spec = {
      groups = [
        {
          name     = "flagger"
          interval = var.prometheus_rule.interval
          rules = [
            {
              alert = "canary_rollback"
              expr  = "flagger_canary_status > 1"
              labels = {
                severity = var.prometheus_rule.canary_rollback_serverity
              }
              annotations = {
                summary     = "Canary Deployment Rollback"
                description = "The `{{ $labels.name }}` canary deployment in the `{{ $labels.${local.prometheus_rule_namespace_label} }}` namespace has been rolled back."

              }
            },

          ]
        }
      ]
    }
  })
}
