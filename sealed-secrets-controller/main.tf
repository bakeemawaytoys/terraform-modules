terraform {
  required_providers {
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.11.0"
    }
  }
  required_version = ">= 1.5"
}


###################################################
# Install the Custom Resource Definitions
# https://docs.github.com/en/rest/repos/contents
###################################################

locals {
  chart_version_components = split(".", var.chart_version)
  crd_directory            = "${path.module}/files/crds/${local.chart_version_components[0]}.${local.chart_version_components[1]}"
}

# Use kubectl_manifest instead of kubernetes_manifest because kubernetes_manifest is buggy.
resource "kubectl_manifest" "crd" {
  for_each = fileset(local.crd_directory, "*")

  # Set this true or else TF will fail when updating a CRD that was originally created by Helm.
  force_conflicts = true
  # Server side apply must be used or else some CRDs will error out with "metadata.annotations: Too long: must have at most 262144 bytes"
  server_side_apply = true
  wait              = true
  yaml_body         = file("${local.crd_directory}/${each.key}")
}

locals {
  labels = merge(
    {
      "app.kubernetes.io/managed-by" = "terraform"
    },
    var.labels,
  )

  node_selector = merge(
    var.node_selector,
    {
      "kubernetes.io/os" = "linux"
    }
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

resource "helm_release" "sealed_secrets" {
  atomic           = true
  chart            = "sealed-secrets"
  cleanup_on_fail  = true
  create_namespace = false
  description      = "Bitnami Sealed Secrets"
  max_history      = 5
  name             = var.release_name
  namespace        = var.namespace
  recreate_pods    = true
  repository       = "https://bitnami-labs.github.io/sealed-secrets"
  version          = var.chart_version
  skip_crds        = true
  wait_for_jobs    = true

  values = [
    yamlencode(
      {
        image = {
          registry = var.image_registry
        }
        metrics = {
          dashboards = {
            create    = var.grafana_dashboard_config != null
            labels    = try(merge(local.labels, var.grafana_dashboard_config.label, {}), {})
            namespace = try(var.grafana_dashboard_config.namespace, "")
          }
          serviceMonitor = {
            enabled  = var.service_monitor.enabled
            interval = var.service_monitor.scrape_interval
            labels   = local.labels
          }
        }
        nodeSelector      = local.node_selector
        podLabels         = local.labels
        priorityClassName = "system-cluster-critical"
        rbac = {
          labels = local.labels
        }
        resources = var.pod_resources
        serviceAccount = {
          labels = local.labels
        }
        tolerations = local.node_tolerations
      }
    )
  ]

  depends_on = [
    kubectl_manifest.crd
  ]
}

# Create cluster roles for viewing and editing sealed secret resources
# The cluster role aggregation labels have been added so that access is
# implicitly granted to existing cluster roles.
resource "kubernetes_cluster_role" "sealed_secret_view" {
  metadata {
    name = "sealed-secret-view"
    labels = merge(
      local.labels, {
        "rbac.authorization.k8s.io/aggregate-to-view" = "true"
      }
    )
  }

  rule {
    api_groups = ["bitnami.com"]
    resources = [
      "sealedsecrets",
      "sealedsecrets/status",
    ]
    verbs = [
      "get",
      "list",
      "watch",
    ]
  }

  depends_on = [
    helm_release.sealed_secrets
  ]
}

resource "kubernetes_cluster_role" "sealed_secret_edit" {
  metadata {
    name = "sealed-secret-edit"
    labels = merge(
      local.labels, {
        # The edit role aggregates to the admin role so including the admin role isn't technically
        # necessary but has been added for clarity.
        "rbac.authorization.k8s.io/aggregate-to-admin" = "true"
        "rbac.authorization.k8s.io/aggregate-to-edit"  = "true"
      }
    )
  }

  rule {
    api_groups = ["bitnami.com"]
    resources = [
      "sealedsecrets",
    ]
    # The sealed secret resource supports deletecollection but it has been omitted to prevent accidental bulk deletes.
    verbs = [
      "create",
      "delete",
      "get",
      "list",
      "patch",
      "watch",
      "update",
    ]
  }

  rule {
    api_groups = ["bitnami.com"]
    resources = [
      "sealedsecrets/status",
    ]
    verbs = [
      "get",
      "list",
      "watch",
    ]
  }

  depends_on = [
    helm_release.sealed_secrets
  ]
}

##############################
# Alert Manager integration
##############################

# https://monitoring.mixins.dev/sealed-secrets/
# https://github.com/monitoring-mixins/website/blob/master/assets/sealed-secrets/alerts.yaml
locals {
  alerts = {
    "groups" = [
      {
        "name" = "sealed-secrets"
        "rules" = [
          {
            "alert" = "SealedSecretsUnsealErrorHigh"
            "annotations" = {
              "description" = "High number of errors during unsealing Sealed Secrets in {{ $labels.namespace }} namespace."
              "runbook_url" = "https://github.com/bitnami-labs/sealed-secrets"
              "summary"     = "Sealed Secrets Unseal Error High"
            }
            "expr" = <<-EOT
          sum by (reason, namespace) (rate(sealed_secrets_controller_unseal_errors_total{}[5m])) > 0

          EOT
            "labels" = {
              "severity" = "warning"
            }
          },
        ]
      },
    ]
  }
}

resource "kubectl_manifest" "alerts" {
  for_each = toset(var.enable_prometheus_rules ? ["sealed-secrets-controller"] : [])

  yaml_body = yamlencode(
    {
      apiVersion = "monitoring.coreos.com/v1"
      kind       = "PrometheusRule"
      metadata = {
        labels    = local.labels
        name      = each.key
        namespace = var.namespace
      }
      spec = local.alerts
    }
  )
  ignore_fields = [
    "metadata.annotations.prometheus-operator-validated"
  ]
}
