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
    time = {
      source  = "hashicorp/time"
      version = "~> 0.8"
    }
  }
  required_version = ">= 1.5"
}

locals {
  labels = merge(
    var.labels,
    {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  )
}

###################################################
# Install the Custom Resource Definitions
###################################################

locals {
  crd_directory = "${path.module}/files/crds/${var.chart_version}"
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

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_default_tags" "current" {}

locals {

  node_subnet_arns    = var.node_subnets[*].arn
  security_group_ids  = setunion([var.eks_cluster.cluster_security_group_id], var.node_security_group_ids)
  security_group_arns = formatlist("arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:security-group/%s", local.security_group_ids)
}

locals {
  # Tags for the resources managed by Terraform
  tags = merge(
    var.tags,
    {
      "kubernetes.io/cluster"                                 = var.eks_cluster.cluster_name
      "kubernetes.io/cluster/${var.eks_cluster.cluster_name}" = "owned"
    }
  )
}

resource "kubernetes_namespace_v1" "karpenter" {
  metadata {
    name = "karpeneter"
    labels = merge(
      local.labels,
      { for mode, level in var.pod_security_standards : "pod-security.kubernetes.io/${mode}" => level },
      {
        "goldilocks.fairwinds.com/enabled" : tostring(var.enable_goldilocks)
      }
    )
  }
}

data "aws_iam_role" "fargate" {
  name = var.fargate_pod_execution_role_name
}

# Use a time_static resource to generate a new fargate profile name suffix any time one of the
# profile's static attributes changes.  This allow the resource to use the create_before_destroy lifecycle
# attribute so that a new profile will be available for Karpenter before the old one is destroyed.
# See https://docs.aws.amazon.com/eks/latest/userguide/fargate-profile.html#delete-fargate-profile for details
# on Fargate's scheduling behavior to understand why this is necessary.
resource "time_static" "fargate_profile" {
  triggers = {
    cluster_name           = var.eks_cluster.cluster_name
    namespace              = kubernetes_namespace_v1.karpenter.metadata[0].name
    pod_execution_role_arn = data.aws_iam_role.fargate.arn
    subnet_ids             = join(",", sort(var.fargate_pod_subnets[*].id))
  }
}

resource "aws_eks_fargate_profile" "karpenter" {
  # Reference the values through the triggers to ensure the same value is used with both resources.
  cluster_name           = time_static.fargate_profile.triggers.cluster_name
  fargate_profile_name   = "karpenter-${time_static.fargate_profile.unix}"
  pod_execution_role_arn = time_static.fargate_profile.triggers.pod_execution_role_arn
  subnet_ids             = split(",", time_static.fargate_profile.triggers.subnet_ids)

  selector {
    namespace = time_static.fargate_profile.triggers.namespace
  }

  tags = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_iam_instance_profile" "cluster_node" {
  name = var.instance_profile_name
}

locals {
  service_account_name = "karpenter-controller"
}

module "karpenter_iam_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.3"

  oidc_providers = {
    main = {
      provider_arn = var.eks_cluster.service_account_oidc_provider_arn
      namespace_service_accounts = [
        "${kubernetes_namespace_v1.karpenter.metadata[0].name}:${local.service_account_name}"
      ]
    }
  }

  role_description = "Karpenter running in the ${var.eks_cluster.cluster_name} EKS cluster"
  role_name        = "${var.eks_cluster.cluster_name}-eks-cluster-karpenter-controller"
  tags             = local.tags
}

locals {

  # Tags that are required to be present in all templates
  required_node_template_tags = {
    managed_with = "karpenter"
  }

  # The set of tags Karpenter must include on the resources it creates as enforced by IAM.
  iam_enforced_karpenter_resource_tags = merge(
    local.required_node_template_tags,
    {
      # Karpenter always adds these tags.
      "karpenter.sh/provisioner-name"                         = "*"
      "kubernetes.io/cluster/${var.eks_cluster.cluster_name}" = "owned"
    },
  )
}

# The EC2 permissions are based on the example policy in the Getting Started CloudFormation template.
# https://github.com/aws/karpenter/blob/main/website/content/en/v0.19.2/getting-started/getting-started-with-eksctl/cloudformation.yaml
data "aws_iam_policy_document" "karpenter" {

  # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ExamplePolicies_EC2.html#iam-example-region
  statement {
    sid    = "RestrictRegion"
    effect = "Deny"
    actions = [
      "ec2:*"
    ]
    resources = ["*"]
    condition {
      test     = "StringNotEquals"
      values   = [data.aws_region.current.name]
      variable = "ec2:Region"
    }
  }

  statement {
    sid = "CreateEc2Resource"
    actions = [
      "ec2:CreateLaunchTemplate",
      "ec2:CreateFleet",
    ]
    # The combination of the conditions on this statement and the region restriction statement provide the necessary limits on the wildcard
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = ["*"]
    dynamic "condition" {
      for_each = local.iam_enforced_karpenter_resource_tags
      content {
        test     = "StringLike"
        values   = [condition.value]
        variable = "aws:RequestTag/${condition.key}"
      }
    }
  }

  statement {
    sid = "Ec2Tagging"
    actions = [
      "ec2:CreateTags",
    ]
    # The combination of the conditions on this statement and the region restriction statement provide the necessary limits on the wildcard
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = ["*"]
    # Limit tagging to the resource types Karpenter manages
    condition {
      test = "StringEquals"
      values = [
        "CreateLaunchTemplate",
        "CreateFleet",
        "RunInstances"
      ]
      variable = "ec2:CreateAction"
    }
  }

  statement {
    sid = "SpotPricing"
    actions = [
      "pricing:GetProducts",
    ]
    resources = ["*"]
  }

  statement {
    sid = "EC2Read"
    actions = [
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeSpotPriceHistory",
    ]
    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "ec2:TerminateInstances",
      "ec2:DeleteLaunchTemplate",
    ]
    # The combination of the conditions on this statement and the region restriction statement provide the necessary limits on the wildcard
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = ["*"]
    # Restrict the actions to the resources owned by this Karpenter instance
    dynamic "condition" {
      for_each = local.iam_enforced_karpenter_resource_tags
      content {
        test     = "StringLike"
        values   = [condition.value]
        variable = "aws:ResourceTag/${condition.key}"
      }
    }
  }

  statement {
    actions = [
      "ec2:CreateFleet",
      "ec2:RunInstances",
    ]
    resources = [
      "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:launch-template/*",
    ]
    # Restrict to templates created by karpenter
    dynamic "condition" {
      for_each = local.iam_enforced_karpenter_resource_tags
      content {
        test     = "StringLike"
        values   = [condition.value]
        variable = "aws:ResourceTag/${condition.key}"
      }
    }
  }

  statement {
    sid = "RunWithSpecificResources"
    actions = [
      "ec2:CreateFleet",
      "ec2:RunInstances",
    ]
    resources = concat(
      local.security_group_arns,
      local.node_subnet_arns,
    )
  }

  statement {
    sid = "RestrctAMIs"
    actions = [
      "ec2:CreateFleet",
      "ec2:RunInstances",
    ]
    # The combination of the conditions on this statement and the region restriction statement provide the necessary limits on the wildcard
    # Also, the images are dynamically determened by reading an SSM parameter so resources ARNs would be impossible to use.
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = ["arn:aws:ec2:*::image/*"]
    condition {
      test = "StringEquals"
      values = [
        "amazon",
      ]
      variable = "ec2:Owner"
    }
  }

  statement {
    actions = [
      "ec2:CreateFleet",
      "ec2:RunInstances",
    ]
    resources = [
      "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:network-interface/*",
    ]
    condition {
      test     = "StringEquals"
      values   = local.node_subnet_arns
      variable = "ec2:Subnet"
    }
  }

  statement {
    actions = [
      "ec2:CreateFleet",
      "ec2:RunInstances",
    ]
    resources = [
      "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:instance/*",
      "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:volume/*",
    ]
    # Enforce tagging requirements on the resources that can be tagged
    dynamic "condition" {
      for_each = local.iam_enforced_karpenter_resource_tags
      content {
        test     = "StringLike"
        values   = [condition.value]
        variable = "aws:RequestTag/${condition.key}"
      }
    }
  }

  statement {
    sid     = "EksAmiLookUp"
    actions = ["ssm:GetParameter"]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.name}::parameter/aws/service/*",
    ]
  }

  statement {
    sid       = "AllowedInstanceProfiles"
    actions   = ["iam:PassRole"]
    resources = [data.aws_iam_instance_profile.cluster_node.role_arn]
  }
}

resource "aws_iam_role_policy" "karpenter" {
  name_prefix = "run-instances-"
  policy      = data.aws_iam_policy_document.karpenter.json
  role        = module.karpenter_iam_role.iam_role_name
}

# Prevent instances from launching that would allow pods to access the instance metadata.
# https://aws.github.io/aws-eks-best-practices/security/docs/iam/#restrict-access-to-the-instance-profile-assigned-to-the-worker-node
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ExamplePolicies_EC2.html#iam-example-instance-metadata
data "aws_iam_policy_document" "instance_metadata" {
  statement {
    sid    = "MaxImdsHopLimit"
    effect = "Deny"
    actions = [
      "ec2:RunInstances",
    ]
    resources = [
      "arn:aws:ec2:*:*:instance/*",
    ]
    condition {
      test     = "NumericGreaterThan"
      values   = ["1"]
      variable = "ec2:MetadataHttpPutResponseHopLimit"
    }
  }

  statement {
    sid    = "RequireImdsV2"
    effect = "Deny"
    actions = [
      "ec2:RunInstances",
    ]
    resources = [
      "arn:aws:ec2:*:*:instance/*",
    ]
    condition {
      test     = "StringNotEquals"
      values   = ["required"]
      variable = "ec2:MetadataHttpTokens"
    }
  }
}

resource "aws_iam_role_policy" "instance_metadata" {
  role        = module.karpenter_iam_role.iam_role_name
  name_prefix = "instance-metadata-"
  policy      = data.aws_iam_policy_document.instance_metadata.json
}

data "aws_iam_policy_document" "eks" {
  statement {
    sid = "DiscoverClusterAttributes"
    actions = [
      "eks:DescribeCluster"
    ]
    resources = ["arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/${var.eks_cluster.cluster_name}"]
  }
}

resource "aws_iam_role_policy" "eks" {
  role        = module.karpenter_iam_role.iam_role_name
  name_prefix = "eks-"
  policy      = data.aws_iam_policy_document.eks.json
}

#####################################
# Instance interruption notifications
#####################################

# The notification resources are modeled after the CloudFormation template in the Getting Started guide
# https://github.com/aws/karpenter/blob/main/website/content/en/v0.19.2/getting-started/getting-started-with-eksctl/cloudformation.yaml

resource "aws_sqs_queue" "interruption_notification" {
  message_retention_seconds = 300
  name                      = "${var.eks_cluster.cluster_name}-eks-cluster-karpenter-instance-notifications"
  sqs_managed_sse_enabled   = true
  tags                      = local.tags
}

resource "aws_cloudwatch_event_rule" "interruption_notification" {
  for_each = {
    "AWS Health Event"                       = "aws.health"
    "EC2 Spot Instance Interruption Warning" = "aws.ec2"
    "EC2 Instance Rebalance Recommendation"  = "aws.ec2"
    "EC2 Instance State-change Notification" = "aws.ec2"
  }
  description = "${each.key} for Karpenter instances in the ${var.eks_cluster.cluster_name} EKS cluster"
  name_prefix = "${var.eks_cluster.cluster_name}-karpenter-"
  event_pattern = jsonencode(
    {
      "source"      = [each.value]
      "detail-type" = [each.key]
    }
  )
  tags = local.tags
}

resource "aws_cloudwatch_event_target" "interruption_notification" {
  for_each  = aws_cloudwatch_event_rule.interruption_notification
  arn       = aws_sqs_queue.interruption_notification.arn
  target_id = "KarpenterInterruptionQueue"
  rule      = each.value.name
}

data "aws_iam_policy_document" "interruption_notification_queue_policy" {

  # https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-use-resource-based.html#eb-sqs-permissions
  statement {
    sid = "EventBridgeAccess"
    principals {
      identifiers = [
        "events.amazonaws.com",
      ]
      type = "Service"
    }
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.interruption_notification.arn]

    condition {
      test     = "ArnEquals"
      values   = values(aws_cloudwatch_event_rule.interruption_notification)[*].arn
      variable = "aws:SourceArn"
    }
  }
}

resource "aws_sqs_queue_policy" "interruption_notification" {
  policy    = data.aws_iam_policy_document.interruption_notification_queue_policy.json
  queue_url = aws_sqs_queue.interruption_notification.url
}

data "aws_iam_policy_document" "interruption_notification" {
  statement {
    actions = [
      "sqs:DeleteMessage",
      "sqs:GetQueueUrl",
      "sqs:GetQueueAttributes",
      "sqs:ReceiveMessage",
    ]
    resources = [aws_sqs_queue.interruption_notification.arn]
  }
}

resource "aws_iam_role_policy" "interruption_notification" {
  name_prefix = "interruption-notification-events-"
  policy      = data.aws_iam_policy_document.interruption_notification.json
  role        = module.karpenter_iam_role.iam_role_name
}

resource "aws_cloudwatch_metric_alarm" "queue_depth" {
  actions_enabled     = var.cloudwatch_alarms.queue_depth_alarm.actions_enabled
  alarm_actions       = var.cloudwatch_alarms.actions
  alarm_description   = <<-EOF
  Monitors the depth of the SQS instance notification queue used by the Karpenter deployment in the ${var.eks_cluster.cluster_name} EKS cluster.
  If this alarm triggers, it indicates Karpenter is either down or unable to consume messages from the queue.
  EOF
  alarm_name          = "karpenter-${var.eks_cluster.cluster_name}-eks-cluster-instance-notification-queue-depth"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  dimensions = {
    "QueueName" = aws_sqs_queue.interruption_notification.name
  }
  evaluation_periods        = var.cloudwatch_alarms.queue_depth_alarm.evaluation_periods
  insufficient_data_actions = var.cloudwatch_alarms.actions
  metric_name               = "ApproximateNumberOfMessagesVisible"
  namespace                 = "AWS/SQS"
  ok_actions                = var.cloudwatch_alarms.actions
  period                    = var.cloudwatch_alarms.queue_depth_alarm.period
  statistic                 = "Sum"
  threshold                 = var.cloudwatch_alarms.queue_depth_alarm.threshold
  treat_missing_data        = "breaching"
  tags                      = local.tags
}

#####################################
# Helm Release
#####################################

resource "helm_release" "karpenter" {
  atomic           = true
  create_namespace = false
  chart            = "karpenter"
  cleanup_on_fail  = true
  description      = "Karpenter node provisioner"
  max_history      = 5
  name             = "karpenter"
  namespace        = kubernetes_namespace_v1.karpenter.metadata[0].name
  repository       = "oci://public.ecr.aws/karpenter"
  skip_crds        = true
  version          = var.chart_version
  wait_for_jobs    = true

  values = [
    yamlencode({
      additionalLabels = local.labels
      controller = {
        image = {
          repository = "${var.karpenter_image_registry}/karpenter/controller"
        }
        resources = var.pod_resources
        # Remove this security context once the module drops support for versions less than 0.31.
        securityContext = {
          allowPrivilegeEscalation = false
          capabilities = {
            drop = ["ALL"]
          }
          readOnlyRootFilesystem = true
        }
      }
      logEncoding = "json"
      logLevel    = "debug"
      podLabels   = local.labels
      # Remove this security context once the module drops support for versions less than 0.31.
      podSecurityContext = {
        # The fsGroup is from the default value in the Helm chart.
        fsGroup      = 1000
        runAsNonRoot = true
        seccompProfile = {
          type = "RuntimeDefault"
        }
      }
      replicas = var.replicas
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = module.karpenter_iam_role.iam_role_arn
          # Use the regional STS endpoints to support private link endpoints and reduce implicit dependencies on us-east-1
          # The regional endpoint is set to true by default on the latest EKS platforms, but not all clusters on the latest version.
          # https://docs.aws.amazon.com/eks/latest/userguide/platform-versions.html
          # https://github.com/aws/amazon-eks-pod-identity-webhook
          "eks.amazonaws.com/sts-regional-endpoints" = "true"
        }
        name = local.service_account_name
      }
      serviceMonitor = {
        enabled = var.service_monitor.enabled
        endpointConfig = {
          interval = var.service_monitor.scrape_interval
        }
      }
      settings = {
        aws = {
          clusterName            = var.eks_cluster.cluster_name
          defaultInstanceProfile = data.aws_iam_instance_profile.cluster_node.name
          interruptionQueueName  = aws_sqs_queue.interruption_notification.name
        }
      }
    })
  ]

  depends_on = [
    # Ensure all permissions are in place
    aws_iam_role_policy.karpenter,
    aws_iam_role_policy.instance_metadata,
    aws_iam_role_policy.eks,
    # Wait for the Fargate profile to ensure the pods are deployed to Fargate
    aws_eks_fargate_profile.karpenter,
    # Ensure the CRDs are installed and up-to-date
    kubectl_manifest.crd,
  ]
}

###################################
# Default node template resources
###################################

locals {

  node_security_group_selector = join(",", local.security_group_ids)

  node_subnet_id_selector = join(",", sort(var.node_subnets[*].id))

  # Prevent pods from accessing the instance metadata service
  metadata_options = {
    httpEndpoint            = "enabled"
    httpProtocolIPv6        = "disabled"
    httpPutResponseHopLimit = 1
    httpTokens              = "required"
  }

  # - Configure set the Kubelet registry QPS and burst settings to a high value to avoid pull failures when a large number of
  #   Gitlab CI pods are scheduled on a new node. https://github.com/aws/karpenter/issues/1269
  registry_qps   = 50
  registry_burst = 100
  security_group_selector = {
    aws-ids = local.node_security_group_selector
  }
  subnet_selector = {
    aws-ids = local.node_subnet_id_selector
  }

  unfiltered_template_tags = merge(
    data.aws_default_tags.current.tags,
    local.required_node_template_tags,
  )

  # As of version 0.28, Karpenter does not allow certain tags to be set in the provider templates
  # Remove them from the common set of template tags to ensure they aren't included.
  # https://karpenter.sh/docs/upgrade-guide/#upgrading-to-v0280
  tags_owned_by_karpenter = [
    "kubernetes.io/cluster/${var.eks_cluster.cluster_name}",
    "karpenter.sh/managed-by",
    "karpenter.sh/provisioner-name",
    # The Name tag isn't blocked by Karpenter but it shouldn't be overriden.
    "Name",
  ]
  common_template_tags = { for k, v in local.unfiltered_template_tags : k => v if !contains(local.tags_owned_by_karpenter, k) }
}

resource "kubectl_manifest" "karpenter_bottlerocket_node_template" {
  yaml_body = yamlencode(
    {
      apiVersion = "karpenter.k8s.aws/v1alpha1"
      kind       = "AWSNodeTemplate"
      metadata = {
        labels = local.labels
        name   = "bottlerocket"
      }
      spec = {
        amiFamily = "Bottlerocket"
        blockDeviceMappings = [
          {
            deviceName = "/dev/xvda"
            ebs = {
              volumeType = "gp3"
              # 4Gi is the size in the AMI
              volumeSize          = "4Gi"
              deleteOnTermination = true
            }
          },
          {
            deviceName = "/dev/xvdb"
            ebs = {
              volumeType          = "gp3"
              volumeSize          = "${var.node_volume_size}Gi"
              deleteOnTermination = true
            }
          },
        ]
        metadataOptions       = local.metadata_options
        securityGroupSelector = local.security_group_selector
        subnetSelector        = local.subnet_selector
        tags = merge(
          local.common_template_tags,
          {
            operating_system = "bottlerocket"
          },
        )

        userData = <<-EOF
        [settings]

        %{for mirror in var.container_registry_mirrors}
        [[settings.container-registry.mirrors]]
        registry = "${mirror.registry}"
        endpoint = [ "${mirror.endpoint}" ]

        %{endfor~}

        [settings.metrics]
        send-metrics = false

        [settings.kernel]
        lockdown = "confidentiality"

        [settings.kubernetes]
        registry-qps = ${local.registry_qps}
        registry-burst = ${local.registry_burst}
      EOF
      }
    }
  )

  depends_on = [
    kubectl_manifest.crd,
    helm_release.karpenter,
  ]
}

###################################
# Provisioner resources
###################################

locals {
  standard_requirements = [
    {
      key      = "karpenter.k8s.aws/instance-hypervisor"
      operator = "In"
      values   = ["nitro"]
    },
    {
      key      = "kubernetes.io/os"
      operator = "In"
      values   = ["linux"]
    }
  ]
}

resource "kubectl_manifest" "provisioner" {
  for_each = var.provisioners

  force_conflicts = true

  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1alpha5"
    kind       = "Provisioner"
    metadata = {
      labels = local.labels
      name   = each.key
    }
    spec = merge(
      {
        annotations   = each.value.annotations
        consolidation = each.value.consolidation
        kubeletConfiguration = {
          containerRuntime = "containerd"
        }
        labels = each.value.labels
        limits = each.value.limits
        providerRef = {
          apiVersion = kubectl_manifest.karpenter_bottlerocket_node_template.api_version
          kind       = kubectl_manifest.karpenter_bottlerocket_node_template.kind
          name       = kubectl_manifest.karpenter_bottlerocket_node_template.name
        }
        requirements = concat(local.standard_requirements, each.value.requirements)
        # Filter out optional attributes in the taints (i.e. the value attribute).
        startupTaints = [for taint in each.value.startupTaints : { for k, v in taint : k => v if v != null }]
        taints        = [for taint in each.value.taints : { for k, v in taint : k => v if v != null }]
      },
      # Only include optional values if they where supplied.
      each.value.ttlSecondsAfterEmpty == null ? {} : { ttlSecondsAfterEmpty = each.value.ttlSecondsAfterEmpty },
      each.value.ttlSecondsUntilExpired == null ? {} : { ttlSecondsUntilExpired = each.value.ttlSecondsUntilExpired },
      each.value.weight == null ? {} : { weight = each.value.weight },
    )
  })

  lifecycle {
    precondition {
      condition     = (each.value.consolidation.enabled && each.value.ttlSecondsAfterEmpty == null) || !each.value.consolidation.enabled
      error_message = "Provisioners cannot have specify a value for ttlSecondsAfterEmpty if consolidation is enabled."
    }
  }
}

#####################################
# Grafana Integration
#####################################

# The dashboards are found in the Github project in the source for the eksctl Getting Started documentation.
# https://github.com/aws/karpenter/tree/main/website/content/en/v0.19.3/getting-started/getting-started-with-eksctl
# https://karpenter.sh/v0.20.0/gettiSng-started/getting-started-with-eksctl/#deploy-a-temporary-prometheus-and-grafana-stack-optional
locals {
  dashboards_directory = "${path.module}/files/dashboards/${var.chart_version}"
  dashboard_file_names = fileset(local.dashboards_directory, "*")
}

# Install the dashboards as discoverable configmaps as described in the Grafana Helm chart's README file.
# https://github.com/grafana/helm-charts/tree/main/charts/grafana#sidecar-for-dashboards
resource "kubernetes_config_map_v1" "grafana_dashboard" {
  for_each = var.grafana_dashboard_config == null ? [] : local.dashboard_file_names
  metadata {
    annotations = {
      (var.grafana_dashboard_config.folder_annotation_key) = "Karpenter"
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
