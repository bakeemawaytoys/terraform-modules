terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
  required_version = ">= 1.4.0"
}

data "aws_region" "current" {}

locals {
  cluster_ownership = length(var.eks_cluster_names) == 1 ? "owned" : "shared"
  eks_subnet_tags = merge(
    { for cluster_name in var.eks_cluster_names : "kubernetes.io/cluster/${cluster_name}" => local.cluster_ownership },
    var.tags,
  )
}

resource "aws_vpc" "main" {
  cidr_block                           = var.cidr_block
  enable_dns_hostnames                 = true
  enable_dns_support                   = true
  enable_network_address_usage_metrics = true
  tags = merge(
    var.tags,
    {
      Name = var.vpc_name
    },
  )
}

resource "aws_vpc_dhcp_options" "main" {
  domain_name         = "${data.aws_region.current.name}.compute.internal"
  domain_name_servers = ["AmazonProvidedDNS"]
  tags = merge(
    var.tags,
    {
      Name = aws_vpc.main.tags["Name"]
    },
  )
}

resource "aws_vpc_dhcp_options_association" "main" {
  dhcp_options_id = aws_vpc_dhcp_options.main.id
  vpc_id          = aws_vpc.main.id
}

####
# Public subnets with direct access to the Internet
####
resource "aws_subnet" "nat" {
  for_each = zipmap(slice(var.availability_zones, 0, length(var.nat_subnet_cidr_blocks)), var.nat_subnet_cidr_blocks)

  availability_zone = each.key
  cidr_block        = each.value
  tags = merge(
    var.tags,
    {
      Name = "${aws_vpc.main.tags["Name"]}-NAT-${each.key}"
    },
  )
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "public" {
  for_each = try(zipmap(var.availability_zones, var.public_subnet_cidr_blocks), {})

  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = true
  tags = merge(
    local.eks_subnet_tags,
    {
      "kubernetes.io/role/elb" = "1"
      Name                     = "${aws_vpc.main.tags["Name"]}-public-${each.key}"
    },
  )
  vpc_id = aws_vpc.main.id
}

resource "aws_internet_gateway" "vpc" {
  tags = merge(
    var.tags,
    {
      Name = aws_vpc.main.tags["Name"]
    }
  )
  vpc_id = aws_vpc.main.id
}

# Create a single route table for the public subnets.  It will be exposed as an output to the module
# to allow for additional routes that the resources deployed in them might need.
resource "aws_route_table" "public" {
  tags = merge(
    var.tags,
    {
      Name = "${aws_vpc.main.tags["Name"]}-public"
    },
  )

  vpc_id = aws_vpc.main.id
}

resource "aws_route" "internet" {
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.vpc.id
  route_table_id         = aws_route_table.public.id
}


resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  route_table_id = aws_route_table.public.id
  subnet_id      = each.value.id
}

# Create a spearate table for the NAT subnets because only need one route.  The table is considered private to the module.
resource "aws_route_table" "nat" {
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vpc.id
  }

  tags = merge(
    var.tags,
    {
      Name = "${aws_vpc.main.tags["Name"]}-NAT"
    },
  )

  vpc_id = aws_vpc.main.id
}

resource "aws_route_table_association" "nat" {
  for_each       = aws_subnet.nat
  route_table_id = aws_route_table.nat.id
  subnet_id      = each.value.id
}

####
# Create the NAT gateway resources.
####
resource "aws_eip" "nat" {
  for_each = aws_subnet.nat

  tags = merge(
    var.tags,
    {
      Name = "${aws_vpc.main.tags["Name"]}-${each.key}"
    },
  )
}

resource "aws_nat_gateway" "public" {
  for_each      = aws_subnet.nat
  allocation_id = aws_eip.nat[each.key].allocation_id
  subnet_id     = each.value.id

  tags = merge(
    var.tags,
    {
      Name = "${aws_vpc.main.tags["Name"]}-${each.key}"
    },
  )

  depends_on = [
    aws_internet_gateway.vpc
  ]
}

