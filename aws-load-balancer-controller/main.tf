terraform {

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
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
  }
  required_version = ">= 1.6"
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_vpc" "cluster" {
  id = var.vpc_id
}

locals {

  labels = merge(
    var.labels,
    {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  )

  service_account_name = "aws-load-balancer-controller"
  owned_resource_tags = merge(
    var.tags,
    {
      "kubernetes.io/cluster"                                 = var.eks_cluster.cluster_name
      "kubernetes.io/cluster/${var.eks_cluster.cluster_name}" = "owned"
    }
  )

}

resource "aws_security_group" "alb_backend" {
  description = "Shared backend security group for ALBs managed by the ${var.eks_cluster.cluster_name} EKS cluster"
  name        = "${var.eks_cluster.cluster_name}-eks-cluster-aws-load-balancer-controller-alb-shared-backend"

  # Allow ICMP for Path MTU Discover as recommended in the ALB documentation
  # https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-register-targets.html#target-security-groups
  # https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-update-security-groups.html
  ingress {
    description = "IPv4 Path MTU discovery"
    # ICMP type 3
    from_port       = 3
    protocol        = "icmp"
    security_groups = [var.eks_cluster.cluster_security_group_id]
    # ICMP code 4
    to_port = 4
  }

  # All
  # https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html#nacl-ephemeral-ports
  egress {
    description     = "TCP traffic to pods in the ${var.eks_cluster.cluster_name} cluster"
    from_port       = 0
    protocol        = "tcp"
    security_groups = [var.eks_cluster.cluster_security_group_id]
    to_port         = 0
  }



  tags = local.owned_resource_tags

  vpc_id = data.aws_vpc.cluster.id
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
      values   = ["system:serviceaccount:${var.namespace}:${local.service_account_name}"]
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
  description        = "Controller in the ${var.eks_cluster.cluster_name} EKS cluster"
  name_prefix        = "aws-load-balancer-controller-"
  tags               = local.owned_resource_tags

  lifecycle {
    create_before_destroy = true
  }
}

# From https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/v2.4.6/docs/install/iam_policy.json
data "aws_iam_policy_document" "ec2" {

  # Allow the controller to use the Resource Group tagging API to find resources instead of the individual
  # service APIs.  Support for this API was added in version 2.5.2 but is not enabled yet.
  statement {
    sid     = "ResourceGroupTaggingAPI"
    actions = ["tag:GetResources"]
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = ["*"]
  }

  statement {
    actions = [
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeVpcs",
      "ec2:DescribeVpcPeeringConnections",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeTags",
      "ec2:GetCoipPoolUsage",
      "ec2:DescribeCoipPools",

    ]
    resources = ["*"]
  }

  statement {
    sid = "ManageClusterSecurityGroupIngressRules"
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
    ]
    resources = [
      "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:security-group/${var.eks_cluster.cluster_security_group_id}",
    ]
    condition {
      test     = "ArnEquals"
      values   = [data.aws_vpc.cluster.arn]
      variable = "ec2:Vpc"
    }
  }

  statement {
    sid = "CreateFrontEndSecurityGroup"
    actions = [
      "ec2:CreateSecurityGroup",
    ]
    resources = [
      "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:security-group/*",
      data.aws_vpc.cluster.arn,
    ]
  }

  statement {
    sid = "AllowTagOnCreate"
    actions = [
      "ec2:CreateTags"
    ]
    resources = [
      "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:security-group/*",
    ]
    condition {
      test     = "StringEquals"
      values   = ["CreateSecurityGroup"]
      variable = "ec2:CreateAction"
    }
    condition {
      test     = "StringEquals"
      values   = [var.eks_cluster.cluster_name]
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
    }
  }

  statement {
    sid = "ManageOwnedSecurityGroupTags"
    actions = [
      "ec2:CreateTags",
      "ec2:DeleteTags",
    ]
    resources = [
      "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:security-group/*",
    ]
    condition {
      test     = "Null"
      values   = [true]
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
    }
    condition {
      test     = "StringEquals"
      values   = [var.eks_cluster.cluster_name]
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
    }
  }

  statement {
    sid = "ManageOwnedSecurityGroups"
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:DeleteSecurityGroup"
    ]
    resources = [
      "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:security-group/*",
    ]
    condition {
      test     = "StringEquals"
      values   = [var.eks_cluster.cluster_name]
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
    }
  }

}

