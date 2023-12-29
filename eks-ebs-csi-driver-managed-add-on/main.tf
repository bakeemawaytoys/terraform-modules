terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.10"
    }
  }
  required_version = ">= 1.4"
}

data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_iam_openid_connect_provider" "cluster" {
  arn = var.service_account_oidc_provider_arn
}

locals {

  addon_name = "aws-ebs-csi-driver"

  owned_resource_tags = merge(
    var.tags,
    {
      "kubernetes.io/cluster"                                      = var.cluster_name
      "kubernetes.io/cluster/${data.aws_eks_cluster.cluster.name}" = "owned"
    }
  )

  oidc_provider_id       = replace(data.aws_iam_openid_connect_provider.cluster.url, "https://", "")
  oidc_audience_variable = "${local.oidc_provider_id}:aud"
  oidc_subject_variable  = "${local.oidc_provider_id}:sub"
}

data "aws_iam_policy_document" "trust_policy" {
  statement {
    principals {
      identifiers = [data.aws_iam_openid_connect_provider.cluster.arn]
      type        = "Federated"
    }
    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]
    condition {
      test     = "StringEquals"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
      variable = local.oidc_subject_variable
    }
    condition {
      test     = "StringEquals"
      values   = ["sts.amazonaws.com"]
      variable = local.oidc_audience_variable
    }
  }
}

data "aws_iam_policy" "aws_managed" {
  name = "AmazonEBSCSIDriverPolicy"
}

# https://docs.aws.amazon.com/eks/latest/userguide/csi-iam-role.html
resource "aws_iam_role" "service_account" {
  assume_role_policy = data.aws_iam_policy_document.trust_policy.json
  description        = "Managed EBS CIS driver add-on"
  managed_policy_arns = [
    data.aws_iam_policy.aws_managed.arn,
  ]
  name = "${data.aws_eks_cluster.cluster.name}-eks-cluster-ebs-csi-driver-add-on"
  tags = local.owned_resource_tags
}

data "aws_kms_key" "cmk" {
  for_each = toset(compact([var.volume_encryption_key]))
  key_id   = each.key

}

data "aws_iam_policy_document" "cmk" {
  for_each = data.aws_kms_key.cmk
  statement {
    actions = [
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:RevokeGrant",
    ]
    resources = [
      each.value.arn,
    ]
    condition {
      test     = "Bool"
      values   = ["true"]
      variable = "kms:GrantIsForAWSResource"
    }
  }

  statement {
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = [
      each.value.arn,
    ]
  }
}

resource "aws_iam_role_policy" "cmk" {
  for_each = data.aws_kms_key.cmk
  name     = "volume-encryption-key-${each.value.id}"
  policy   = data.aws_iam_policy_document.cmk[each.key].json
  role     = aws_iam_role.service_account.name
}

data "aws_eks_addon_version" "driver" {
  addon_name         = local.addon_name
  kubernetes_version = data.aws_eks_cluster.cluster.version
  most_recent        = var.addon_version == "latest"
}

locals {

  # Use the version loaded from the data source unless a specific version is specified.
  addon_version      = contains(["latest", "default"], var.addon_version) ? data.aws_eks_addon_version.driver.version : var.addon_version
  version_components = regex("^v(?P<major>\\d+)\\.(?P<minor>\\d+)\\.(?P<patch>\\d+)-eksbuild\\.\\d+$", local.addon_version)

  # Convert the version components to integers to allow for comparisons.
  version = { for k, v in local.version_components : k => parseint(v, 10) }

  # The nodeSelector setting wasn't supported until 1.14
  node_selector_supported   = 1 <= local.version["major"] && 14 <= local.version["minor"]
  log_format_config_enabled = 1 <= local.version["major"] && 16 <= local.version["minor"]
  # The snapshotter sidecar can be disabled as of version 1.19.
  # https://github.com/kubernetes-sigs/aws-ebs-csi-driver/issues/1662
  sidecars_supported = 1 <= local.version["major"] && 19 <= local.version["minor"]

  sidecars_config = {
    sidecars = {
      snapshotter = {
        forceEnable = false
      }
    }
  }

  configuration = merge({
    controller = merge(
      {
        extraVolumeTags = {
          managed_with = "ebs-csi-driver"
        }
      },
      local.log_format_config_enabled ? { loggingFormat = "json" } : {},
      local.node_selector_supported ? { nodeSelector = var.node_selector } : {},
    )
    node = local.log_format_config_enabled ? { loggingFormat = "json" } : {}
    },
    local.sidecars_supported ? local.sidecars_config : {}
  )
}

resource "aws_eks_addon" "driver" {
  addon_name = local.addon_name

  addon_version               = local.addon_version
  cluster_name                = data.aws_eks_cluster.cluster.name
  configuration_values        = jsonencode(local.configuration)
  preserve                    = var.preserve_on_delete
  resolve_conflicts_on_create = var.resolve_conflicts
  resolve_conflicts_on_update = var.resolve_conflicts
  service_account_role_arn    = aws_iam_role.service_account.arn
  tags                        = local.owned_resource_tags
}

data "aws_kms_key" "volume_encryption" {
  key_id = coalesce(var.volume_encryption_key, "alias/aws/ebs")
}

# EKS clusters are created with a default storage class that uses the built-in (in-tree) provisioner.
# The annotation that specifies it as the default must be set to false so that a CIS driver storage
# class can be set as the default.
resource "kubernetes_annotations" "cluster_provisioner_default" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  metadata {
    name = "gp2"
  }
  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "false"
  }
  force = true

}

# Create a default storage class that uses the CSI driver to enable dynamic volume provisioning.
# https://kubernetes.io/docs/concepts/storage/dynamic-provisioning/
resource "kubernetes_storage_class_v1" "ebs_default" {
  metadata {
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
    name   = "ebs-default"
    labels = var.labels
  }
  allow_volume_expansion = true
  parameters = {
    "csi.storage.k8s.io/fstype" = "ext4"
    encrypted                   = true
    kmsKeyId                    = data.aws_kms_key.volume_encryption.arn
    type                        = "gp3"
  }
  reclaim_policy      = "Delete"
  storage_provisioner = "ebs.csi.aws.com"
  volume_binding_mode = "WaitForFirstConsumer"

  depends_on = [
    aws_eks_addon.driver,
    kubernetes_annotations.cluster_provisioner_default
  ]
}
