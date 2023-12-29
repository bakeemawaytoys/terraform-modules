terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5"
    }
  }
  required_version = ">= 1.6"
}

data "aws_region" "current" {}

locals {
  # The version corresponds to the Github release used as the basis
  # for the Fluent Bit resources. For the full list of releases,
  # check https://github.com/aws-samples/amazon-cloudwatch-container-insights/releases
  version = "1.3.18"

  required_labels = {
    "app.kubernetes.io/managed-by" = "terraform"
  }

  insights_labels = merge(
    var.labels,
    local.required_labels,
    {
      "app.kubernetes.io/instance" = "ec2"
      "app.kubernetes.io/part-of"  = "cloudwatch-container-insights"
      "app.kubernetes.io/version"  = local.version
    }
  )

  all_tags = merge(
    var.tags,
    {
      "kubernetes.io/cluster"                     = var.cluster_name
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  )

  iam_role_name_prefix = "${lower(var.cluster_name)}-eks-cluster"
}

resource "kubernetes_namespace_v1" "cloudwatch" {
  metadata {
    name = var.namespace
    labels = merge(
      local.insights_labels,
      {
        "goldilocks.fairwinds.com/enabled" : tostring(var.enable_goldilocks)
        "pod-security.kubernetes.io/enforce" = "privileged"
      }
    )
  }
}

############################
# CloudWatch agent resources
############################
locals {

  cloudwatch_agent_labels = merge(
    local.insights_labels,
    {
      "app.kubernetes.io/component" = "metrics-agent"
      "app.kubernetes.io/name"      = "amazon-cloudwatch"
    }
  )

  cloudwatch_agent_service_account_name = "cloudwatch-agent"
}

resource "aws_cloudwatch_log_group" "container_insights_metrics" {
  name              = "/aws/containerinsights/${var.cluster_name}/performance"
  retention_in_days = var.log_retention_in_days
  tags              = local.all_tags
}

module "cloudwatch_agent_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-eks-role"
  version = "5.3.0"

  role_description = "AWS CloudWatch agent for Container Insights"
  role_name        = "${local.iam_role_name_prefix}-cloudwatch-agent"

  cluster_service_accounts = {
    (var.cluster_name) = ["${kubernetes_namespace_v1.cloudwatch.metadata[0].name}:${local.cloudwatch_agent_service_account_name}"]
  }
}

data "aws_iam_policy_document" "cloudwatch_agent" {
  statement {
    sid = "PublishMetrics"
    actions = [
      "cloudwatch:PutMetricData",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      values   = ["ContainerInsights"]
      variable = "cloudwatch:namespace"
    }
    condition {
      test     = "StringEquals"
      values   = [data.aws_region.current.name]
      variable = "aws:RequestedRegion"
    }
  }

  statement {
    sid = "Ec2AccessForMetricsMetadata"
    actions = [
      "ec2:DescribeTags",
      "ec2:DescribeVolumes"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      values   = [data.aws_region.current.name]
      variable = "aws:RequestedRegion"
    }
  }

  statement {
    sid = "AccessToInsightsLogGroup"
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = [
      "${aws_cloudwatch_log_group.container_insights_metrics.arn}:*"
    ]
  }
}

resource "aws_iam_role_policy" "cloudwatch_agent" {
  name_prefix = "cloudwatch-metrics-"
  policy      = data.aws_iam_policy_document.cloudwatch_agent.json
  role        = module.cloudwatch_agent_role.iam_role_name
}

resource "kubernetes_config_map_v1" "cloudwatch_agent_leader_election" {
  metadata {
    labels    = local.cloudwatch_agent_labels
    name      = "cwagent-clusterleader"
    namespace = kubernetes_namespace_v1.cloudwatch.metadata[0].name
  }
}