resource "aws_iam_role_policy" "ec2" {
  name_prefix = "ec2-"
  policy      = data.aws_iam_policy_document.ec2.json
  role        = aws_iam_role.service_account.name
}

# ALB/NLB permissions
data "aws_iam_policy_document" "elb" {

  statement {
    actions = [
      "iam:CreateServiceLinkedRole"
    ]
    # According to the docs, the action does allow for including a role in the resource list but isn't
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = ["*"]
    condition {
      test     = "StringEquals"
      values   = ["elasticloadbalancing.amazonaws.com"]
      variable = "iam:AWSServiceName"
    }
  }

  statement {
    sid = "ReadAccess"
    actions = [
      "acm:ListCertificates",
      "acm:DescribeCertificate",
      "cognito-idp:DescribeUserPoolClient",
      "iam:ListServerCertificates",
      "iam:GetServerCertificate",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeSSLPolicies",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DescribeTags",
    ]
    # Use a wildcard for the sake of policy size.
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = ["*"]
  }

  statement {
    sid = "CreateStandAloneResources"
    actions = [
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateTargetGroup"
    ]
    resources = [
      "arn:aws:elasticloadbalancing:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:loadbalancer/app/*",
      "arn:aws:elasticloadbalancing:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:loadbalancer/net/*",
      "arn:aws:elasticloadbalancing:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:targetgroup/*",
    ]
    condition {
      test     = "StringEquals"
      values   = [var.eks_cluster.cluster_name]
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
    }
  }

  statement {
    sid = "CreateListener"
    actions = [
      "elasticloadbalancing:CreateListener",
    ]
    resources = [
      "arn:aws:elasticloadbalancing:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:loadbalancer/app/*",
      "arn:aws:elasticloadbalancing:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:loadbalancer/net/*",
    ]
    condition {
      test     = "StringEquals"
      values   = [var.eks_cluster.cluster_name]
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
    }
    condition {
      test     = "StringEquals"
      values   = [var.eks_cluster.cluster_name]
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
    }
  }

  statement {
    sid = "CreateRule"
    actions = [
      "elasticloadbalancing:CreateRule"
    ]
    resources = [
      "arn:aws:elasticloadbalancing:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:listener/app/*",
      "arn:aws:elasticloadbalancing:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:listener/net/*",
    ]
    condition {
      test     = "StringEquals"
      values   = [var.eks_cluster.cluster_name]
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
    }
    condition {
      test     = "StringEquals"
      values   = [var.eks_cluster.cluster_name]
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
    }
  }

  statement {
    sid = "ManageTags"
    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags"
    ]
    resources = [
      "arn:aws:elasticloadbalancing:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:loadbalancer/net/*",
      "arn:aws:elasticloadbalancing:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:loadbalancer/app/*",
      "arn:aws:elasticloadbalancing:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:listener/net/*",
      "arn:aws:elasticloadbalancing:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:listener/app/*",
      "arn:aws:elasticloadbalancing:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:listener-rule/net/*",
      "arn:aws:elasticloadbalancing:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:listener-rule/app/*",
      "arn:aws:elasticloadbalancing:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:targetgroup/*",
    ]
    condition {
      test     = "Null"
      values   = [true]
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
    }
    condition {
      test     = "StringEquals"
      values   = [var.eks_cluster.cluster_name]
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
    }
  }

  statement {
    sid = "ManageOwnedResources"
    actions = [
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DeleteRule",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:ModifyRule",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:RemoveListenerCertificates",
      "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:SetRulePriorities",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets",
    ]
    resources = [
      "arn:aws:elasticloadbalancing:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:loadbalancer/app/*",
      "arn:aws:elasticloadbalancing:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:loadbalancer/net/*",
      "arn:aws:elasticloadbalancing:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:listener/app/*",
      "arn:aws:elasticloadbalancing:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:listener/net/*",
      "arn:aws:elasticloadbalancing:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:listener-rule/app/*",
      "arn:aws:elasticloadbalancing:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:listener-rule/net/*",
      "arn:aws:elasticloadbalancing:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:targetgroup/*",
    ]
    condition {
      test     = "StringEquals"
      values   = [var.eks_cluster.cluster_name]
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
    }
  }
}

