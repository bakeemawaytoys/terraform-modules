terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.11"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = ">= 3.20"
    }
  }

  required_version = ">= 1.6"
}

locals {
  release_name = "kube-prometheus-stack"
  labels = merge(
    {
      "app.kubernetes.io/managed-by" = "terraform"
    },
    var.labels,
  )

  component_labels = {
    "alertmanager" = merge(
      local.labels,
      # Add standard labels to match the resources managed by Helm
      {
        "app"                         = "${local.release_name}-alertmanager"
        "app.kubernetes.io/component" = "alertmanager"
        "app.kubernetes.io/instance"  = local.release_name
        "app.kubernetes.io/name"      = "${local.release_name}-alertmanager"
        "app.kubernetes.io/part-of"   = local.release_name
        "app.kubernetes.io/version"   = var.chart_version
      },
    )
    "grafana" = merge(
      local.labels,
      # Add standard labels to match the resources managed by Helm
      {
        "app.kubernetes.io/instance" = local.release_name
        "app.kubernetes.io/name"     = "grafana"
      },
    )
  }

  vault_metadata = merge(
    var.vault_metadata,
    {
      managed_with = "terraform"
    }
  )

  prometheus_images = {
    for repo in ["prometheus/node-exporter", "prometheus/prometheus"] : repo =>
    { registry = var.prometheus_pod_configuration.image_registry, image = repo, }
  }

  prometheus_operator_images = { for repo in ["prometheus-operator/prometheus-config-reloader", "prometheus-operator/prometheus-operator"] : repo =>
    { registry = var.prometheus_operator_pod_configuration.image_registry, image = repo, }
  }

  required_node_selector = {
    "kubernetes.io/os" = "linux"
  }


  required_node_tolerations = [
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
  ]
}

#################################
# Vault Resources
#################################

# Create service service accounts with Terraform instead of Helm so that their name and UID can be used
# to create Vault resources.
resource "kubernetes_service_account_v1" "static_secrets" {
  for_each = toset([
    "alertmanager",
    "grafana",
  ])
  metadata {
    annotations = {
      # Ensure Helm doesn't delete the service accounts when transitioning ownership of service accounts from Helm to Terraform
      "helm.sh/resource-policy" = "keep"
    }
    labels    = local.component_labels[each.key]
    name      = "${local.release_name}-${each.value}"
    namespace = var.namespace
  }

  automount_service_account_token = false
}

# Bind the service account to the system:auth-delegator cluster role so that the service account tokens can be used as the
# as the Vault k8s auth backend's token review JWT.
resource "kubernetes_cluster_role_binding_v1" "static_secrets" {
  metadata {
    labels = local.labels
    name   = local.release_name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "system:auth-delegator"
  }

  dynamic "subject" {
    for_each = kubernetes_service_account_v1.static_secrets
    content {
      kind      = "ServiceAccount"
      name      = subject.value.metadata[0].name
      namespace = subject.value.metadata[0].namespace
    }
  }
}

data "vault_auth_backend" "kubernetes" {
  path = var.vault_auth_backend_path
  lifecycle {
    postcondition {
      condition     = self.type == "kubernetes"
      error_message = "The vault_auth_backend_path variable must refer to a Kuberntes auth backend."
    }
  }
}

data "vault_policy_document" "static_secrets" {
  for_each = {
    "alertmanager" = toset([
      var.alertmanager_slack_vault_kv_secret.path
    ])
    "grafana" = toset([
      var.grafana_admin_user_vault_kv_secret.path,
      var.grafana_ldap_config_vault_kv_secret.path,
    ])
  }

  # The policy data resource does not provide a way to insert comments outside the context of a rule.
  # To work around this limitation, add a rule for a path that cannot exist in Vault and use its
  # description argument as documentation for the entire policy.
  rule {
    capabilities = ["deny"]

    # The '#' character is included in all but the first line because, as of version 3.15, the Vault provider
    # does not insert the leading '#' beyond the first line.
    description = <<-EOF
    This policy is managed by Terraform.
    # ----- Metadata -----
    %{for k, v in local.vault_metadata~}# ${k}: ${v}
    %{endfor~}# --------------------
    EOF
    path        = "~~~ POLICY DOCUMENTATION  ~~~"
  }

  dynamic "rule" {
    for_each = each.value
    content {
      capabilities = ["read"]
      path         = rule.value
    }
  }
}

