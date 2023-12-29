terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.40"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
  required_version = ">= 1.3"
}


locals {
  tags = merge(
    var.tags,
    {
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  )
}

resource "time_static" "fargate_profile" {
  triggers = {
    cluster_name           = var.cluster_name
    fargate_profile_name   = var.fargate_profile_name
    namespaces             = join(",", var.selectors[*].namespace)
    pod_execution_role_arn = var.pod_execution_role_arn
    selector_label_keys    = join(",", flatten([for labels in var.selectors[*].labels : keys(labels)]))
    selector_label_values  = join(",", flatten([for labels in var.selectors[*].labels : values(labels)]))
    subnet_ids             = join(",", var.subnet_ids)
  }
}

resource "aws_eks_fargate_profile" "this" {
  # Reference the values through the triggers to ensure the same value is used with both resources.
  cluster_name           = time_static.fargate_profile.triggers.cluster_name
  fargate_profile_name   = "${time_static.fargate_profile.triggers.fargate_profile_name}-${time_static.fargate_profile.unix}"
  pod_execution_role_arn = time_static.fargate_profile.triggers.pod_execution_role_arn
  subnet_ids             = split(",", time_static.fargate_profile.triggers.subnet_ids)

  dynamic "selector" {
    for_each = var.selectors

    content {
      namespace = selector.value.namespace
      labels    = selector.value.labels
    }
  }

  tags = local.tags

  lifecycle {
    create_before_destroy = true
  }
}