resource "aws_iam_role_policy" "elb" {
  name_prefix = "elb-"
  policy      = data.aws_iam_policy_document.elb.json
  role        = aws_iam_role.service_account.name
}

# Add policies for optional features if the feature is enabled on the controller.
data "aws_iam_policy_document" "shield" {
  statement {
    actions = [
      "shield:GetSubscriptionState",
      "shield:DescribeProtection",
      "shield:CreateProtection",
      "shield:DeleteProtection",
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "waf" {
  statement {
    sid = "ReadAccess"
    actions = [
      "waf-regional:GetWebACL",
      "waf-regional:GetWebACLForResource",
    ]
    resources = ["*"]
  }

  statement {
    sid = "WriteAccess"
    actions = [
      "waf-regional:AssociateWebACL",
      "waf-regional:DisassociateWebACL",
      "elasticloadbalancing:SetWebAcl",
    ]
    resources = [
      "arn:aws:elasticloadbalancing:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:loadbalancer/app/*",
      "arn:aws:waf-regional:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:webacl/*",
    ]
  }
}

data "aws_iam_policy_document" "wavf2" {
  statement {
    sid = "ReadAccess"
    actions = [
      "wafv2:GetWebACL",
      "wafv2:GetWebACLForResource",
    ]
    resources = ["*"]
  }

  statement {
    sid = "WriteAccess"
    actions = [
      "wafv2:AssociateWebACL",
      "wafv2:DisassociateWebACL",
      "elasticloadbalancing:SetWebAcl",
    ]
    resources = [
      "arn:aws:elasticloadbalancing:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:loadbalancer/app/*",
      "arn:aws:wafv2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:webacl/*",
    ]
  }
}

locals {
  feature_policies = {
    shield = data.aws_iam_policy_document.shield.json
    waf    = data.aws_iam_policy_document.waf.json
    wafv2  = data.aws_iam_policy_document.wavf2.json
  }
}

resource "aws_iam_role_policy" "features" {
  for_each    = var.enabled_features
  name_prefix = "${each.value}-"
  policy      = local.feature_policies[each.value]
  role        = aws_iam_role.service_account.name
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

resource "helm_release" "controller" {
  atomic          = true
  chart           = "aws-load-balancer-controller"
  cleanup_on_fail = true
  max_history     = 5
  name            = "aws-load-balancer-controller"
  namespace       = var.namespace
  recreate_pods   = true
  repository      = "https://aws.github.io/eks-charts"
  version         = var.chart_version

  values = [
    yamlencode(
      {
        backendSecurityGroup       = aws_security_group.alb_backend.id
        clusterName                = var.eks_cluster.cluster_name
        createIngressClassResource = false
        defaultSSLPolicy           = var.default_tls_security_policy
        defaultTags = merge(
          var.default_aws_resource_tags,
          {
            managed_with = "aws-load-balancer-controller"
          }
        )
        defaultTargetType = "ip"
        # Disable support for deprecated annoation.
        # https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/deploy/configurations/#disable-ingress-class-annotation
        disableIngressClassAnnotation     = true
        disableIngressGroupNameAnnotation = true
        enableEndpointSlices              = true
        enableServiceMutatorWebhook       = contains(var.enabled_features, "serviceMutatorWebhook")
        enableShield                      = contains(var.enabled_features, "shield")
        enableWaf                         = contains(var.enabled_features, "waf")
        enableWafv2                       = contains(var.enabled_features, "wafv2")
        externalManagedTags               = var.externally_managed_tag_keys
        image = {
          # Pull from the AWS ECR repo in the current region.  Note that the AWS account ID is different in some regions.
          # The account that is corresponds to all of the major regions has been hard coded because there doesn't seem to
          # be a dynamic lookup resource available.
          # https://docs.aws.amazon.com/eks/latest/userguide/add-ons-images.html
          repository = "602401143452.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/amazon/aws-load-balancer-controller"
        }
        logLevel     = var.log_level
        nodeSelector = local.node_selector
        podDisruptionBudget = {
          minAvailable = 1
        }
        podLabels    = local.labels
        region       = data.aws_region.current.name
        replicaCount = var.replica_count
        resources    = var.pod_resources
        serviceAccount = {
          annotations = {
            "eks.amazonaws.com/role-arn" = aws_iam_role.service_account.arn
            # Use the regional STS endpoints to support private link endpoints and reduce implicit dependencies on us-east-1
            # The regional endpoint is set to true by default on the latest EKS platforms, but not all clusters on the latest version.
            # https://docs.aws.amazon.com/eks/latest/userguide/platform-versions.html
            # https://github.com/aws/amazon-eks-pod-identity-webhook
            "eks.amazonaws.com/sts-regional-endpoints" = "true"
          }
          name = local.service_account_name
        }
        serviceMonitor = {
          enabled  = var.service_monitor.enabled
          interval = var.service_monitor.scrape_interval
        }
        tolerations = local.node_tolerations
        vpcId       = data.aws_vpc.cluster.id
      }
    )
  ]

  # Ensure IAM permissions are available before creating the controller resources.
  depends_on = [
    aws_iam_role_policy.ec2,
    aws_iam_role_policy.elb,
    aws_iam_role_policy.features,
  ]
}

locals {

  access_logs_attributes = var.alb_access_logs == null ? {} : {
    "access_logs.s3.enabled" = var.alb_access_logs.enabled
    "access_logs.s3.bucket"  = var.alb_access_logs.bucket_name
    "access_logs.s3.prefix"  = var.alb_access_logs.bucket_prefix
  }

  ingress_class_controller             = "ingress.k8s.aws/alb"
  ingress_class_parameters_api_group   = "elbv2.k8s.aws"
  ingress_class_parameters_api_version = "${local.ingress_class_parameters_api_group}/v1beta1"
  ingress_class_parameters_kind        = "IngressClassParams"
}

resource "kubectl_manifest" "ingress_class_params" {
  for_each = {
    internal        = var.internal_ingress_class_parameters
    internet-facing = var.internet_facing_ingress_class_parameters
  }
  yaml_body = yamlencode(
    {
      apiVersion = local.ingress_class_parameters_api_version
      kind       = local.ingress_class_parameters_kind
      metadata = {
        labels = local.labels,
        name   = "${each.key}-application-load-balancer"
      }
      spec = merge(
        {
          ipAddressType          = "ipv4"
          inboundCIDRs           = try(each.value.inbound_cidrs, ["0.0.0.0/0"])
          loadBalancerAttributes = [for k, v in merge(local.access_logs_attributes, each.value.load_balancer_attributes) : { key = replace(k, "-", "."), value = tostring(v) }]

          namespaceSelector = {
            matchExpressions = each.value.namespace_selector.match_expressions
            matchLabels      = each.value.namespace_selector.match_labels
          }
          scheme    = each.key
          sslPolicy = "ELBSecurityPolicy-TLS13-1-2-2021-06"
          tags      = [for k, v in each.value.tags : { key = k, value = v }]
        },
      )
    }
  )

  depends_on = [
    # Ensure the Helm release has been applied so that the IngressClassParams CRD is available.
    helm_release.controller,
  ]
}

resource "kubernetes_ingress_class_v1" "predefined" {
  for_each = kubectl_manifest.ingress_class_params
  metadata {
    labels = local.labels
    name   = each.value.name
  }
  spec {
    controller = local.ingress_class_controller
    parameters {
      api_group = split("/", each.value.api_version)[0]
      kind      = each.value.kind
      name      = each.value.name
    }
  }
}