resource "vault_policy" "static_secrets" {
  for_each = data.vault_policy_document.static_secrets
  # Prefix the policy name with the auth backend to avoid naming collisions.  Policies are global in Vault but roles are unique to an auth backend.
  name   = "${data.vault_auth_backend.kubernetes.path}-${kubernetes_service_account_v1.static_secrets[each.key].metadata[0].name}"
  policy = each.value.hcl
}

moved {
  from = vault_policy.static_secrets["kube-prometheus-stack-alertmanager"]
  to   = vault_policy.static_secrets["alertmanager"]
}

moved {
  from = vault_policy.static_secrets["kube-prometheus-stack-grafana"]
  to   = vault_policy.static_secrets["grafana"]
}

resource "vault_kubernetes_auth_backend_role" "static_secrets" {
  for_each                         = kubernetes_service_account_v1.static_secrets
  backend                          = data.vault_auth_backend.kubernetes.path
  role_name                        = each.value.metadata[0].name
  bound_service_account_names      = [each.value.metadata[0].name]
  bound_service_account_namespaces = [each.value.metadata[0].namespace]
  token_policies                   = [vault_policy.static_secrets[each.key].name]
  # Keep the token TTL short to limit the number of live leases when secrets auto rotation is enabled.
  # Apparently it creates a new Vault token every time it syncs
  # https://github.com/hashicorp/vault-csi-provider/issues/150
  # https://secrets-store-csi-driver.sigs.k8s.io/topics/secret-auto-rotation.html
  # https://github.com/hashicorp/vault-csi-provider/issues/151
  token_max_ttl = 60 * 5

  depends_on = [
    kubernetes_cluster_role_binding_v1.static_secrets
  ]
}

moved {
  from = vault_kubernetes_auth_backend_role.static_secrets["kube-prometheus-stack-alertmanager"]
  to   = vault_kubernetes_auth_backend_role.static_secrets["alertmanager"]
}

moved {
  from = vault_kubernetes_auth_backend_role.static_secrets["kube-prometheus-stack-grafana"]
  to   = vault_kubernetes_auth_backend_role.static_secrets["grafana"]
}

resource "vault_identity_entity" "static_secrets" {
  for_each = vault_kubernetes_auth_backend_role.static_secrets
  # Prefix the policy name with the auth backend to avoid naming collisions.
  name     = "${each.value.backend}-${each.key}"
  metadata = local.vault_metadata
}

resource "vault_identity_entity_alias" "static_secrets" {
  for_each     = vault_identity_entity.static_secrets
  canonical_id = each.value.id
  custom_metadata = merge(
    local.vault_metadata,
    {
      entity_name              = each.value.name
      backend_role_name        = vault_kubernetes_auth_backend_role.static_secrets[each.key].role_name
      k8s_service_account_name = kubernetes_service_account_v1.static_secrets[each.key].metadata[0].name
    }
  )
  mount_accessor = data.vault_auth_backend.kubernetes.accessor
  name           = kubernetes_service_account_v1.static_secrets[each.key].metadata[0].uid
}

