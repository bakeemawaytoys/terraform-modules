terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 3.1.0"
    }
  }
  required_version = ">= 1.5.0"
}

locals {
  owned_resource_tags = merge(
    var.tags,
    {
      "kubernetes.io/cluster"                     = var.cluster_name
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  )
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# Create the role for the cluster to assume
# https://docs.aws.amazon.com/eks/latest/userguide/service_IAM_role.html
data "aws_iam_policy_document" "eks_trust_policy" {
  statement {
    principals {
      identifiers = ["eks.amazonaws.com"]
      type        = "Service"
    }
    actions = ["sts:AssumeRole"]
  }
}

moved {
  from = aws_iam_role.cluster_service_role
  to   = aws_iam_role.cluster_service_role["module"]
}

resource "aws_iam_role" "cluster_service_role" {
  # Selectively create the role using a for_each
  for_each           = var.predefined_cluster_role_name == null ? toset(["module"]) : toset([])
  assume_role_policy = data.aws_iam_policy_document.eks_trust_policy.json
  description        = "Service role for the ${var.cluster_name} cluster"
  name               = "${var.cluster_name}-eks-cluster-service-role"
  tags               = local.owned_resource_tags
}

moved {
  from = aws_iam_role_policy_attachment.cluster_service_role
  to   = aws_iam_role_policy_attachment.cluster_service_role["module"]
}

resource "aws_iam_role_policy_attachment" "cluster_service_role" {
  for_each   = aws_iam_role.cluster_service_role
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = each.value.name
}

data "aws_iam_role" "cluster_service_role" {
  # use a look up so that regardless of where the role comes from, all attributes will be available to the rest of the module.count.count.
  name = var.predefined_cluster_role_name == null ? aws_iam_role.cluster_service_role["module"].name : var.predefined_cluster_role_name
}

# Create the Cloudwatch log group prior to creating the cluster so that the cluster doesn't have to.
# This allows Terraform to manage the group without the need to import it after the fact.
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cluster_log_retention
  tags              = local.owned_resource_tags
}

# Create KMS CMK for encrypting k8s secrets
# No policy is specified so that the default policy is applied.
# The default policy allows the use of IAM policies to grant access.
resource "aws_kms_key" "cluster" {
  deletion_window_in_days = 14
  description             = "Encrypts the secrets in the ${var.cluster_name} EKS cluster"
  enable_key_rotation     = true
  tags                    = local.owned_resource_tags
}

resource "aws_kms_alias" "cluster" {
  name          = "alias/eks/cluster/${var.cluster_name}"
  target_key_id = aws_kms_key.cluster.id
}

# Create the role that CloudFormation will asssume to create and manage
# the cluster resource.  The role is also granted permanent admin
# access to the cluster because it creates the cluster.
# https://docs.aws.amazon.com/eks/latest/userguide/add-user-role.html.
# Using a dedicated role is considered best practice as per
# https://aws.github.io/aws-eks-best-practices/security/docs/iam/#create-the-cluster-with-a-dedicated-iam-role

data "aws_iam_roles" "sso_permission_set" {
  for_each    = var.administrator_sso_permission_sets
  name_regex  = "AWSReservedSSO_${each.value}_[a-z0-9]+$"
  path_prefix = "/aws-reserved/sso.amazonaws.com/us-west-2/"
}

locals {
  sso_iam_role_arns = flatten(values(data.aws_iam_roles.sso_permission_set)[*].arns)
}

data "aws_iam_policy_document" "cluster_owner_trust_policy" {
  statement {
    sid = "CloudFormationAccess"
    principals {
      type        = "Service"
      identifiers = ["cloudformation.amazonaws.com"]
    }
    actions = [
      "sts:AssumeRole"
    ]
    condition {
      test     = "StringEquals"
      values   = [data.aws_caller_identity.current.account_id]
      variable = "aws:SourceAccount"
    }
  }

  dynamic "statement" {
    # Wrap the ARNs in a list so that only one statement is created.
    for_each = length(local.sso_iam_role_arns) > 0 ? [local.sso_iam_role_arns] : []
    content {
      sid = "UserAdminAccess"
      principals {
        type        = "AWS"
        identifiers = statement.value
      }
      actions = [
        "sts:AssumeRole",
      ]
      condition {
        # Require the session name to match the value of the SAML subject.  For AWS SSO, this will be the user's email address.
        test     = "StringEquals"
        values   = ["$${saml:sub}"]
        variable = "sts:RoleSessionName"
      }
    }
  }

  dynamic "statement" {
    # Wrap the ARNs in a list so that only one statement is created.
    for_each = length(var.administrator_iam_principals) > 0 ? [var.administrator_iam_principals] : []
    content {
      sid = "AutomationAdminAccess"
      principals {
        type        = "AWS"
        identifiers = statement.value
      }
      actions = [
        "sts:AssumeRole",
      ]
      condition {
        # Prevent use of the session name used by CloudFormation when it assumes the role.
        # This will allow the statements in the policy to limit actions to CloudFormation.
        test     = "StringNotEquals"
        values   = ["AWSCloudFormation"]
        variable = "sts:RoleSessionName"
      }
    }
  }
}

locals {
  is_imported_cluster = var.cluster_creator_arn != null
  role_description    = local.is_imported_cluster ? "The role used to manage the ${var.cluster_name} EKS cluster resource" : "The role used to create the ${var.cluster_name} EKS cluster"
  role_name           = local.is_imported_cluster ? "${var.cluster_name}-eks-cluster-resource-manager" : "${var.cluster_name}-eks-cluster-owner"
}

moved {
  from = aws_iam_role.cluster_owner
  to   = aws_iam_role.cloudformation_role
}

resource "aws_iam_role" "cloudformation_role" {
  assume_role_policy = data.aws_iam_policy_document.cluster_owner_trust_policy.json
  description        = local.role_description
  name               = local.role_name
  tags               = local.owned_resource_tags
  lifecycle {
    precondition {
      condition = !local.is_imported_cluster || (local.is_imported_cluster && length(var.administrator_iam_principals) == 0)

      error_message = <<-EOF
      The 'administrator_iam_principals' variable cannot contain any values if the 'cluster_creator_arn' variable contains a value
      because the cluster manager role cannot be used to authenticate with the k8s API.  Use the ${coalesce(var.cluster_creator_arn, "placeholder so a null value is in the template")} IAM
      principal to access the k8s API as the cluster creator.

      From the EKS documentation (https://docs.aws.amazon.com/eks/latest/userguide/troubleshooting.html):
     "When an Amazon EKS cluster is created, the IAM entity (user or role) that creates the cluster is added to the Kubernetes RBAC authorization table as the administrator (with system:masters permissions). Initially, only that IAM user can make calls to the Kubernetes API server using kubectl ."
      EOF
    }
  }
}

# Define a limited policy for the cluster owner role to perform CRUD actions on the cluster.
# Given that the cluster owner role also has admin rights on the cluster, the role will
# also be assumed by principals other than CloudFormation.  To prevent those principals
# from create clusters, the policy requires the value of the aws:userid variable to match
# the value set by the CloudFormation service.  For this to work, the role's trust policy
# must prevent other principals from using the same session name as CloudFormation.
data "aws_iam_policy_document" "cloudformation_role" {

  statement {
    actions = [
      "eks:DescribeCluster",
      "eks:DescribeUpdate",
      "eks:ListTagsForResource",
      "eks:ListUpdates",
    ]
    resources = [
      "arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}",
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:userid"
      values   = ["${aws_iam_role.cloudformation_role.unique_id}:AWSCloudFormation"]
    }
  }

  statement {
    actions = [
      "eks:ListClusters",
    ]
    resources = [
      "*"
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:userid"
      values   = ["${aws_iam_role.cloudformation_role.unique_id}:AWSCloudFormation"]
    }
  }


  statement {
    actions = [
      "eks:CreateCluster",
    ]
    resources = [
      "*"
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:userid"
      values   = ["${aws_iam_role.cloudformation_role.unique_id}:AWSCloudFormation"]
    }
  }

  statement {
    actions = setunion(
      [
        "eks:TagResource",
        "eks:UntagResource",
        "eks:UpdateClusterConfig",
        "eks:UpdateClusterVersion",
      ],
      var.deletion_protection ? [] : ["eks:DeleteCluster"]
    )
    resources = [
      "arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}",
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:userid"
      values   = ["${aws_iam_role.cloudformation_role.unique_id}:AWSCloudFormation"]
    }
  }

  statement {
    actions = [
      "iam:PassRole"
    ]
    resources = [
      data.aws_iam_role.cluster_service_role.arn
    ]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["eks.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:userid"
      values   = ["${aws_iam_role.cloudformation_role.unique_id}:AWSCloudFormation"]
    }
  }

  # Permission to create grants on the
  # as described on https://docs.aws.amazon.com/eks/latest/userguide/create-cluster.html
  statement {
    sid = "DescribeSecretsEncryptionKey"
    actions = [
      "kms:DescribeKey",
    ]
    resources = [
      aws_kms_key.cluster.arn,
    ]
  }

  statement {
    sid = "CreateSecretsEncryptionGrant"
    actions = [
      "kms:CreateGrant",
    ]
    resources = [
      aws_kms_key.cluster.arn,
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:userid"
      values   = ["${aws_iam_role.cloudformation_role.unique_id}:AWSCloudFormation"]
    }
    condition {
      test     = "StringEquals"
      values   = ["eks.${data.aws_region.current.name}.amazonaws.com"]
      variable = "kms:ViaService"
    }
  }
}

moved {
  from = aws_iam_role_policy.cluster_owner
  to   = aws_iam_role_policy.cloudformation_role
}

resource "aws_iam_role_policy" "cloudformation_role" {
  policy = data.aws_iam_policy_document.cloudformation_role.json
  role   = aws_iam_role.cloudformation_role.name
}

# Create the cluster using CloudFormation.  By using CloudFormation, the cluster can be created with
# a dedicated IAM role while still managing it with the role assumed by Terraform.
# This is also an attempt at an alternative solution to the issues described at
# https://github.com/hashicorp/terraform-provider-kubernetes/blob/main/_examples/eks/README.md

locals {

  cluster_creator = coalesce(var.cluster_creator_arn, aws_iam_role.cloudformation_role.arn)

  enabled_logging_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  cloudformation_template = {
    AWSTemplateFormatVersion = "2010-09-09"
    Description              = "The ${var.cluster_name} EKS cluster"
    Parameters = {
      KubernetesVersion = {
        Type          = "String"
        AllowedValues = ["1.23", "1.24", "1.25", "1.26", "1.27"]
        Description   = "The Kubernetes version to use in the EKS cluster"
      }
    }
    Resources = {
      Cluster = {
        Type = "AWS::EKS::Cluster"
        # Include a deletion policy so that the cluster can be imported if necessary.
        DeletionPolicy = "Delete"
        Properties = {
          EncryptionConfig = [
            {
              Provider = {
                KeyArn = aws_kms_key.cluster.arn
              }
              Resources = ["secrets"]
            }
          ]
          KubernetesNetworkConfig = {
            IpFamily        = "ipv4"
            ServiceIpv4Cidr = var.cluster_ipv4_cidr_block
          }
          Logging = {
            ClusterLogging = {
              EnabledTypes = [for t in local.enabled_logging_types : { Type = t }]
            }
          }
          Name = var.cluster_name
          ResourcesVpcConfig = {
            EndpointPrivateAccess = var.endpoint_private_access
            EndpointPublicAccess  = var.endpoint_public_access
            SubnetIds             = var.subnet_ids
            SecurityGroupIds      = var.additional_security_group_identifiers

          }
          RoleArn = data.aws_iam_role.cluster_service_role.arn
          Tags = [
            {
              Key   = "cluster_creator_arn"
              Value = local.cluster_creator
            }
          ]
          Version = { "Ref" = "KubernetesVersion" }
        }
      }
    }
    Outputs = {
      ClusterArn = {
        Description = "The ARN of the cluster."
        Value       = { "Fn::GetAtt" = ["Cluster", "Arn"] }
      }
      CertificateAuthorityData = {
        Description = "The certificate-authority-data of the cluster."
        Value       = { "Fn::GetAtt" = ["Cluster", "CertificateAuthorityData"] }
      }
      ClusterName = {
        Description = "The name of the EKS cluster."
        Value       = { "Ref" = "Cluster" }
      }
      ClusterSecurityGroupId = {
        Description = "The cluster security group that was created by Amazon EKS for the cluster."
        Value       = { "Fn::GetAtt" = ["Cluster", "ClusterSecurityGroupId"] }
      }
      ClusterEndpoint = {
        Description = "The endpoint for the K8s API"
        Value       = { "Fn::GetAtt" = ["Cluster", "Endpoint"] }
      },
      KubernetesVersion = {
        Description = "The version of Kubernetes running in the cluster."
        Value       = { "Ref" = "KubernetesVersion" }
      }
      OpenIdConnectIssuerUrl = {
        Description = "The issuer URL for the cluster's OIDC identity provider."
        Value       = { "Fn::GetAtt" = ["Cluster", "OpenIdConnectIssuerUrl"] }
      }
    }
  }

  stack_policy = {
    Statement = concat(
      [
        {
          "Effect"    = "Allow"
          "Action"    = "Update:*"
          "Principal" = "*"
          "Resource"  = "*"
        },
      ],
      # Add a Deny statement if deletion protection is enabled
      var.deletion_protection ?
      [
        {
          "Effect" = "Deny"
          # Prevent destruction of the cluster when updating the stack
          "Action"    = ["Update:Replace", "Update:Delete"]
          "Principal" = "*"
          "Resource"  = "*"
          "Condition" = {
            "StringEquals" = {
              "ResourceType" = ["AWS::EKS::Cluster", ]
            }
          }
        }
      ] : []
    )
  }
}

resource "aws_cloudformation_stack" "cluster" {
  name          = "${var.cluster_name}-eks-cluster"
  iam_role_arn  = aws_iam_role.cloudformation_role.arn
  policy_body   = jsonencode(local.stack_policy)
  template_body = jsonencode(local.cloudformation_template)

  parameters = {
    "KubernetesVersion" = var.k8s_version
  }

  # Ensure all of the necessary resources exist before attempting to create the stack
  depends_on = [
    aws_cloudwatch_log_group.cluster,
    aws_kms_key.cluster,
    aws_iam_role_policy_attachment.cluster_service_role,
    aws_iam_role_policy.cloudformation_role,
  ]
  tags = merge(
    local.owned_resource_tags,
    {
      cluster_creator_arn = local.cluster_creator
    }
  )
}

data "aws_eks_cluster" "cluster" {
  name = aws_cloudformation_stack.cluster.outputs["ClusterName"]
}

data "aws_default_tags" "current" {}

resource "aws_ec2_tag" "cluster_security_group" {
  for_each    = merge(data.aws_default_tags.current.tags, var.tags, { managed_with = "eks" })
  resource_id = aws_cloudformation_stack.cluster.outputs["ClusterSecurityGroupId"] #data.aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id
  key         = each.key
  value       = each.value

  lifecycle {
    # The cluster security group ID will never change because EKS doesn't allow it to be modified.  It can be ignored so
    # that Terraform doesn't try to recreate this resource when the CloudFormation stack outputs change.
    ignore_changes = [resource_id]
  }
}

locals {
  # Use the resource ID of the managed_with tag to get the cluster's security group ID to avoid
  # depending on the output of the CloudFormation stack resource.  This will ensure Terraform
  # doesn't try to recreate every resource when the CloudFormation stack is modified.  For this
  # to hold true, the aws_ec2_tag.cluster_security_group resource must ignore changes to the
  # resource_id attribute.
  cluster_security_group_id = aws_ec2_tag.cluster_security_group["managed_with"].resource_id
}

# Create an IAM OIDC provider to enable IAM roles for service accounts in the cluster.
# https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html
data "tls_certificate" "cluster" {
  url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  url             = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  tags            = local.owned_resource_tags
  lifecycle {
    # The cluster's OIDC URL will never change.  Ignoring the url attribute will prevent Terraform from recreating this resource when the CloudFormation stack is modified.
    ignore_changes = [url]
  }
}

resource "aws_accessanalyzer_archive_rule" "oidc_provider_role" {
  analyzer_name = var.access_analyzer_name
  rule_name     = "${var.cluster_name}-eks-cluster-oidc-provider-role"
  filter {
    criteria = "principal.Federated"
    eq       = [aws_iam_openid_connect_provider.cluster.arn]
  }
}

# Setup the eks-managed add-ons

locals {
  oidc_provider_id       = replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")
  oidc_audience_variable = "${local.oidc_provider_id}:aud"
  oidc_subject_variable  = "${local.oidc_provider_id}:sub"
}

# Create the IAM role for the VPC-CNI add-on
data "aws_iam_policy_document" "vpc_cni_trust_policy" {
  statement {
    principals {
      identifiers = [aws_iam_openid_connect_provider.cluster.arn]
      type        = "Federated"
    }
    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]
    condition {
      test     = "StringEquals"
      values   = ["system:serviceaccount:kube-system:aws-node"]
      variable = local.oidc_subject_variable
    }
    condition {
      test     = "StringEquals"
      values   = ["sts.amazonaws.com"]
      variable = local.oidc_audience_variable
    }
  }
}

resource "aws_iam_role" "vpc_cni" {
  assume_role_policy = data.aws_iam_policy_document.vpc_cni_trust_policy.json
  description        = "The VPC-CNI add-on in the ${var.cluster_name} EKS cluster"
  name               = "${var.cluster_name}-eks-cluster-vpc-cni-addon"
  tags               = local.owned_resource_tags
}

resource "aws_iam_role_policy_attachment" "vpc_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.vpc_cni.name
}

