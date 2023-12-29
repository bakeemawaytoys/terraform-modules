terraform {

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.9"
    }

  }
  required_version = ">= 1.4"
}

locals {
  labels = merge(
    var.labels,
    {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  )
}

resource "helm_release" "metrics_server" {
  atomic           = true
  chart            = "metrics-server"
  cleanup_on_fail  = true
  create_namespace = false
  max_history      = 5
  name             = "metrics-server"
  namespace        = "kube-system"
  recreate_pods    = true
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  version          = var.chart_version

  values = [
    yamlencode(
      {
        commonLabels = local.labels
        image = {
          repository = "${var.image_registry}/metrics-server/metrics-server"
        }
        metrics = {
          enabled = true
        }
        nodeSelector = var.node_selector
        podDisruptionBudget = {
          enabled      = true
          minAvailable = 1
        }
        replicas  = var.replicas
        resources = var.pod_resources
        service = {
          labels = {
            # According to a comment in the chart's values file, adding these two labels will allow the metrics-server to show up in `kubectl cluster-info`
            "kubernetes.io/cluster-service" = "true"
            "kubernetes.io/name"            = "Metrics-server"
          }
        }
        serviceMonitor = {
          enabled = var.enable_service_monitor
        }
        tolerations = concat(
          [
            # Include default tolerations for the standard architecture label to support clusters with mixed architectures
            {
              effect   = "NoSchedule"
              key      = "kubernetes.io/arch"
              operator = "Exists"
            },
          ],
          var.node_tolerations,
        )
      }
  )]
}