###################################################
# Install the Custom Resource Definitions
# https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack#upgrading-chart
###################################################
locals {
  chart_major_version = split(".", var.chart_version)[0]
  # Map the major version of the Helm chart to the version of the Prometheus Operator CRDs it supports
  crd_version_mapping = {
    "51" = "v0.68.0"
    "52" = "v0.68.0"
    "53" = "v0.69.1"
    "54" = "v0.69.1"
    "55" = "v0.70.0"
  }
  crd_directory = "${path.module}/files/crds/${local.crd_version_mapping[local.chart_major_version]}"
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

####################################
# Alert Manager
####################################

locals {
  alertmanager_resource_name             = "${local.release_name}-alertmanager"
  alertmanager_secret_slack_api_url_file = "slack-api-url"
}

resource "kubectl_manifest" "alertmanager_secret_provider" {
  yaml_body = yamlencode({
    apiVersion = "secrets-store.csi.x-k8s.io/v1"
    kind       = "SecretProviderClass"
    metadata = {
      labels    = local.labels
      name      = local.alertmanager_resource_name
      namespace = var.namespace
    }
    spec = {
      provider = "vault"
      parameters = {
        roleName = vault_kubernetes_auth_backend_role.static_secrets["alertmanager"].role_name
        objects = yamlencode(
          [
            {
              objectName = local.alertmanager_secret_slack_api_url_file
              secretPath = var.alertmanager_slack_vault_kv_secret.path
              secretKey  = var.alertmanager_slack_vault_kv_secret.slack_api_url_key
            },
          ]
        )
      }
    }
  })
}

locals {

  alertmanager_hosts              = ["alertmanager.${var.kube_base_domain}"]
  alertmanager_secrets_path       = "/mnt/secrets-store"
  alertmanager_secrets_mount_name = "vault-secrets"

  alertmanager_values = {
    alertmanager = {
      config = {
        global = {
          resolve_timeout    = "5m"
          slack_api_url_file = "${local.alertmanager_secrets_path}/${local.alertmanager_secret_slack_api_url_file}"
        }
        # The inhibit rules are copied from the Helm chart's default value for the alertmanager config.
        # https://github.com/prometheus-community/helm-charts/blob/a3b5c8ed85d034361f457545f88cb41a415e1265/charts/kube-prometheus-stack/values.yaml#L175
        # https://prometheus.io/docs/alerting/latest/configuration/#inhibit_rule
        inhibit_rules = [
          {
            source_matchers = ["severity = critical"]
            target_matchers = ["severity =~ warning|info"]
            equal = [
              "namespace",
              "alertname",
            ]
          },
          {
            source_matchers = ["severity = warning"]
            target_matchers = ["severity = info"]
            equal = [
              "namespace",
              "alertname",
            ]
          },
          {
            source_matchers = ["alertname = InfoInhibitor"]
            target_matchers = ["severity = info"]
            equal = [
              "namespace",
            ]
          }
        ]
        route = {
          group_by        = ["namespace"]
          group_wait      = "30s"
          group_interval  = "5m"
          receiver        = "null"
          repeat_interval = "2h"
          routes = [
            {
              matchers = ["alertname =~ \"InfoInhibitor|Watchdog\""]
              receiver = "null"
            },
            {
              matchers = null
              receiver = "slack"
              continue = true
            },
          ]
        }
        receivers = [
          {
            name = "null"
          },
          {
            name = "slack"
            slack_configs = [
              {
                channel       = var.alertmanager_slack_vault_kv_secret.slack_channel
                send_resolved = true
                title         = "[{{ .Status | toUpper }}{{ if eq .Status \"firing\" }}:{{ .Alerts.Firing | len }}{{ end }}] Monitoring Event Notification"
                text          = <<-EOF
                  {{ range .Alerts }}
                    *Alert:* {{ .Annotations.summary }} - `{{ .Labels.severity }}`
                    *Description:* {{ .Annotations.description }}
                    *Graph:* <{{ .GeneratorURL }}|:chart_with_upwards_trend:>
                    *Details:*
                    {{ range .Labels.SortedPairs }} • *{{ .Name }}:* `{{ .Value }}`
                    {{ end }}
                  {{ end }}
                  EOF
              }
            ]
          }
        ],
        templates = [
          "/etc/alertmanager/config/*.tmpl"
        ]
      }
      ingress = {
        enabled          = true
        ingressClassName = var.ingress_class_name
        annotations = {
          "cert-manager.io/cluster-issuer" = var.cluster_cert_issuer_name
        }
        labels   = local.labels
        hosts    = local.alertmanager_hosts
        paths    = ["/"]
        pathType = "Prefix"
        tls = [
          {
            secretName = "alertmanager-tls"
            hosts      = local.alertmanager_hosts
          }
        ]
      }
      serviceAccount = {
        create = false
        name   = kubernetes_service_account_v1.static_secrets["alertmanager"].metadata[0].name
      }
      alertmanagerSpec = {
        image = {
          image    = "prometheus/alertmanager"
          registry = var.alertmanager_pod_configuration.image_registry
        }
        logFormat    = "json"
        nodeSelector = merge(var.alertmanager_pod_configuration.node_selector, local.required_node_selector)
        podMetadata = {
          annotations = {
            # Fargate does not support stateful sets.  Adding this annotation will ensure the pods are never scheduled on Fargate node.
            "eks.amazonaws.com/compute-type" = "ec2"
          }
        }
        priorityClassName = "system-cluster-critical"
        resources         = var.alertmanager_pod_configuration.resources
        storage = {
          volumeClaimTemplate = {
            spec = {
              storageClassName = "gp2"
              accessModes      = ["ReadWriteOnce"]
              resources = {
                requests = {
                  storage = "${var.alertmanager_pod_configuration.volume_size}Gi"
                }
              }
            }
          }
        }
        tolerations = concat(local.required_node_tolerations, var.alertmanager_pod_configuration.node_tolerations)
        volumes = [
          {
            name = local.alertmanager_secrets_mount_name
            csi = {
              driver   = "secrets-store.csi.k8s.io"
              readOnly = true
              volumeAttributes = {
                secretProviderClass = kubectl_manifest.alertmanager_secret_provider.name
              }
            }
          }
        ]
        volumeMounts = [
          {
            name      = local.alertmanager_secrets_mount_name
            mountPath = local.alertmanager_secrets_path
            readOnly  = true
          }
        ]
      }
    }
  }
}

####################################
# Grafana
####################################

# Create a shared namespace dedicated to configmaps containing Grafana dashboards.
resource "kubernetes_namespace_v1" "grafana_dashboards" {
  metadata {
    labels = local.component_labels["grafana"]
    name   = "grafana-dashboards"
  }
}

# Use a resource quota to prevent the creation of workload resoruces in the namespace
resource "kubernetes_resource_quota_v1" "grafana_dashboards" {
  metadata {
    labels    = local.component_labels["grafana"]
    name      = "block-workloads"
    namespace = kubernetes_namespace_v1.grafana_dashboards.metadata[0].name
  }

  spec {
    hard = {
      "count/cronjobs.batch"         = 0
      "count/deployments.apps"       = 0
      "count/jobs.batch"             = 0
      "count/persistentvolumeclaims" = 0
      "count/pods"                   = 0
      "count/replicasets.apps"       = 0
      "count/replicationcontrollers" = 0
      "count/services"               = 0
      "count/statefulsets.apps"      = 0
    }
  }
}

# Create a role to grant permission to monitor the configmaps
resource "kubernetes_role_v1" "grafana_dashboards" {
  metadata {
    labels    = local.component_labels["grafana"]
    name      = "grafana-sidecar"
    namespace = kubernetes_namespace_v1.grafana_dashboards.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["get", "watch", "list"]
  }
}

# Bind the role to the Grafana service account.  So that the sidecar running in the Grafana pod can monitor the configmaps.
resource "kubernetes_role_binding_v1" "grafana_dashboards" {
  metadata {
    labels    = local.component_labels["grafana"]
    name      = "grafana-sidecar"
    namespace = kubernetes_namespace_v1.grafana_dashboards.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.grafana_dashboards.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.static_secrets["grafana"].metadata[0].name
    namespace = kubernetes_service_account_v1.static_secrets["grafana"].metadata[0].namespace
  }
}

locals {
  grafana_resource_name = "${local.release_name}-grafana"

  # Define local values to simplify references between the Helm values and the SecretProviderClass manifest
  grafana_secret = {
    name = local.grafana_resource_name
    admin_username = {
      k8s_secret_key = "admin-username"
      object_name    = "grafana-admin-username"
    }
    admin_password = {
      k8s_secret_key = "admin-password"
      object_name    = "grafana-admin-password"
    }
    ldap_config = {
      object_name = "ldap.toml"
    }
  }
}

resource "kubectl_manifest" "grafana_secret_provider" {

  yaml_body = yamlencode({
    apiVersion = "secrets-store.csi.x-k8s.io/v1"
    kind       = "SecretProviderClass"
    metadata = {
      labels    = local.labels
      name      = local.grafana_resource_name
      namespace = var.namespace
    }
    spec = {
      provider = "vault"
      secretObjects = [
        # Create a k8s secret so that the admin credentials can be injected as environment variables
        {
          data = [
            {
              objectName = local.grafana_secret.admin_username.object_name
              key        = local.grafana_secret.admin_username.k8s_secret_key
            },
            {
              objectName = local.grafana_secret.admin_password.object_name
              key        = local.grafana_secret.admin_password.k8s_secret_key
            },
          ]
          labels = merge(
            local.labels,
            {
              "app.kubernetes.io/managed-by" = "vault-csi-provider"
            }
          )
          secretName = local.grafana_secret.name
          type       = "Opaque"
        }
      ]
      parameters = {
        roleName = vault_kubernetes_auth_backend_role.static_secrets["grafana"].role_name
        objects = yamlencode(
          [
            {
              objectName = local.grafana_secret.admin_username.object_name
              secretPath = var.grafana_admin_user_vault_kv_secret.path
              secretKey  = var.grafana_admin_user_vault_kv_secret.username_key
            },
            {
              objectName = local.grafana_secret.admin_password.object_name
              secretPath = var.grafana_admin_user_vault_kv_secret.path
              secretKey  = var.grafana_admin_user_vault_kv_secret.password_key
            },
            {
              objectName = local.grafana_secret.ldap_config.object_name
              secretPath = var.grafana_ldap_config_vault_kv_secret.path
              secretKey  = var.grafana_ldap_config_vault_kv_secret.toml_key
            }
          ]
        )
      }
    }
  })
}

locals {
  grafana_host_name    = "grafana.${var.kube_base_domain}"
  grafana_hosts        = [local.grafana_host_name]
  grafana_secrets_path = "/mnt/secret-store"

  # Define a local for the key of the label the side car will look for when searching for configmaps containing dashboards.
  # A local isn't strictly necessary because the value is the same as the default in the chart but the value has to be referenced
  # in multiple locations in the module.
  dashboard_label_key   = "grafana_dashboard"
  dashboard_label_value = "1"

  # The annotation the sidecar will look for in configmaps to override the destination folder for files.
  dashboard_folder_annotation_key = "dashboards.grafana.com/folder"

  # Grafana chart values
  # https://github.com/grafana/helm-charts/tree/main/charts/grafana
  grafana_values = {
    grafana = {
      admin = {
        existingSecret = local.grafana_secret.name
        passwordKey    = local.grafana_secret.admin_password.k8s_secret_key
        userKey        = local.grafana_secret.admin_username.k8s_secret_key
      }
      extraLabels = local.labels
      # The extraSecretMounts value is used by the chart to define both the Volume and VolumeMount in the pod spec
      extraSecretMounts = [
        {
          name      = "grafana-secrets"
          mountPath = local.grafana_secrets_path
          readOnly  = true
          csi = {
            driver   = "secrets-store.csi.k8s.io"
            readOnly = true
            volumeAttributes = {
              "secretProviderClass" = kubectl_manifest.grafana_secret_provider.name
            }
          }
        }
      ]

      "grafana.ini" = {
        "auth.ldap" = {
          enabled       = true
          allow_sign_up = true
          config_file   = "${local.grafana_secrets_path}/${local.grafana_secret.ldap_config.object_name}"
        }
        "log.console" = {
          format = "json"
        }
        server = {
          root_url = "https://${local.grafana_host_name}/"
        }
        users = {
          # Allow viewer to use the Explore UI. https://grafana.com/docs/grafana/latest/explore/#start-exploring
          viewers_can_edit = true
        }
      }
      image = {
        registry = var.grafana_pod_configuration.image_registry
      }
      ldap = {
        # This does not disable Grafana's LDAP support, it disables the Grafana chart's logic to add secret mounts to the manifest.
        # The ldap config file will be mounted as a CSI volume so there is no need to add secret mounts.
        enabled = false
      }
      nodeSelector = merge(var.grafana_pod_configuration.node_selector, local.required_node_selector)
      # The polystat plug-in is installed for the Gitlab Pipeline Exporter dashboards
      # https://github.com/mvisonneau/gitlab-ci-pipelines-exporter
      # https://grafana.com/grafana/dashboards/10620-gitlab-ci-pipelines/
      plugins           = ["grafana-polystat-panel"]
      priorityClassName = "system-cluster-critical"
      rbac = {
        # Set namespaced to true to prevent the creation of a cluster role.
        # A cluster role is only required when the sidecar monitors all namespaces.
        namespaced = true
      }
      resources = var.grafana_pod_configuration.resources
      sidecar = {
        dashboards = {
          env = {
            LOG_TZ = "UTC"
          }
          folderAnnotation = local.dashboard_folder_annotation_key
          label            = local.dashboard_label_key
          labelValue       = local.dashboard_label_value
          provider = {
            # Allow the folder annotation to dictate the Grafana folder structure
            foldersFromFilesStructure = true
          }
          resource = "configmap"
          searchNamespace = [
            var.namespace,
            kubernetes_namespace_v1.grafana_dashboards.metadata[0].name
          ]
        }
        # Until a use case presents itself, custom datasources will not be supported.
        # The datasource sidecar will be limited to Grafana's namespace.
        datasources = {
          env = {
            LOG_TZ = "UTC"
          }
          # Set the resource to configmap instead of both to limit the exposure of secrets
          resource = "configmap"
        }
        # Prevent naming collisions
        enableUniqueFilenames = true
        resources = {
          limits = {
            cpu    = "50m"
            memory = "128Mi"
          }
          requests = {
            cpu    = "50m"
            memory = "128Mi"
          }
        }
        securityContext = {
          allowPrivilegeEscalation = false
          capabilities = {
            drop = ["all"]
          }
          privileged             = false
          readOnlyRootFilesystem = true
          runAsNonRoot           = true
        }
      }
      serviceAccount = {
        # The service account token must be available for the Vault CSI provider to use for Vault authentication
        # https://developer.hashicorp.com/vault/docs/platform/k8s/csi#authenticating-with-vault
        autoMount = true
        create    = false
        name      = kubernetes_service_account_v1.static_secrets["grafana"].metadata[0].name
      }
      testFramework = {
        enabled = false
      }
      tolerations = concat(local.required_node_tolerations, var.grafana_pod_configuration.node_tolerations)
      ingress = {
        enabled          = true
        ingressClassName = var.ingress_class_name
        annotations = {
          "cert-manager.io/cluster-issuer" = var.cluster_cert_issuer_name
        }
        hosts = local.grafana_hosts
        tls = [
          {
            secretName = "grafana-tls"
            hosts      = local.grafana_hosts
          }
        ]
      }
    }
  }
}

locals {

  prometheus_hosts = ["prometheus.${var.kube_base_domain}"]
  prometheus_port  = 9090

  prometheus_values = {
    # Values for the prometheus-node-exporter subchart
    prometheus-node-exporter = {
      affinity = {
        # Prevent scheduling on Fargate nodes
        nodeAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = {
            nodeSelectorTerms = [
              {
                matchExpressions = [
                  {
                    key      = "eks.amazonaws.com/compute-type"
                    operator = "NotIn"
                    values   = ["fargate"]
                  }
                ]
              }
            ]
          }
        }
      }
      image             = local.prometheus_images["prometheus/node-exporter"]
      priorityClassName = "system-node-critical"
      resources = {
        limits = {
          cpu    = "50m"
          memory = "128Mi"
        }
        requests = {
          cpu    = "50m"
          memory = "128Mi"
        }
      }
    }
    # Values for the prometheusOperator subchart
    prometheusOperator = {
      image        = local.prometheus_operator_images["prometheus-operator/prometheus-operator"]
      logFormat    = "json"
      resources    = var.prometheus_operator_pod_configuration.resources
      nodeSelector = merge(var.prometheus_operator_pod_configuration.node_selector, local.required_node_selector)
      prometheusConfigReloader = {
        image = local.prometheus_operator_images["prometheus-operator/prometheus-config-reloader"]
        resources = {
          requests = {
            cpu    = "100m"
            memory = "64Mi"
          }
          limits = {
            cpu    = "100m"
            memory = "64Mi"
          }
        }
      }
      tolerations = concat(local.required_node_tolerations, var.prometheus_operator_pod_configuration.node_tolerations)
    }
    # Values for the prometheus subchart
    prometheus = {
      ingress = {
        enabled          = true
        ingressClassName = var.ingress_class_name
        annotations = {
          "cert-manager.io/cluster-issuer" = var.cluster_cert_issuer_name
        }
        labels   = local.labels
        hosts    = local.prometheus_hosts
        paths    = ["/"]
        pathType = "Prefix"
        tls = [
          {
            secretName = "prometheus-general-tls"
            hosts      = local.prometheus_hosts
          }
        ]
      }
      prometheusSpec = {
        image        = local.prometheus_images["prometheus/prometheus"]
        logFormat    = "json"
        nodeSelector = merge(var.prometheus_pod_configuration.node_selector, local.required_node_selector)
        podMetadata = {
          annotations = {
            # Fargate does not support stateful sets.  Adding this annotation will ensure the Prometheus pods are never scheduled on Fargate node.
            "eks.amazonaws.com/compute-type" = "ec2"
          }
        }
        # Load PodMonitor resources from every namespace and not just the deployment namespace
        podMonitorSelectorNilUsesHelmValues = false
        priorityClassName                   = "system-cluster-critical"
        # Load Prob resources from every namespace and not just the deployment namespace
        probeSelectorNilUsesHelmValues = false
        resources                      = var.prometheus_pod_configuration.resources
        retention                      = "90d"
        # Load PrometheusRule resources from every namespace and not just the deployment namespace
        # https://prometheus-operator.dev/docs/user-guides/alerting/#deploying-prometheus-rules
        ruleSelectorNilUsesHelmValues = false
        service = {
          # Explicitly set the port using a local value so that outputs can reference the local.
          # This will ensure the output values are consistent with the Prometheus configuration.
          port       = local.prometheus_port
          targetPort = local.prometheus_port
        }
        # Load ServiceMonitor resources from every namespace and not just the deployment namespace
        serviceMonitorSelectorNilUsesHelmValues = false
        storageSpec = {
          volumeClaimTemplate = {
            spec = {
              storageClassName = "gp2"
              accessModes      = ["ReadWriteOnce"]
              resources = {
                requests = {
                  storage = "${var.prometheus_pod_configuration.volume_size}Gi"
                }
              }
            }
          }
        }
        tolerations = concat(local.required_node_tolerations, var.prometheus_pod_configuration.node_tolerations)
      }
    }
  }
}

