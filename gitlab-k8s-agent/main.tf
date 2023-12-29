terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.9.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23"
    }
  }
  required_version = ">= 1.4"
}

locals {
  resource_name = "gitlab-agent-project-${var.project_id}-${var.agent_name}"
  labels = merge(
    var.labels,
    {
      "app.kubernetes.io/component" = "gitlab-agent-for-kubernetes"
      "app.kubernetes.io/part-of"   = "gitlab"
      "gitlab.com/agent-project-id" = tostring(var.project_id)
      "gitlab.com/agent-name"       = var.agent_name
    }
  )
}

module "access_token" {
  source = "../sealed-secret"

  encrypted_data = {
    token = var.sealed_access_token
  }

  labels = local.labels

  name      = local.resource_name
  namespace = var.namespace
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

resource "helm_release" "agent" {
  atomic           = true
  chart            = "gitlab-agent"
  cleanup_on_fail  = true
  create_namespace = false
  description      = <<-EOF
  Agent registered with project ${var.project_id} using the .gitlab/agents/${var.agent_name} configuration.
  EOF
  max_history      = 5
  name             = local.resource_name
  namespace        = var.namespace
  version          = var.chart_version
  recreate_pods    = true
  repository       = "https://charts.gitlab.io"
  wait             = true

  values = [
    yamlencode(
      {
        additionalLabels = local.labels
        config = {
          kasAddress = "wss://${var.gitlab_hostname}/-/kubernetes-agent/"
          secretName = module.access_token.name
        }
        nodeSelector = local.node_selector
        podLabels    = local.labels
        resources    = var.pod_resources
        securityContext = {
          allowPrivilegeEscalation = false
          capabilities = {
            drop = ["ALL"]
          }
          readOnlyRootFilesystem = true
          runAsNonRoot           = true
          seccompProfile = {
            type = "RuntimeDefault"
          }
        }
        serviceAccount = {
          # Specify the service account name so that it is predictable and can be returned as a module output value
          name = local.resource_name
        }
        tolerations = local.node_tolerations
      }
    )
  ]

  depends_on = [
    module.access_token
  ]
}


# Limited access to cluster-scoped resources.
# Primarily to enable https://docs.gitlab.com/ee/ci/environments/kubernetes_dashboard.html
resource "kubernetes_cluster_role_v1" "user_impersonation_cluster_resources" {
  metadata {
    labels = local.labels
    name   = "${local.resource_name}-user"
  }

  rule {
    api_groups = [""]
    resources  = ["namespaces"]
    verbs      = ["get", "list"]
  }

  rule {
    api_groups = ["apiextensions.k8s.io"]
    resources  = ["customresourcedefinitions"]
    verbs      = ["get", "list"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "user_impersonation_cluster_resources" {
  metadata {
    labels = local.labels
    name   = kubernetes_cluster_role_v1.user_impersonation_cluster_resources.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.user_impersonation_cluster_resources.metadata[0].name
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Group"
    name      = "gitlab:user"
  }
}