####
# Create the private subnets
####
resource "aws_subnet" "node" {
  for_each   = zipmap(var.availability_zones, var.node_subnet_cidr_blocks)
  cidr_block = each.value
  tags = merge(
    local.eks_subnet_tags,
    {
      Name = "${aws_vpc.main.tags["Name"]}-nodes-${each.key}"
    },
  )
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "pod" {
  for_each = zipmap(var.availability_zones, var.pod_subnet_cidr_blocks)

  availability_zone = each.key
  cidr_block        = each.value
  tags = merge(
    local.eks_subnet_tags,
    {
      Name = "${aws_vpc.main.tags["Name"]}-pods-${each.key}"
    },
  )
  vpc_id = aws_vpc.main.id
}

# An optional set of private subnets for internal ELBs and other non-k8s applications.
resource "aws_subnet" "private" {
  for_each = try(zipmap(var.availability_zones, var.private_subnet_cidr_blocks), {})

  availability_zone = each.key
  cidr_block        = each.value
  tags = merge(
    local.eks_subnet_tags,
    {
      "kubernetes.io/role/internal-elb" = "1"
      Name                              = "${aws_vpc.main.tags["Name"]}-private-${each.key}"
    },
  )
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "private" {
  for_each = toset(var.availability_zones)
  tags = merge(
    var.tags,
    {
      Name = "${aws_vpc.main.tags["Name"]}-private-${each.key}"
    },
  )
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "nat" {
  for_each               = aws_route_table.private
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(values(aws_nat_gateway.public), index(var.availability_zones, each.key)).id
  route_table_id         = each.value.id
}

resource "aws_route_table_association" "node" {
  for_each       = aws_subnet.node
  route_table_id = aws_route_table.private[each.key].id
  subnet_id      = each.value.id
}

resource "aws_route_table_association" "pod" {
  for_each       = aws_subnet.pod
  route_table_id = aws_route_table.private[each.key].id
  subnet_id      = each.value.id
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  route_table_id = aws_route_table.private[each.key].id
  subnet_id      = each.value.id
}

####
# An optional set of internal subnets for resources that don't require access to anything but the VPC CIDR block.  Primarily intended for
# VPC-enabled services and PrivateLink endpoints.
####

resource "aws_subnet" "internal" {
  for_each = try(zipmap(var.availability_zones, var.internal_subnet_cidr_blocks), {})

  availability_zone = each.key
  cidr_block        = each.value
  tags = merge(
    var.tags,
    {
      Name = "${aws_vpc.main.tags["Name"]}-internal-${each.key}"
    },
  )
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "internal" {
  tags = merge(
    var.tags,
    {
      Name = "${aws_vpc.main.tags["Name"]}-internal"
    },
  )
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table_association" "internal" {
  for_each       = aws_subnet.internal
  route_table_id = aws_route_table.internal.id
  subnet_id      = each.value.id
}

resource "aws_vpc_endpoint" "gateway" {
  for_each = toset(["dynamodb", "s3"])
  tags = merge(
    var.tags,
    {
      Name = aws_vpc.main.tags["Name"]
    }
  )
  service_name = "com.amazonaws.${data.aws_region.current.name}.${each.value}"
  route_table_ids = concat(
    [
      aws_route_table.internal.id,
      aws_route_table.nat.id,
      aws_route_table.public.id,
    ],
    values(aws_route_table.private)[*].id,
  )
  vpc_endpoint_type = "Gateway"
  vpc_id            = aws_vpc.main.id
}

######################
# Route53 Resolver
######################

resource "aws_route53_resolver_firewall_rule_group_association" "vpc" {
  for_each               = toset(var.route53_firewall_rule_group_ids)
  name                   = aws_vpc.main.tags["Name"]
  firewall_rule_group_id = each.key
  # Priorites must be greater than 100
  priority = 101 + index(var.route53_firewall_rule_group_ids, each.key)
  vpc_id   = aws_vpc.main.id
}

resource "aws_route53_resolver_query_log_config_association" "vpc" {
  for_each                     = var.route53_query_log_config_ids
  resolver_query_log_config_id = each.key
  resource_id                  = aws_vpc.main.id
}

#######################
# Subnet Groups
######################

locals {
  groups = {
    internal = values(aws_subnet.internal)[*].id
    private  = (values(aws_subnet.private)[*].id)
  }
  # Filter the map in case there are no subnets defined.
  subnet_groups = { for k, v in local.groups : k => v if 0 < length(k) }
}

resource "aws_db_subnet_group" "vpc" {
  for_each    = local.subnet_groups
  description = "RDS instances in the ${aws_vpc.main.tags["Name"]} VPC ${each.key} subnets."
  name        = lower("rds-${aws_vpc.main.tags["Name"]}-${each.key}-subnets")
  subnet_ids  = each.value
  tags        = var.tags
}

resource "aws_elasticache_subnet_group" "vpc" {
  for_each    = local.subnet_groups
  description = "Nodes in the ${aws_vpc.main.tags["Name"]} VPC ${each.key} subnets."
  name        = lower("${aws_vpc.main.tags["Name"]}-${each.key}-subnets")
  subnet_ids  = each.value
  tags        = var.tags
}

resource "aws_docdb_subnet_group" "vpc" {
  for_each    = local.subnet_groups
  description = "DocumentDB instances in the ${aws_vpc.main.tags["Name"]} VPC ${each.key} subnets."
  name        = lower("docdb-${aws_vpc.main.tags["Name"]}-${each.key}-subnets")
  subnet_ids  = each.value
  tags        = var.tags
}


#########################
# Default VPC resources
########################

locals {
  default_resource_name_suffix = endswith(aws_vpc.main.tags["Name"], "-VPC") ? "-default" : "-VPC-default"
  default_resource_name        = "${aws_vpc.main.tags["Name"]}${local.default_resource_name_suffix}"
}

resource "aws_default_network_acl" "main" {
  default_network_acl_id = aws_vpc.main.default_network_acl_id

  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  subnet_ids = concat(
    values(aws_subnet.internal)[*].id,
    values(aws_subnet.private)[*].id,
    values(aws_subnet.public)[*].id,
    values(aws_subnet.nat)[*].id,
    values(aws_subnet.node)[*].id,
    values(aws_subnet.pod)[*].id,
  )

  tags = merge(
    var.tags,
    {
      Name = local.default_resource_name
    },
  )
}

resource "aws_default_route_table" "main" {
  default_route_table_id = aws_vpc.main.default_route_table_id
  # Ensure no routes outside of the local route are in the table.
  route = []
  tags = merge(
    var.tags,
    {
      Name = local.default_resource_name
    },
  )
}

resource "aws_default_security_group" "main" {
  # Ensure the security group has no rules to prevent accidentally opening up access to a resource that is automatically assigned this group.
  egress  = []
  ingress = []

  tags = merge(
    var.tags,
    {
      Name = local.default_resource_name
    },
  )
  vpc_id = aws_vpc.main.id
}
