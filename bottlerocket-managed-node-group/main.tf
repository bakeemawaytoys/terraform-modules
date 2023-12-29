terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.50.0"
    }
  }
  required_version = ">= 1.3.0"
}

data "aws_default_tags" "current" {}

data "aws_ec2_instance_type" "desired" {
  for_each      = var.instance_types
  instance_type = each.key
  lifecycle {
    postcondition {
      condition     = self.hypervisor == "nitro"
      error_message = "All instance types must use the Nitro hypervisor."
    }

    postcondition {
      condition     = self.ebs_encryption_support == "supported"
      error_message = "All instance types must support EBS encryption."
    }

    postcondition {
      condition     = self.ena_support == "required"
      error_message = "ENA support is required for all instance types"
    }

    postcondition {
      condition     = self.ebs_optimized_support != "unsupported"
      error_message = "All instance types must be EBS optimized"
    }

    postcondition {
      condition     = contains(self.supported_architectures, "arm64") || contains(self.supported_architectures, "x86_64")
      error_message = "The CPU architecture of each instance type must be either arm64 or x86_64."
    }
  }
}


data "aws_subnet" "node" {
  for_each = toset(var.subnet_ids)
  id       = each.key
}

data "aws_ec2_instance_type_offerings" "node" {
  for_each = data.aws_subnet.node
  filter {
    name   = "instance-type"
    values = var.instance_types
  }

  filter {
    name   = "location"
    values = [each.value.availability_zone_id]
  }

  location_type = "availability-zone-id"
  lifecycle {
    postcondition {
      condition     = length(self.instance_types) == length(var.instance_types)
      error_message = <<-EOF
      One or more of the instance types is not available in the ${each.value.availability_zone_id} availability zone (${each.key}).
      Select an instance type that can be launched in every availability zone of every subnet specified in the 'subnet_ids' variable.
      The required availability zones are ${join(", ", values(data.aws_subnet.node)[*].availability_zone_id)}.
      EOF
    }
  }
}

locals {
  instance_type_architectures = distinct(flatten(values(data.aws_ec2_instance_type.desired)[*].supported_architectures))
  # A simple check using the Contains function is used to determine the group's architecture.
  # A precondition on the launch template resource ensures that the set of instances doesn't contain a mixture of architectures.
  architecture = contains(local.instance_type_architectures, "arm64") ? "arm64" : "x86_64"
  owned_resource_tags = merge(
    var.tags,
    {
      "kubernetes.io/cluster"                                 = var.eks_cluster.cluster_name
      "kubernetes.io/cluster/${var.eks_cluster.cluster_name}" = "owned"
      operating_system                                        = "bottlerocket"
    }
  )

  # https://github.com/bottlerocket-os/bottlerocket
  bottlrocket_settings = <<-EOF
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
  registry-qps = 50
  registry-burst = 100

  EOF
}

data "aws_ssm_parameter" "ami_release_version" {
  name = "/aws/service/bottlerocket/aws-k8s-${var.eks_cluster.k8s_version}/${local.architecture}/${var.bottlerocket_version}/image_version"
}

resource "aws_launch_template" "this" {
  description             = "Customizations for the ${var.name_prefix} managed node group in the ${var.eks_cluster.cluster_name} EKS cluster."
  disable_api_stop        = false
  disable_api_termination = false
  ebs_optimized           = true
  name_prefix             = "${var.name_prefix}-eks-node-group-"
  tags                    = local.owned_resource_tags
  update_default_version  = true
  user_data               = base64encode(local.bottlrocket_settings)
  vpc_security_group_ids = concat(
    var.security_group_ids,
    [var.eks_cluster.cluster_security_group_id]
  )

  block_device_mappings {
    device_name = "/dev/xvdb"
    ebs {
      delete_on_termination = "true"
      encrypted             = "true"
      iops                  = var.volume_iops
      throughput            = var.volume_throughput
      volume_size           = var.volume_size
      volume_type           = "gp3"
    }
  }

  # https://github.com/bottlerocket-os/bottlerocket#default-volumes
  block_device_mappings {
    # Override the root device to use gp3
    device_name = "/dev/xvda"
    ebs {
      delete_on_termination = "true"
      encrypted             = "true"
      volume_type           = "gp3"
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_protocol_ipv6          = "disabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "required"
    instance_metadata_tags      = "disabled"
  }

  monitoring {
    enabled = true
  }

  dynamic "tag_specifications" {
    for_each = ["instance", "network-interface", "volume"]
    content {
      resource_type = tag_specifications.value
      # Pass in the default tags so that they are propagated to instances
      tags = merge(
        data.aws_default_tags.current.tags,
        local.owned_resource_tags,
        {
          Name = var.name_prefix
        }
      )
    }
  }

  depends_on = [
    data.aws_ec2_instance_type_offerings.node
  ]

  lifecycle {
    create_before_destroy = true

    # Ensure that the set of instance types doesn't contain a mixture of architectures.
    precondition {
      condition     = length(local.instance_type_architectures) == 1
      error_message = "All instance types must have the same architecture."
    }
  }
}

resource "aws_eks_node_group" "this" {
  ami_type               = "BOTTLEROCKET_${local.architecture == "arm64" ? "ARM_64" : "x86_64"}"
  capacity_type          = upper(replace(var.capacity_type, "-", "_"))
  cluster_name           = var.eks_cluster.cluster_name
  instance_types         = values(data.aws_ec2_instance_type.desired)[*].instance_type
  labels                 = var.labels
  node_group_name_prefix = "${var.name_prefix}-"
  node_role_arn          = var.iam_role_arn
  release_version        = nonsensitive(data.aws_ssm_parameter.ami_release_version.value)
  subnet_ids             = var.subnet_ids
  tags                   = local.owned_resource_tags

  dynamic "taint" {
    for_each = var.taints
    content {
      effect = taint.value.effect
      key    = taint.value.key
      value  = taint.value.value
    }
  }

  version = var.eks_cluster.k8s_version

  launch_template {
    name    = aws_launch_template.this.name
    version = aws_launch_template.this.default_version
  }

  scaling_config {
    desired_size = var.size.desired
    max_size     = var.size.max
    min_size     = var.size.min
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    data.aws_ec2_instance_type_offerings.node
  ]


  lifecycle {
    create_before_destroy = true
  }
}


moved {
  from = module.eks_managed_node_group.aws_eks_node_group.this[0]
  to   = aws_eks_node_group.this
}

moved {
  from = module.eks_managed_node_group.aws_launch_template.this[0]
  to   = aws_launch_template.this
}
