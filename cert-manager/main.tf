terraform {

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.10"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0"
    }

  }
  required_version = ">= 1.6"
}

data "aws_region" "current" {}

data "aws_route53_zone" "zones" {
  for_each     = var.acme_dns01_route53_solvers
  name         = each.key
  private_zone = false
}

locals {

  # Create a local copy of the Route53 solvers with all PQDNs converted to FQDNs.  The attributes of the Route53 zone are also added to the map values to
  # simplify log in the places this map is used.
  acme_dns01_route53_solvers = { for name, solver in var.acme_dns01_route53_solvers : name =>
    {
      # If no names or zones are defined in the solver, then the solver is for the entire Rout53 zone.   In this case, the dns_zones list
      # will be set to a single item list containing just the name of the Route53 zone.
      dns_names    = [for n in solver.dns_names : "${n}.${name}"]
      dns_zones    = length(solver.dns_zones) == 0 && length(solver.dns_names) == 0 ? [name] : [for z in solver.dns_zones : "${z}.${name}"]
      route53_zone = data.aws_route53_zone.zones[name]
    }
  }

  # Construct a map of objects suitable for use as ACME solvers in ClusterIssuer and Issuer resources.  It will be used in module outputs.
  issuer_solvers = { for name, value in local.acme_dns01_route53_solvers : name =>
    [
      # Create a single solver for each selector type because using one solver does not work as described in https://cert-manager.io/v1.0-docs/configuration/acme/#all-together
      # does not work as expected.  Names in the dnsNames list can be validated but the names that only match the dnsZones list don't.
      for selector_type, values in { dnsNames = value.dns_names, dnsZones = value.dns_zones } :
      {
        dns01 = {
          route53 = {
            region       = data.aws_region.current.name
            hostedZoneID = value.route53_zone.zone_id
          }
        }
        selector = {
          (selector_type) = values
        }
      }
      # Do not create a solver no values are supplied
      if 0 < length(values)
    ]
  }

  labels = merge(
    {
      "app.kubernetes.io/managed-by" = "terraform"
    },
    var.labels,
  )

  owned_resource_tags = merge(
    var.tags,
    {
      "kubernetes.io/cluster"                                 = var.eks_cluster.cluster_name
      "kubernetes.io/cluster/${var.eks_cluster.cluster_name}" = "owned"
    }
  )

  service_account_name = "cert-manager"
}


resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = "cert-manager"
    labels = merge(
      local.labels,
      { for mode, level in var.pod_security_standards : "pod-security.kubernetes.io/${mode}" => level },
      {
        "goldilocks.fairwinds.com/enabled" : tostring(var.enable_goldilocks)
      }
    )
  }
}


data "aws_iam_policy_document" "trust_policy" {
  statement {
    principals {
      identifiers = [var.eks_cluster.service_account_oidc_provider_arn]
      type        = "Federated"
    }
    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]
    condition {
      test     = "StringEquals"
      values   = ["system:serviceaccount:${kubernetes_namespace_v1.this.metadata[0].name}:${local.service_account_name}"]
      variable = var.eks_cluster.service_account_oidc_subject_variable
    }
    condition {
      test     = "StringEquals"
      values   = ["sts.amazonaws.com"]
      variable = var.eks_cluster.service_account_oidc_audience_variable
    }
  }
}

resource "aws_iam_role" "service_account" {
  assume_role_policy = data.aws_iam_policy_document.trust_policy.json
  description        = "cert-manager in the ${var.eks_cluster.cluster_name} EKS cluster"
  name_prefix        = "kubernetes-cert-manager-"
  tags               = local.owned_resource_tags

  lifecycle {
    create_before_destroy = true
  }
}