####################################
# Kube State Metrics
####################################

locals {
  kube_state_metrics_values = {
    kube-state-metrics = {
      image = {
        registry = var.kube_state_metrics_pod_configuration.image_registry
      }
      nodeSelector      = merge(var.kube_state_metrics_pod_configuration.node_selector, local.required_node_selector)
      priorityClassName = "system-cluster-critical"
      replicas          = var.kube_state_metrics_pod_configuration.replica_count
      resources         = var.kube_state_metrics_pod_configuration.resources
      tolerations       = concat(local.required_node_tolerations, var.kube_state_metrics_pod_configuration.node_tolerations)
    }
  }
}

resource "helm_release" "prometheus_stack" {
  chart            = "kube-prometheus-stack"
  create_namespace = false
  max_history      = 2
  name             = local.release_name
  namespace        = var.namespace
  recreate_pods    = true
  repository       = "https://prometheus-community.github.io/helm-charts"
  # The chart doesn't deploy CRDs but just in case it suddently does some day.
  skip_crds = true
  # Double the default timeout to allow for the large number of pods in the chart that must be redeployed.
  timeout       = 10 * 60 * 60
  version       = var.chart_version
  wait_for_jobs = true

  values = [
    yamlencode(
      {
        commonLabels = local.labels
        kubeControllerManager = {
          enabled = false
        }
        kubeEtcd = {
          enabled = false
        }
        kubeScheduler = {
          enabled = false
        }
        kubeProxy = {
          enabled = false
        }
      }
    ),
    yamlencode(local.alertmanager_values),
    yamlencode(local.grafana_values),
    yamlencode(local.kube_state_metrics_values),
    yamlencode(local.prometheus_values),
  ]

  depends_on = [
    kubectl_manifest.crd,
    kubectl_manifest.grafana_secret_provider,
    kubectl_manifest.alertmanager_secret_provider,
    kubernetes_role_binding_v1.grafana_dashboards,
  ]
}
