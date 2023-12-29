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
  required_version = ">= 1.5"
}

locals {

  owned_resource_tags = merge(
    var.tags,
    {
      "kubernetes.io/cluster"                                 = var.eks_cluster.cluster_name
      "kubernetes.io/cluster/${var.eks_cluster.cluster_name}" = "owned"
    }
  )
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}


locals {
  bucket_name = coalesce(var.custom_bucket_name, "velero-backups-${var.eks_cluster.cluster_name}-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}")
}

resource "aws_s3_bucket" "velero" {
  bucket = local.bucket_name
  tags   = local.owned_resource_tags
}

resource "aws_s3_bucket_logging" "velero" {
  for_each      = toset(var.access_logging.enabled ? ["enabled"] : [])
  bucket        = aws_s3_bucket.velero.bucket
  target_bucket = var.access_logging.bucket
  target_prefix = var.access_logging.prefix
}

resource "aws_s3_bucket_metric" "velero" {
  bucket = aws_s3_bucket.velero.bucket
  name   = "Everything"
}

resource "aws_s3_bucket_analytics_configuration" "velero" {
  bucket = aws_s3_bucket.velero.bucket
  name   = "Everything"
}

resource "aws_s3_bucket_versioning" "velero" {
  bucket = aws_s3_bucket.velero.bucket
  versioning_configuration {
    status = "Enabled"
  }
}

# Add a lifecycle rule to clean up non-concurrent versions.
# No rule is needed for the current version because Velero will handle that.
resource "aws_s3_bucket_lifecycle_configuration" "velero" {
  bucket = aws_s3_bucket.velero.bucket

  rule {
    id = "NonConcurrentVersionCleanup"
    filter {
      # Empty filter to apply to everything
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
    expiration {
      expired_object_delete_marker = true
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }

    status = "Enabled"
  }

  depends_on = [
    aws_s3_bucket_versioning.velero
  ]
}

resource "aws_s3_bucket_public_access_block" "velero" {
  bucket                  = aws_s3_bucket.velero.bucket
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "velero" {
  bucket = aws_s3_bucket.velero.bucket
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
  depends_on = [
    aws_s3_bucket_public_access_block.velero
  ]
}

data "aws_iam_policy_document" "bucket" {
  # https://aws.amazon.com/premiumsupport/knowledge-center/s3-bucket-policy-for-config-rule/
  statement {
    sid = "AllowTLSRequestsOnly"
    principals {
      identifiers = ["*"]
      type        = "AWS"
    }
    effect = "Deny"
    actions = [
      "s3:*"
    ]
    resources = [
      aws_s3_bucket.velero.arn,
      "${aws_s3_bucket.velero.arn}/*",
    ]
    condition {
      test     = "Bool"
      values   = ["false"]
      variable = "aws:SecureTransport"
    }
  }
}

resource "aws_s3_bucket_policy" "velero" {
  bucket = aws_s3_bucket.velero.bucket
  policy = data.aws_iam_policy_document.bucket.json

  depends_on = [
    aws_s3_bucket_public_access_block.velero
  ]
}


resource "aws_s3_bucket_server_side_encryption_configuration" "velero" {
  bucket = aws_s3_bucket.velero.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
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
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
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
  description        = "Velero in the ${var.eks_cluster.cluster_name} EKS cluster"
  name_prefix        = "kubernetes-velero-"
  tags               = local.owned_resource_tags

  lifecycle {
    create_before_destroy = true
  }
}

# https://github.com/vmware-tanzu/velero-plugin-for-aws
data "aws_iam_policy_document" "service_account" {

  statement {
    sid = "ObjectAccess"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListMultipartUploadParts",
      "s3:PutObject",
    ]
    # Velero owns all of the objects in the bucket so a wildcard is appropriate.
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = [
      "${aws_s3_bucket.velero.arn}/*"
    ]
    condition {
      test     = "StringEquals"
      values   = [data.aws_caller_identity.current.account_id]
      variable = "s3:ResourceAccount"
    }
  }

  statement {
    sid = "BucketAccess"
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.velero.arn,
    ]
    condition {
      test     = "StringEquals"
      values   = [data.aws_caller_identity.current.account_id]
      variable = "s3:ResourceAccount"
    }
  }
}

