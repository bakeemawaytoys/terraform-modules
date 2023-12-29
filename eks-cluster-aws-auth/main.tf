terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23"
    }
  }
  required_version = ">= 1.5"
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  owned_resource_tags = merge(
    var.tags,
    {
      "kubernetes.io/cluster"                     = var.cluster_name
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  )
}

# https://docs.aws.amazon.com/AmazonECR/latest/userguide/pull-through-cache.html?icmpid=docs_ecr_hp-registry-private#pull-through-cache-iam
data "aws_iam_policy_document" "ecr_pull_through_cache" {
  statement {
    sid     = "EcrPullThroughCacheAccess"
    actions = ["ecr:BatchImportUpstreamImage"]
    resources = [
      "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/*",
    ]
  }
}

########################
#  EC2 Node Role
########################
data "aws_iam_policy_document" "ec2_trust_policy" {
  statement {
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "node" {
  assume_role_policy = data.aws_iam_policy_document.ec2_trust_policy.json
  description        = "Role for nodes in the ${var.cluster_name} cluster"
  name               = "${var.cluster_name}-eks-cluster-node"
  tags               = local.owned_resource_tags
}

resource "aws_iam_instance_profile" "node" {
  name = aws_iam_role.node.name
  role = aws_iam_role.node.name
}

locals {
  # https://docs.aws.amazon.com/eks/latest/userguide/create-node-role.html
  required_ec2_managed_policies = [
    "AmazonEC2ContainerRegistryReadOnly",
    "AmazonEKSWorkerNodePolicy",
  ]
  ec2_managed_policies = var.ssm_agent_credentials_source == "instance-profile" ? setunion(local.required_ec2_managed_policies, ["AmazonSSMManagedInstanceCore"]) : local.required_ec2_managed_policies
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each   = toset(local.ec2_managed_policies)
  policy_arn = "arn:aws:iam::aws:policy/${each.value}"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy" "node" {
  name_prefix = "ecr-pull-through-cache-"
  policy      = data.aws_iam_policy_document.ecr_pull_through_cache.json
  role        = aws_iam_role.node.name
}

########################
#  EC2 Node Role
########################

data "aws_iam_policy_document" "fargate_trust_policy" {
  statement {
    principals {
      identifiers = ["eks-fargate-pods.amazonaws.com"]
      type        = "Service"
    }
    actions = ["sts:AssumeRole"]
    condition {
      test     = "ArnLike"
      values   = ["arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:fargateprofile/${var.cluster_name}/*"]
      variable = "aws:SourceArn"
    }
  }
}

resource "aws_iam_role" "fargate" {
  assume_role_policy = data.aws_iam_policy_document.fargate_trust_policy.json
  description        = "Fargate pod execution role for the ${var.cluster_name} cluster"
  name               = "${var.cluster_name}-eks-cluster-fargate-pod"
  tags               = local.owned_resource_tags
}

resource "aws_iam_role_policy_attachment" "fargate" {
  for_each   = toset(["AmazonEKSFargatePodExecutionRolePolicy"])
  policy_arn = "arn:aws:iam::aws:policy/${each.value}"
  role       = aws_iam_role.fargate.name
}

resource "aws_iam_role_policy" "fargate" {
  name_prefix = "ecr-pull-through-cache-"
  policy      = data.aws_iam_policy_document.ecr_pull_through_cache.json
  role        = aws_iam_role.fargate.name
}

locals {

  # Remove the paths from the role ARN to account for https://github.com/kubernetes-sigs/aws-iam-authenticator/issues/268
  # The regex solution is based on https://github.com/kubernetes-sigs/aws-iam-authenticator/issues/268#issuecomment-695132427
  # It has been modified to work on ARNs with any number of components in the path including zero.
  role_arn_regex = "(?P<prefix>arn:aws:iam::[0-9]+:role)/(?:[^/]+/)*(?P<role>.*)"

  node_role_maps = [
    {
      # Role mapping for Fargate is described at
      # https://aws.amazon.com/premiumsupport/knowledge-center/fargate-troubleshoot-profile-creation/
      rolearn  = aws_iam_role.fargate.arn
      username = "system:node:{{SessionName}}"
      groups = [
        "system:bootstrappers",
        "system:nodes",
        "system:node-proxier",
      ]
    },
    {
      rolearn  = aws_iam_role.node.arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups = [
        "system:bootstrappers",
        "system:nodes",
      ]
    }
  ]

  iam_role_maps = [for item in var.iam_role_mappings :
    {
      rolearn  = join("/", values(regex(local.role_arn_regex, item["role_arn"])))
      groups   = item["rbac_groups"]
      username = join(":", compact([item.username_prefix, "{{SessionName}}"]))
    }
  ]
}

# https://github.com/kubernetes-sigs/aws-iam-authenticator#full-configuration-format
resource "kubernetes_config_map_v1" "aws_auth" {
  metadata {
    namespace = "kube-system"
    name      = "aws-auth"
  }
  data = {
    mapRoles = yamlencode(flatten(
      [
        local.iam_role_maps,
        local.node_role_maps,
      ]
    ))
  }
}