# Create an inline policy to support clusters with IPv6 enabled.
# https://docs.aws.amazon.com/eks/latest/userguide/cni-iam-role.html#cni-iam-role-create-ipv6-policy
data "aws_iam_policy_document" "vpc_cni" {
  statement {
    sid = "IPv6ClusterSupport"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeTags",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeInstanceTypes"
    ]
    resources = ["*"]
  }
  statement {
    sid = "ModifyInterfaces"
    actions = [
      "ec2:AssignIpv6Addresses",
      "ec2:CreateTags"
    ]
    resources = [
      "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:network-interface/*",
    ]
    condition {
      test     = "ArnEquals"
      values   = ["arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:vpc/${data.aws_eks_cluster.cluster.vpc_config[0].vpc_id}"]
      variable = "ec2:Vpc"
    }
  }
}

resource "aws_iam_role_policy" "vpc_cni" {
  policy = data.aws_iam_policy_document.vpc_cni.json
  role   = aws_iam_role.vpc_cni.name
}

data "aws_eks_addon_version" "vpc_cni" {
  addon_name         = "vpc-cni"
  kubernetes_version = var.k8s_version
  most_recent        = var.vpc_cni_version == "latest"
}

resource "aws_eks_addon" "vpc_cni" {
  addon_name                  = data.aws_eks_addon_version.vpc_cni.addon_name
  addon_version               = contains(["latest", "default"], var.vpc_cni_version) ? data.aws_eks_addon_version.vpc_cni.version : var.vpc_cni_version
  cluster_name                = var.cluster_name
  preserve                    = true
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = aws_iam_role.vpc_cni.arn
  tags                        = local.owned_resource_tags
}