resource "aws_iam_role_policy" "service_accounts" {
  policy = data.aws_iam_policy_document.service_account.json
  role   = aws_iam_role.service_account.name
}

locals {
  labels = merge(
    {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/instance"   = var.release_name
      "app.kubernetes.io/name"       = var.release_name
    },
    var.labels,
  )
}

# Create the namespace using Terraform instead of Helm so that it will be removed if the module is removed.  Helm, as far as I can tell, doesn't remove namespaces that it creates during an install.
resource "kubernetes_namespace_v1" "velero" {
  for_each = var.create_namespace ? toset([var.namespace]) : toset([])
  metadata {
    name = each.key
    labels = merge(
      local.labels,
      { for mode, level in var.pod_security_standards : "pod-security.kubernetes.io/${mode}" => level },
      {
        "goldilocks.fairwinds.com/enabled" : tostring(var.enable_goldilocks)
      }
    )
  }
}


###################################################
# Install the Custom Resource Definitions
###################################################

locals {

  version_parts         = split(".", var.chart_version)
  crd_directory         = "${path.module}/files/crds/${local.version_parts[0]}.${local.version_parts[1]}"
  storage_location_name = "default"
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

resource "helm_release" "velero" {
  atomic           = true
  cleanup_on_fail  = true
  create_namespace = false
  chart            = "velero"
  description      = "Velero backups"
  max_history      = 5
  name             = var.release_name
  namespace        = var.namespace
  recreate_pods    = true
  repository       = "https://vmware-tanzu.github.io/helm-charts"
  skip_crds        = true
  version          = var.chart_version

  values = [
    yamlencode({
      cleanUpCRDs = false
      credentials = {
        useSecret = false
      }
      configuration = {

        backupStorageLocation = [
          {
            bucket   = aws_s3_bucket.velero.bucket
            prefix   = ""
            provider = "aws"
            config = {
              region = aws_s3_bucket.velero.region
            }
            name = local.storage_location_name
            # Disable validation frequency to reduce the noise in the logs.
            validationFrequency = 0
          }
        ]
        extraEnvVars = {
          # https://github.com/vmware-tanzu/velero-plugin-for-aws#migrating-pvs-across-clusters
          AWS_CLUSTER_NAME = var.eks_cluster.cluster_name
        }
        labels                 = local.labels
        logFormat              = "json"
        logLevel               = var.log_level
        region                 = data.aws_region.current.name
        volumeSnapshotLocation = []
      }
      containerSecurityContext = {
        allowPrivilegeEscalation = false
        capabilities = {
          drop = ["ALL"]
          add  = []
        }
        readOnlyRootFilesystem = true
        # The Velero image is built on a Google distroless image.
        # The image defines a non-numeric user in its USER directive.
        # That means it is a non-root user but it won't work out of the box
        # with the security context unless numeric values are set here.
        runAsUser    = 1000
        runAsGroup   = 1000
        runAsNonRoot = true
      }
      helmHookAnnotations = false
      image = {
        repository = "${var.velero_image_registry}/velero/velero"
      }
      initContainers = [
        {
          name            = "velero-plugin-for-csi"
          image           = "${var.velero_image_registry}/velero/velero-plugin-for-aws:v${var.aws_plugin_version}"
          imagePullPolicy = "IfNotPresent"
          securityContext = {
            allowPrivilegeEscalation = false
            capabilities = {
              drop = ["ALL"]
              add  = []
            }
            readOnlyRootFilesystem = true
            # The AWS plug-in container uses user 65532:65532
            runAsNonRoot = true
          }
          volumeMounts = [
            {
              mountPath = "/target"
              name      = "plugins"
            }
          ]
        }
      ]
      labels = local.labels
      metrics = {
        prometheusRule = {
          enabled = var.enable_prometheus_rules
          # The rules are copied from the examples in the comments of the chart's values file
          # https://github.com/vmware-tanzu/helm-charts/blob/velero-2.32.6/charts/velero/values.yaml#L170
          spec = [
            {
              "alert" = "VeleroBackupPartialFailures"
              "annotations" = {
                "message" = "Velero backup {{ $labels.schedule }} has {{ $value | humanizePercentage }} partialy failed backups."
              }
              "expr" = "velero_backup_partial_failure_total{schedule!=\"\"} / velero_backup_attempt_total{schedule!=\"\"} > 0.25"
              "for"  = "15m"
              "labels" = {
                "severity" = "warning"
              }
            },
            {
              "alert" = "VeleroBackupFailures"
              "annotations" = {
                "message" = "Velero backup {{ $labels.schedule }} has {{ $value | humanizePercentage }} failed backups."
              }
              "expr" = "velero_backup_failure_total{schedule!=\"\"} / velero_backup_attempt_total{schedule!=\"\"} > 0.25"
              "for"  = "15m"
              "labels" = {
                "severity" = "warning"
              }
            },
          ]
        }
        service = {
          labels = local.labels
        }
        serviceMonitor = {
          enabled = var.enable_service_monitor
        }
      }
      nodeSelector = var.node_selector
      podLabels    = local.labels
      podSecurityContext = {
        runAsNonRoot = true
        seccompProfile = {
          type = "RuntimeDefault"
        }
      }
      priorityClassName = "system-cluster-critical"
      resources         = var.pod_resources
      schedules = {
        for name, schedule in var.schedules : name =>
        merge(
          schedule,
          {
            template = merge(
              schedule.template, {
                snapshotVolumes         = false
                storageLocation         = local.storage_location_name
                volumeSnapshotLocations = []
              }
            )
          }
        )
      }
      serviceAccount = {
        server = {
          annotations = {
            "eks.amazonaws.com/role-arn" = aws_iam_role.service_account.arn
            # Use the regional STS endpoints to support private link endpoints and reduce implicit dependencies on us-east-1
            # The regional endpoint is set to true by default on the latest EKS platforms, but not all clusters on the latest version.
            # https://docs.aws.amazon.com/eks/latest/userguide/platform-versions.html
            # https://github.com/aws/amazon-eks-pod-identity-webhook
            "eks.amazonaws.com/sts-regional-endpoints" = "true"
          }
          labels = local.labels
          name   = var.service_account_name
        }
      }
      snapshotsEnabled = false
      tolerations = concat(
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
      upgradeCRDs = false
    })
  ]

  depends_on = [
    kubernetes_namespace_v1.velero,
    kubectl_manifest.crd,
  ]
}

locals {
  api_group                    = "velero.io"
  custom_resource_names        = [for name in values(kubectl_manifest.crd)[*].name : split(".", name)[0]]
  custom_resource_status_names = formatlist("%s/status", local.custom_resource_names)
}

# Create cluster roles for viewing and managing the Velero resources.
# The cluster role aggregation labels have been added so that access is
# implicitly granted to existing cluster roles.
resource "kubernetes_cluster_role" "viewer" {
  metadata {
    name = "velero-view"
    labels = merge(
      local.labels, {
        "rbac.authorization.k8s.io/aggregate-to-view" = "true"
      }
    )
  }

  rule {
    api_groups = [local.api_group]
    resources = concat(
      local.custom_resource_names,
      local.custom_resource_status_names,
    )
    verbs = [
      "get",
      "list",
      "watch",
    ]
  }

  depends_on = [
    helm_release.velero
  ]
}

resource "kubernetes_cluster_role" "admin" {
  metadata {
    name = "velero-admin"
    labels = merge(
      local.labels, {
        "rbac.authorization.k8s.io/aggregate-to-admin" = "true"
      }
    )
  }

  rule {
    api_groups = [local.api_group]
    resources  = local.custom_resource_names
    verbs = [
      "create",
      "deletecollection",
      "delete",
      "get",
      "list",
      "patch",
      "watch",
      "update",
    ]
  }

  rule {
    api_groups = [local.api_group]
    resources  = local.custom_resource_status_names
    verbs = [
      "get",
      "list",
      "watch",
    ]
  }

  depends_on = [
    helm_release.velero
  ]
}

#####################################
# Grafana Integration
#####################################

# https://grafana.com/grafana/dashboards/11055-kubernetes-addons-velero-stats/
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
      (var.grafana_dashboard_config.folder_annotation_key) = "Velero"
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