# https://cert-manager.io/docs/configuration/acme/dns01/route53/
data "aws_iam_policy_document" "service_account" {
  statement {
    sid = "MonitorChanges"
    actions = [
      "route53:GetChange",
    ]
    # Route53 doesn't provide any way allow access to changes with out a wildcard.
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = [
      "arn:aws:route53:::change/*",
    ]
  }

  statement {
    sid = "ReadRecordSets"
    actions = [
      "route53:ListResourceRecordSets",
    ]
    resources = values(data.aws_route53_zone.zones)[*].arn
  }

  dynamic "statement" {
    for_each = local.acme_dns01_route53_solvers
    iterator = solver
    content {
      actions = [
        "route53:ChangeResourceRecordSets",
      ]
      resources = [
        solver.value.route53_zone.arn,
      ]
      # Limit record creation to TXT records in the cluster's base domain.
      # https://letsencrypt.org/docs/challenge-types/#dns-01-challenge
      # https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/specifying-rrset-conditions.html#route53_rrset_ConditionKeys
      # The certmanager docs don't provide any details about the specific actions it takes with Route53.  The code is
      # pretty easy to follow, though.  It is located at https://github.com/cert-manager/cert-manager/blob/master/pkg/issuer/acme/dns/route53/route53.go
      condition {
        test     = "ForAllValues:StringEquals"
        values   = ["TXT"]
        variable = "route53:ChangeResourceRecordSetsRecordTypes"
      }
      condition {
        test = "ForAllValues:StringLike"
        # Limit the record names to those specified in the solver.
        values = concat(
          # Construct a wildcard pattern for the zones to allow any record in the zones.
          # Construct exact matches for the zones to allow wildcard cert challenges to succeed.
          formatlist("_acme-challenge.*.%s", solver.value.dns_zones),
          formatlist("_acme-challenge.%s", solver.value.dns_zones),
          # Construct exact matches for the names
          formatlist("_acme-challenge.%s", solver.value.dns_names),
        )
        variable = "route53:ChangeResourceRecordSetsNormalizedRecordNames"
      }
      condition {
        test     = "ForAllValues:StringEquals"
        values   = ["DELETE", "UPSERT"]
        variable = "route53:ChangeResourceRecordSetsActions"
      }
    }

  }

  # CertManager lists the account's zones to verify that a public zone for the requested domain name exists.
  statement {
    sid       = "ZoneValidation"
    actions   = ["route53:ListHostedZonesByName"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "service_account" {
  policy = data.aws_iam_policy_document.service_account.json
  role   = aws_iam_role.service_account.name
}

###################################################
# Install the Custom Resource Definitions
###################################################
data "kubectl_file_documents" "crd" {
  content = file("${path.module}/files/crds/${var.chart_version}/cert-manager.crds.yaml")
}

# Use kubectl_manifest instaed of kubernetes_manifest because kubernetes_manifest complains that the older CRD resources contain the "status" attribute.
resource "kubectl_manifest" "crd" {
  for_each = data.kubectl_file_documents.crd.manifests

  # Set this true or else TF will fail when updating a CRD that was originally created by Helm.
  force_conflicts   = true
  server_side_apply = true
  wait              = true
  yaml_body         = each.value
}


locals {
  node_selector = {
    "kubernetes.io/os" = "linux"
  }

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

resource "helm_release" "cert_manager" {
  atomic           = true
  chart            = "cert-manager"
  cleanup_on_fail  = true
  create_namespace = false
  repository       = "https://charts.jetstack.io"
  max_history      = 5
  name             = var.release_name
  namespace        = kubernetes_namespace_v1.this.metadata[0].name
  recreate_pods    = true
  skip_crds        = true
  version          = var.chart_version
  wait_for_jobs    = true

  values = [
    yamlencode(
      {
        acmesolver = {
          image = {
            registry   = var.image_registry
            repository = "jetstack/cert-manager-acmesolver"
          }
        }
        cainjector = {
          extraArgs = [
            "--logging-format=json",
            # Limit the CA injector to cert-manager's internal components because
            # it isn't used in any other context at this time.
            # https://cert-manager.io/docs/release-notes/release-notes-1.12/#cainjector
            "--enable-apiservices-injectable=false",
            "--enable-certificates-data-source=false",
            "--enable-customresourcedefinitions-injectable=false",
            "--namespace=${kubernetes_namespace_v1.this.metadata[0].name}",
          ]
          image = {
            registry   = var.image_registry
            repository = "jetstack/cert-manager-cainjector"
          }
          podDisruptionBudget = {
            enabled = true
          }
          podLabels = local.labels
          serviceAccount = {
            labels = local.labels
          }
          replicaCount = var.ca_injector_pod_configuration.replicas
          resources    = var.ca_injector_pod_configuration.resources
          nodeSelector = merge(var.ca_injector_pod_configuration.node_selector, local.node_selector)
          tolerations  = local.node_tolerations
        }
        commonLabels = local.labels
        # Configure cert-manager to "own" the secrets it creates to store the key pairs so that they
        # are removed when a cert is removed.
        enableCertificateOwnerRef = true
        extraArgs = concat(
          [
            "--acme-http01-solver-resource-limits-cpu=${var.http_challenge_solver_pod_configuration.resources.limits.cpu}",
            "--acme-http01-solver-resource-limits-memory=${var.http_challenge_solver_pod_configuration.resources.limits.memory}",
            "--acme-http01-solver-resource-request-cpu=${var.http_challenge_solver_pod_configuration.resources.requests.cpu}",
            "--acme-http01-solver-resource-request-memory=${var.http_challenge_solver_pod_configuration.resources.requests.memory}",
            "--cluster-resource-namespace=${coalesce(var.cluster_resource_namespace, kubernetes_namespace_v1.this.metadata[0].name)}",
            "--logging-format=json",
          ],
          var.default_ingress_issuer == null ? [] : ["--default-issuer-group=${var.default_ingress_issuer.group}", "--default-issuer-kind=${var.default_ingress_issuer.kind}", "--default-issuer-name=${var.default_ingress_issuer.name}"]
        )
        global = {
          logLevel          = var.log_level
          priorityClassName = "system-cluster-critical"
        }
        image = {
          registry   = var.image_registry
          repository = "jetstack/cert-manager-controller"
        }
        installCRDs = false
        podLabels   = local.labels
        prometheus = {
          enabled = true
          servicemonitor = {
            enabled  = var.service_monitor.enabled
            interval = var.service_monitor.scrape_interval
          }
        }
        replicaCount = var.controller_pod_configuration.replicas
        resources    = var.controller_pod_configuration.resources
        nodeSelector = merge(var.controller_pod_configuration.node_selector, local.node_selector)
        podDisruptionBudget = {
          enabled = true
        }
        serviceAccount = {
          annotations = {
            "eks.amazonaws.com/role-arn" = aws_iam_role.service_account.arn
            # Use the regional STS endpoints to support private link endpoints and reduce implicit dependencies on us-east-1
            # The regional endpoint is set to true by default on the latest EKS platforms, but not all clusters on the latest version.
            # https://docs.aws.amazon.com/eks/latest/userguide/platform-versions.html
            # https://github.com/aws/amazon-eks-pod-identity-webhook
            "eks.amazonaws.com/sts-regional-endpoints" = "true"
          }
          labels = local.labels
          name   = local.service_account_name
        }
        serviceLabels = local.labels
        startupapicheck = {
          image = {
            registry   = var.image_registry
            repository = "jetstack/cert-manager-ctl"
          }
          podLabels = local.labels
          serviceAccount = {
            labels = local.labels
          }
        }
        tolerations = local.node_tolerations
        webhook = {
          extraArgs = [
            "--logging-format=json",
          ]
          image = {
            registry   = var.image_registry
            repository = "jetstack/cert-manager-webhook"
          }
          podDisruptionBudget = {
            enabled = true
          }
          podLabels    = local.labels
          replicaCount = var.webhook_pod_configuration.replicas
          resources    = var.webhook_pod_configuration.resources
          nodeSelector = merge(var.webhook_pod_configuration.node_selector, local.node_selector)
          serviceAccount = {
            labels = local.labels
          }
          serviceLabels = local.labels
          tolerations   = local.node_tolerations
        }
      }
    )
  ]

  depends_on = [
    # Wait for the CRDs to become available.
    kubectl_manifest.crd,
    # Ensure the service account has the necessary permissions before the chart is installed.
    aws_iam_role_policy.service_account
  ]
}

# https://monitoring.mixins.dev/cert-manager/

#####################################
# Grafana Integration
#####################################

# https://monitoring.mixins.dev/cert-manager/
# https://cert-manager.io/docs/usage/prometheus-metrics/
# https://gitlab.com/uneeq-oss/cert-manager-mixin.git
locals {
  dashboards_directory = "${path.module}/files/dashboards"
  dashboard_file_names = fileset(local.dashboards_directory, "*")
}

# Install the dashboards as discoverable configmaps as described in the Grafana Helm chart's README file.
# https://github.com/grafana/helm-charts/tree/main/charts/grafana#sidecar-for-dashboards
resource "kubernetes_config_map_v1" "grafana_dashboard" {
  for_each = var.grafana_dashboard_config == null ? [] : local.dashboard_file_names
  metadata {
    annotations = {
      (var.grafana_dashboard_config.folder_annotation_key) = "Cert-Manager"
    }
    labels = merge(
      local.labels,
      var.grafana_dashboard_config.label,
    )
    name      = split(".", each.key)[0]
    namespace = var.grafana_dashboard_config.namespace
  }

  data = {
    (each.key) = file("${local.dashboards_directory}/${each.key}")
  }
}

##############################
# Alert Manager integration
##############################

# https://monitoring.mixins.dev/cert-manager/
# https://github.com/monitoring-mixins/website/blob/master/assets/cert-manager/dashboards/cert-manager.json
locals {
  alerts = {
    "groups" = [
      {
        "name" = "cert-manager"
        "rules" = [
          {
            "alert" = "CertManagerAbsent"
            "annotations" = {
              "description" = "New certificates will not be able to be minted, and existing ones can't be renewed until cert-manager is back."
              "runbook_url" = "https://gitlab.com/uneeq-oss/cert-manager-mixin/-/blob/master/RUNBOOK.md#certmanagerabsent"
              "summary"     = "Cert Manager has dissapeared from Prometheus service discovery."
            }
            "expr" = "absent(up{job=\"cert-manager\"})"
            "for"  = "10m"
            "labels" = {
              "severity" = "critical"
            }
          },
        ]
      },
      {
        "name" = "certificates"
        "rules" = [
          {
            "alert" = "CertManagerCertExpirySoon"
            "annotations" = {
              "dashboard_url" = "https://grafana.example.com/d/TvuRo2iMk/cert-manager"
              "description"   = "The domain that this cert covers will be unavailable after {{ $value | humanizeDuration }}. Clients using endpoints that this cert protects will start to fail in {{ $value | humanizeDuration }}."
              "runbook_url"   = "https://gitlab.com/uneeq-oss/cert-manager-mixin/-/blob/master/RUNBOOK.md#certmanagercertexpirysoon"
              "summary"       = "The cert `{{ $labels.name }}` is {{ $value | humanizeDuration }} from expiry, it should have renewed over a week ago."
            }
            "expr" = <<-EOT
          avg by (exported_namespace, namespace, name) (
            certmanager_certificate_expiration_timestamp_seconds - time()
          ) < (21 * 24 * 3600) # 21 days in seconds

          EOT
            "for"  = "1h"
            "labels" = {
              "severity" = "warning"
            }
          },
          {
            "alert" = "CertManagerCertNotReady"
            "annotations" = {
              "dashboard_url" = "https://grafana.example.com/d/TvuRo2iMk/cert-manager"
              "description"   = "This certificate has not been ready to serve traffic for at least 10m. If the cert is being renewed or there is another valid cert, the ingress controller _may_ be able to serve that instead."
              "runbook_url"   = "https://gitlab.com/uneeq-oss/cert-manager-mixin/-/blob/master/RUNBOOK.md#certmanagercertnotready"
              "summary"       = "The cert `{{ $labels.name }}` is not ready to serve traffic."
            }
            "expr" = <<-EOT
          max by (name, exported_namespace, namespace, condition) (
            certmanager_certificate_ready_status{condition!="True"} == 1
          )

          EOT
            "for"  = "10m"
            "labels" = {
              "severity" = "critical"
            }
          },
          {
            "alert" = "CertManagerHittingRateLimits"
            "annotations" = {
              "dashboard_url" = "https://grafana.example.com/d/TvuRo2iMk/cert-manager"
              "description"   = "Depending on the rate limit, cert-manager may be unable to generate certificates for up to a week."
              "runbook_url"   = "https://gitlab.com/uneeq-oss/cert-manager-mixin/-/blob/master/RUNBOOK.md#certmanagerhittingratelimits"
              "summary"       = "Cert manager hitting LetsEncrypt rate limits."
            }
            "expr" = <<-EOT
          sum by (host) (
            rate(certmanager_http_acme_client_request_count{status="429"}[5m])
          ) > 0

          EOT
            "for"  = "5m"
            "labels" = {
              "severity" = "critical"
            }
          },
        ]
      },
    ]
  }
}

resource "kubectl_manifest" "alerts" {
  for_each = toset(var.enable_prometheus_rules ? ["cert-manager"] : [])

  yaml_body = yamlencode(
    {
      apiVersion = "monitoring.coreos.com/v1"
      kind       = "PrometheusRule"
      metadata = {
        labels    = local.labels
        name      = each.key
        namespace = kubernetes_namespace_v1.this.metadata[0].name
      }
      spec = local.alerts
    }
  )
  ignore_fields = [
    "metadata.annotations.prometheus-operator-validated"
  ]
}