data "aws_eks_addon_version" "coredns" {
  addon_name         = "coredns"
  kubernetes_version = var.k8s_version
  most_recent        = var.coredns_version == "latest"
}

resource "aws_eks_addon" "coredns" {
  count                       = lower(var.coredns_version) == "none" ? 0 : 1
  addon_name                  = data.aws_eks_addon_version.coredns.addon_name
  addon_version               = contains(["latest", "default"], var.coredns_version) ? data.aws_eks_addon_version.coredns.version : var.coredns_version
  cluster_name                = var.cluster_name
  preserve                    = true
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = local.owned_resource_tags
}

data "aws_eks_addon_version" "kube_proxy" {
  addon_name         = "kube-proxy"
  kubernetes_version = var.k8s_version
  most_recent        = var.kube_proxy_version == "latest"
}

resource "aws_eks_addon" "kube_proxy" {
  addon_name                  = data.aws_eks_addon_version.kube_proxy.addon_name
  addon_version               = contains(["latest", "default"], var.kube_proxy_version) ? data.aws_eks_addon_version.kube_proxy.version : var.kube_proxy_version
  cluster_name                = var.cluster_name
  preserve                    = true
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = local.owned_resource_tags
}

resource "aws_resourcegroups_group" "automation_k8s_cluster" {
  description = "Resources owned by the ${var.cluster_name} EKS cluster"
  name        = "${var.cluster_name}-eks-cluster"
  resource_query {
    query = jsonencode(
      {
        ResourceTypeFilters = ["AWS::AllSupported"]
        TagFilters = [
          {
            Key    = "kubernetes.io/cluster/${var.cluster_name}"
            Values = ["owned"]
          }
        ]
      }
    )
  }
  tags = local.owned_resource_tags
}