resource "kubernetes_config_map_v1" "cloudwatch_agent_config" {
  metadata {
    labels    = local.cloudwatch_agent_labels
    name      = "cwagentconfig"
    namespace = kubernetes_namespace_v1.cloudwatch.metadata[0].name
  }

  data = {
    "cwagentconfig.json" = jsonencode(
      {
        agent = {
          region = data.aws_region.current.name
          # https://github.com/aws/amazon-cloudwatch-agent/pull/766
          usage_data = false
        }
        logs = {
          metrics_collected = {
            kubernetes = {
              cluster_name                = var.cluster_name
              enhanced_container_insights = var.enable_enhanced_observability
              metrics_collection_interval = var.metrics_collection_interval
            }
          }
          endpoint_override    = "logs.${data.aws_region.current.name}.amazonaws.com"
          force_flush_interval = 5
        }
      }
    )
  }
}

resource "kubernetes_service_account_v1" "cloudwatch_agent" {
  metadata {
    annotations = {
      "eks.amazonaws.com/role-arn"               = module.cloudwatch_agent_role.iam_role_arn
      "eks.amazonaws.com/sts-regional-endpoints" = "true"
    }
    labels    = local.cloudwatch_agent_labels
    name      = local.cloudwatch_agent_service_account_name
    namespace = kubernetes_namespace_v1.cloudwatch.metadata[0].name
  }
  automount_service_account_token = true
}

