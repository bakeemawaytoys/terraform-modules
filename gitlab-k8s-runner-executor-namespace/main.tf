terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.67"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20"
    }
  }
  required_version = ">= 1.4"
}

locals {
  name = "gitlab-runner-executors"
  labels = merge(
    var.labels,
    {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  )
  tags = merge(
    var.tags,
    {
      "kubernetes.io/cluster"                                 = var.eks_cluster.cluster_name
      "kubernetes.io/cluster/${var.eks_cluster.cluster_name}" = "owned"
    }
  )
}

module "fargate_profile" {
  source = "../eks-fargate-profile"

  cluster_name           = var.eks_cluster.cluster_name
  fargate_profile_name   = "gitlab-runner-executors"
  pod_execution_role_arn = var.fargate_profile.pod_execution_role_arn
  selectors = [{
    namespace = local.name
  }]
  subnet_ids = var.fargate_profile.subnet_ids
  tags       = local.tags
}

module "iam_role" {
  source = "../eks-iam-role-for-service-account"

  eks_cluster = var.eks_cluster
  name        = "${var.eks_cluster.cluster_name}-cluster-gitlab-runner-executor"
  service_account = {
    # Use a wildcard to allow all runner executors to share a role.  Value matches the service accounts created by the gitlab-k8s-runner-executor-namespace
    name      = "gitlab-runner-*"
    namespace = local.name
  }
  s3_access = {
    writer_buckets = [
      var.distributed_cache_bucket,
    ]
  }
  tags = local.tags
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    annotations = var.annotations
    labels = merge(
      local.labels,
      { for mode, level in var.pod_security_standards : "pod-security.kubernetes.io/${mode}" => level },
      {
        "goldilocks.fairwinds.com/enabled" : tostring(var.enable_goldilocks)
      }
    )
    name = local.name
  }

  # Add a dependency on the Fargate profile and IAM role to ensure they exist before any executor pods are scheduled.
  depends_on = [
    module.fargate_profile,
    module.iam_role,
  ]
}