resource "kubernetes_cluster_role_v1" "cloudwatch_agent" {
  metadata {
    labels = local.cloudwatch_agent_labels
    name   = "cloudwatch-agent-role"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "nodes", "endpoints"]
    verbs      = ["list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["replicasets", "daemonsets", "deployments", "statefulsets"]
    verbs      = ["list", "watch"]
  }

  rule {
    api_groups = ["batch"]
    resources  = ["jobs"]
    verbs      = ["list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["nodes/proxy"]
    verbs      = ["get"]
  }

  rule {
    api_groups = [""]
    resources  = ["nodes/stats", "configmaps", "events"]
    verbs      = ["create"]
  }

  rule {
    api_groups     = [""]
    resources      = ["configmaps"]
    resource_names = [kubernetes_config_map_v1.cloudwatch_agent_leader_election.metadata[0].name]
    verbs          = ["get", "update"]
  }

  rule {
    non_resource_urls = ["/metrics"]
    verbs             = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "cloudwatch_agent" {
  metadata {
    labels = local.cloudwatch_agent_labels
    name   = "cloudwatch-agent-role-binding"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.cloudwatch_agent.metadata[0].name
    namespace = kubernetes_service_account_v1.cloudwatch_agent.metadata[0].namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.cloudwatch_agent.metadata[0].name
  }
}

# Use a UUID that is regenerated any time the config map is modified and then add the value to the pod template.
# If the config changes, the pod template changes and that will result in a restart of the pods to pick up the
# config changes.
resource "random_uuid" "cloudwatch_agent_config" {
  keepers = kubernetes_config_map_v1.cloudwatch_agent_config.data
}

locals {
  cloudwatch_agent_selector_labels = {
    name = "container-insights-cloudwatch-agent"
  }
  cloudwatch_agent_pod_labels = merge(
    local.cloudwatch_agent_selector_labels,
    local.cloudwatch_agent_labels,
  )
}

resource "kubernetes_daemon_set_v1" "cloudwatch_agent" {
  metadata {
    labels    = local.cloudwatch_agent_labels
    name      = "cloudwatch-agent"
    namespace = kubernetes_namespace_v1.cloudwatch.metadata[0].name
  }

  spec {
    selector {
      match_labels = local.cloudwatch_agent_selector_labels
    }

    template {
      metadata {
        annotations = {
          "config-id" = random_uuid.cloudwatch_agent_config.id
        }
        labels = local.cloudwatch_agent_pod_labels
      }

      spec {

        # The agent needs access to the EC2 metadata.  For EC2 instances that configure the metadata to block access from pods, enabling host network access is the only way to access the metadata endpoint.
        host_network = true

        priority_class_name = "system-node-critical"

        volume {
          name = "cwagentconfig"
          config_map {
            name = kubernetes_config_map_v1.cloudwatch_agent_config.metadata[0].name
          }
        }

        volume {
          name = "rootfs"
          host_path {
            path = "/"
          }
        }

        volume {
          name = "containerdsock"
          host_path {
            path = "/run/containerd/containerd.sock"
          }
        }

        volume {
          name = "sys"
          host_path {
            path = "/sys"
          }
        }

        volume {
          name = "devdisk"
          host_path {
            path = "/dev/disk/"
          }
        }

        volume {
          name = "devkmsg"
          host_path {
            path = "/dev/kmsg"
          }
        }

        container {

          env {
            name = "AWS_ROLE_SESSION_NAME"
            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }

          env {
            name = "HOST_IP"
            value_from {
              field_ref {
                field_path = "status.hostIP"
              }
            }
          }

          env {
            name = "HOST_NAME"
            value_from {
              field_ref {
                field_path = "spec.nodeName"
              }
            }
          }

          env {
            name = "K8S_NAMESPACE"
            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }

          env {
            name  = "CI_VERSION"
            value = "k8s/${local.version}"
          }

          # https://github.com/aws/amazon-cloudwatch-agent/pull/122
          env {
            name  = "RUN_IN_AWS"
            value = "True"
          }

          # https://github.com/aws/amazon-cloudwatch-agent/pull/682
          env {
            name  = "RUN_WITH_IRSA"
            value = "True"
          }

          image             = "${var.image_registry}/cloudwatch-agent/cloudwatch-agent:1.300030.2b309@sha256:d1e511adcc30a8bf5af09f2f0102745885919ad11e96a4b34fb0581e232d916f"
          image_pull_policy = "Always"

          name = "cloudwatch-agent"

          resources {
            limits   = var.cloudwatch_agent_pod_resources.limits
            requests = var.cloudwatch_agent_pod_resources.requests
          }

          security_context {
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
            }
            seccomp_profile {
              type = "RuntimeDefault"
            }
          }

          volume_mount {
            name       = "cwagentconfig"
            mount_path = "/etc/cwagentconfig"
          }

          volume_mount {
            name       = "rootfs"
            read_only  = true
            mount_path = "/rootfs"
          }

          volume_mount {
            name       = "containerdsock"
            read_only  = true
            mount_path = "/run/containerd/containerd.sock"
          }

          volume_mount {
            name       = "sys"
            read_only  = true
            mount_path = "/sys"
          }

          volume_mount {
            name       = "devdisk"
            read_only  = true
            mount_path = "/dev/disk"
          }

          volume_mount {
            name       = "devkmsg"
            read_only  = true
            mount_path = "/dev/kmsg"
          }
        }

        termination_grace_period_seconds = 60
        service_account_name             = kubernetes_service_account_v1.cloudwatch_agent.metadata[0].name
      }
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.container_insights_metrics,
    aws_iam_role_policy.cloudwatch_agent,
    module.cloudwatch_agent_role,
  ]
}

############################
# Fluent Bit agent resources
############################
locals {

  fluent_bit_labels = merge(
    local.insights_labels,
    {
      "app.kubernetes.io/component" = "logging-agent"
      "app.kubernetes.io/name"      = "fluent-bit"
    }
  )

  fluent_bit_service_account_name = "fluent-bit"
  aws_fluent_bit_version          = "2.31.12.20231011"
}

resource "aws_cloudwatch_log_group" "container_insights_logs" {
  for_each          = toset(["application", "dataplane", "host"])
  name              = "/aws/containerinsights/${var.cluster_name}/${each.key}"
  retention_in_days = var.log_retention_in_days
  tags              = local.all_tags
}

module "fluent_bit_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-eks-role"
  version = "5.3.0"

  role_description = "AWS Fluent Bit agent for Container Insights"
  role_name        = "${local.iam_role_name_prefix}-aws-fluent-bit-agent"

  cluster_service_accounts = {
    (var.cluster_name) = ["${kubernetes_namespace_v1.cloudwatch.metadata[0].name}:${local.fluent_bit_service_account_name}"]
  }
}

data "aws_iam_policy_document" "fluent_bit" {

  statement {
    sid = "Ec2AccessForMetricsMetadata"
    actions = [
      "ec2:DescribeVolumes",
      "ec2:DescribeTags",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      values   = [data.aws_region.current.name]
      variable = "aws:RequestedRegion"
    }
  }

  statement {
    sid = "AccessToInsightsLogGroup"
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = formatlist("%s:*", values(aws_cloudwatch_log_group.container_insights_logs)[*].arn)
  }
}

resource "aws_iam_role_policy" "fluent_bit" {
  name_prefix = "cloudwatch-logs-"
  policy      = data.aws_iam_policy_document.fluent_bit.json
  role        = module.fluent_bit_role.iam_role_name
}

resource "kubernetes_service_account_v1" "fluent_bit" {
  metadata {
    annotations = {
      "eks.amazonaws.com/role-arn"               = module.fluent_bit_role.iam_role_arn
      "eks.amazonaws.com/sts-regional-endpoints" = "true"
    }
    labels    = local.fluent_bit_labels
    name      = local.fluent_bit_service_account_name
    namespace = kubernetes_namespace_v1.cloudwatch.metadata[0].name
  }
  automount_service_account_token = true
}

resource "kubernetes_cluster_role_v1" "fluent_bit" {
  metadata {
    name   = "fluent-bit-role"
    labels = local.fluent_bit_labels
  }

  rule {
    non_resource_urls = ["/metrics"]
    verbs             = ["get"]
  }

  rule {
    api_groups = [""]
    resources = [
      "namespaces",
      "pods",
      "pods/logs",
      "nodes",
      "nodes/proxy"
    ]
    verbs = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "fluent_bit" {
  metadata {
    name   = "fluent-bit-role-binding"
    labels = local.fluent_bit_labels
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.fluent_bit.metadata[0].name
    namespace = kubernetes_namespace_v1.cloudwatch.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.fluent_bit.metadata[0].name
  }
}

resource "kubernetes_config_map_v1" "fluent_bit_config" {
  metadata {
    name      = "fluent-bit-config"
    namespace = kubernetes_namespace_v1.cloudwatch.metadata[0].name

    labels = local.fluent_bit_labels

  }

  data = { for conf in fileset("${path.module}/files/fluent-bit", "*.conf") : conf => file("${path.module}/files/fluent-bit/${conf}") }
}

locals {
  fluent_bit_selector_labels = {
    name = "container-insights-fluent-bit-agent"
  }
  fluent_bit_pod_labels = merge(
    local.fluent_bit_selector_labels,
    local.fluent_bit_labels,
  )

  fluent_bit_storage_mount_directory = "/var/fluent-bit/state"
}

data "aws_ssm_parameter" "fluent_bit_image" {
  name = "/aws/service/aws-for-fluent-bit/${local.aws_fluent_bit_version}"
}

# Use a UUID that is regenerated any time the config map is modified and then add the value to the pod template.
# If the config changes, the pod template changes and that will result in a restart of the pods to pick up the
# config changes.
resource "random_uuid" "fluent_bit_config" {
  keepers = kubernetes_config_map_v1.fluent_bit_config.data
}

resource "kubernetes_daemon_set_v1" "fluent_bit" {
  metadata {
    labels    = local.fluent_bit_labels
    name      = "fluent-bit"
    namespace = kubernetes_namespace_v1.cloudwatch.metadata[0].name
  }

  spec {
    selector {
      match_labels = local.fluent_bit_selector_labels
    }

    template {
      metadata {
        annotations = {
          "config-id"            = random_uuid.fluent_bit_config.id
          "prometheus.io/scrape" = var.http_server_enabled
          # https://docs.fluentbit.io/manual/administration/monitoring#metrics-in-prometheus-format
          "prometheus.io/path" = "/api/v1/metrics/prometheus"
          "prometheus.io/port" = var.http_server_port
        }
        labels = local.fluent_bit_pod_labels
      }

      spec {

        dns_policy          = "ClusterFirstWithHostNet"
        host_network        = true
        priority_class_name = "system-node-critical"

        volume {
          name = "fluentbitstate"
          host_path {
            path = local.fluent_bit_storage_mount_directory
          }
        }

        volume {
          name = "varlog"
          host_path {
            path = "/var/log"
          }
        }

        volume {
          name = kubernetes_config_map_v1.fluent_bit_config.metadata[0].name
          config_map {
            name = kubernetes_config_map_v1.fluent_bit_config.metadata[0].name
          }
        }

        volume {
          name = "runlogjournal"
          host_path {
            path = "/run/log/journal"
          }
        }

        volume {
          name = "dmesg"
          host_path {
            path = "/var/log/dmesg"
          }
        }

        container {

          # Ensure Fluent Bit uses service account role instead of the metadata service.
          env {
            name  = "AWS_EC2_METADATA_DISABLED"
            value = "true"
          }

          env {
            name  = "AWS_REGION"
            value = data.aws_region.current.name
          }

          env {
            name = "AWS_ROLE_SESSION_NAME"
            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }

          env {
            name  = "CI_VERSION"
            value = "k8s/${local.version}"
          }

          env {
            name  = "CLUSTER_NAME"
            value = var.cluster_name
          }

          env {
            name  = "HTTP_SERVER"
            value = var.http_server_enabled ? "On" : "Off"
          }

          env {
            name  = "HTTP_PORT"
            value = var.http_server_port
          }

          env {
            name  = "READ_FROM_HEAD"
            value = var.read_from_head ? "On" : "Off"
          }

          env {
            name  = "READ_FROM_TAIL"
            value = var.read_from_tail ? "On" : "Off"
          }

          env {
            name  = "STATE_DIRECTORY"
            value = local.fluent_bit_storage_mount_directory
          }

          env {
            name = "HOST_NAME"
            value_from {
              field_ref {
                field_path = "spec.nodeName"
              }
            }
          }

          env {
            name = "HOSTNAME"
            value_from {
              field_ref {
                api_version = "v1"
                field_path  = "metadata.name"
              }
            }
          }

          image             = nonsensitive(data.aws_ssm_parameter.fluent_bit_image.value)
          image_pull_policy = "IfNotPresent"

          name = "fluent-bit"
          resources {
            limits   = var.fluent_bit_pod_resources.limits
            requests = var.fluent_bit_pod_resources.requests
          }

          security_context {
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
            }
            read_only_root_filesystem = true
            seccomp_profile {
              type = "RuntimeDefault"
            }
          }

          volume_mount {
            name       = "fluentbitstate"
            mount_path = local.fluent_bit_storage_mount_directory
          }

          volume_mount {
            name       = "varlog"
            read_only  = true
            mount_path = "/var/log"
          }

          volume_mount {
            name       = kubernetes_config_map_v1.fluent_bit_config.metadata[0].name
            mount_path = "/fluent-bit/etc/"
          }

          volume_mount {
            name       = "runlogjournal"
            read_only  = true
            mount_path = "/run/log/journal"
          }

          volume_mount {
            name       = "dmesg"
            read_only  = true
            mount_path = "/var/log/dmesg"
          }

        }
        service_account_name = kubernetes_service_account_v1.fluent_bit.metadata[0].name
        # This must match the value in fluent-bit.conf
        termination_grace_period_seconds = 30
      }
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.container_insights_logs,
    # Ensure all permissions are configured prior to creating the pods
    aws_iam_role_policy.fluent_bit,
    kubernetes_cluster_role_binding_v1.fluent_bit,
    module.fluent_bit_role,
  ]

  lifecycle {
    precondition {
      condition     = var.read_from_head || var.read_from_tail
      error_message = "Either the 'read_from_head' variable or the 'read_from_tail' variable must be set to true."
    }
  }
}


#################
# Fargate Logging
#################


locals {
  fargate_labels = merge(
    var.labels,
    local.required_labels,
  )
}

# FluentBit ships its process logs ot a stand-alone log group.  The group name is not configurable.
# https://docs.aws.amazon.com/eks/latest/userguide/fargate-logging.html
resource "aws_cloudwatch_log_group" "fargate_fluent_bit" {
  name              = "${var.cluster_name}-fluent-bit-logs"
  retention_in_days = var.fargate_logging.fluent_bit_process_logging.retention_in_days
  tags              = local.all_tags
}

moved {
  from = aws_cloudwatch_log_group.fargate_fluentbit
  to   = aws_cloudwatch_log_group.fargate_fluent_bit
}

data "aws_iam_policy_document" "fargate" {
  statement {
    sid = "AccessToInsightsLogGroup"
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = formatlist("%s:*", [
      aws_cloudwatch_log_group.container_insights_logs["application"].arn,
      aws_cloudwatch_log_group.fargate_fluent_bit.arn,
    ])
  }

  # The FluentBit process logs don't work unless it has permission to create its log group
  # even though the log group already exists.  This limitation isn't mentioned in the
  # EKS documentation.
  statement {
    sid     = "LogGroupExistenceCheck"
    actions = ["logs:CreateLogGroup"]
    resources = [
      "${aws_cloudwatch_log_group.fargate_fluent_bit.arn}:*",
    ]
  }
}

resource "aws_iam_role_policy" "fargate" {
  for_each    = var.fargate_logging.pod_execution_role_names
  name_prefix = "fargate-logging-"
  policy      = data.aws_iam_policy_document.fargate.json
  role        = each.value
}

resource "kubernetes_namespace_v1" "fargate" {
  metadata {
    labels = merge(
      {
        "aws-observability"                  = var.fargate_logging.enabled ? "enabled" : "disabled"
        "pod-security.kubernetes.io/enforce" = "restricted"
      },
      local.fargate_labels,
    )
    name = "aws-observability"
  }
}

locals {
  banned_resources = [
    "cronjobs.batch",
    "deployments.apps",
    "ingress.networking.k8s.io",
    "jobs.batch",
    "persistentvolumeclaims",
    "replicasets.apps",
    "replicationcontrollers",
    "secrets",
    "services",
    "statefulsets.apps",
  ]
}

# Prevent the creation of any resources other than the configmap
resource "kubernetes_resource_quota_v1" "fargate" {
  metadata {
    labels    = local.fargate_labels
    name      = "banned-resources"
    namespace = kubernetes_namespace_v1.fargate.metadata[0].name
  }

  spec {
    hard = {
      for r in local.banned_resources : "count/${r}" => 0
    }
  }
}

resource "kubernetes_config_map_v1" "fargate" {
  metadata {
    labels    = local.fargate_labels
    name      = "aws-logging"
    namespace = kubernetes_namespace_v1.fargate.metadata[0].name
  }

  data = {
    flb_log_cw = tostring(var.fargate_logging.fluent_bit_process_logging.enabled)

    "filters.conf" = <<-EOF
      [FILTER]
        Name parser
        Match *
        Key_name log
        Parser cri
      [FILTER]
        Name             kubernetes
        Match            kube.*
        Merge_Log           On
        Merge_Log_Key       log_processed
        Buffer_Size         0
        Kube_Meta_Cache_TTL 300s
        Annotations         Off
        K8S-Logging.Parser  On
        K8S-Logging.Exclude On
    EOF

    "output.conf" = <<-EOF
      [OUTPUT]
        Name              cloudwatch_logs
        Match             kube.*
        region            ${data.aws_region.current.name}
        log_group_name    ${aws_cloudwatch_log_group.container_insights_logs["application"].name}
        log_stream_prefix fargate-
        auto_create_group false
    EOF

    # The AWS docs don't explicitly state this, but it is implied that Fargate's FluentBit agent
    # doesn't include a parser for containerd logs.  This parser is copied from the FluentBit
    # code at https://github.com/fluent/fluent-bit/blob/fb7d4c8c9b22a2e73787a029e89df769e0c0267b/conf/parsers.conf#L116
    # There is an open issue on the containers roadmap requesting the inclusion of the parser: https://github.com/aws/containers-roadmap/issues/1366
    "parsers.conf" = <<-EOF
      [PARSER]
        Name cri
        Format regex
        Regex ^(?<time>[^ ]+) (?<stream>stdout|stderr) (?<_p>[^ ]*) (?<log>.*)$
        Time_Key    time
        Time_Format %Y-%m-%dT%H:%M:%S.%L%z
        Time_Keep   On
    EOF
  }

  depends_on = [
    aws_iam_role_policy.fargate,
    aws_cloudwatch_log_group.fargate_fluent_bit,
  ]
}
