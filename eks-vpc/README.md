# EKS VPC

## Overview

Creates a VPC suitable for an EKS cluster as described in the [EKS documentation](https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html).

## Subnet Types

### Internal

Internal subnets are for resources that don't require access to anything outside of the VPC.  They have no access to the Internet.  Examples in include [PrivateLink endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/concepts.html), [RDS instances](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Welcome.html), and [Route53 Resolvers](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/Welcome.html).

### NAT

NAT subnets are small subnets dedicated entirely running [NAT Gateways](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html).  The NAT Gateway(s) provide Internet access for the Node, Pod, and Private subnets.

### Node

Node subnets are dedicated to running EKS nodes and nothing else. The node subnets should have large CIDR blocks unless the k8s pods are configured to create there network interfaces in the Pod subnets.

### Public

Public subnets have direct access to the Internet via the VPC's Internet Gateway.  A public IP address is automatically assigned to anything launched in these subnets.  Their primary use-case is running external load balancers.

### Pod

Pod subnets are dedicated to [pod network interfaces](https://docs.aws.amazon.com/eks/latest/userguide/cni-custom-network.html) and [Fargate nodes](https://docs.aws.amazon.com/eks/latest/userguide/fargate-profile.html).  As such they should be allocated with large CIDR blocks.

### Private

Private subnets are for running non-Kubernetes resources that are internal the VPC but require connectivity to resources outside of the VPC.  Examples include EC2 instances and internal load balancers.

## Default Resources

The VPC's default security group, network ACLs, and route table are all managed by the resource with the expectation that they are never used or modified outside of the module.  All rules on the default security group have been removed to render it useless.  Similarly, all routes on the default route table have been removed.  The default network ACLs are used by the module but they are set to the default rules to allow all ingress and egress traffic.  The assumption is that network ACLs are never used to control traffic in the VPC managed by this module.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.4.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_db_subnet_group.vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group) | resource |
| [aws_default_network_acl.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_network_acl) | resource |
| [aws_default_route_table.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_route_table) | resource |
| [aws_default_security_group.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group) | resource |
| [aws_docdb_subnet_group.vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/docdb_subnet_group) | resource |
| [aws_eip.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_elasticache_subnet_group.vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_subnet_group) | resource |
| [aws_internet_gateway.vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_route.internet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route53_resolver_firewall_rule_group_association.vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_resolver_firewall_rule_group_association) | resource |
| [aws_route53_resolver_query_log_config_association.vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_resolver_query_log_config_association) | resource |
| [aws_route_table.internal](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.internal](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.pod](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_subnet.internal](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.pod](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc_dhcp_options.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_dhcp_options) | resource |
| [aws_vpc_dhcp_options_association.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_dhcp_options_association) | resource |
| [aws_vpc_endpoint.gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | The names of the availability zones to use for the VPC's subnets. | `list(string)` | n/a | yes |
| <a name="input_cidr_block"></a> [cidr\_block](#input\_cidr\_block) | The primary IPv4 CIDR block of the VPC. | `string` | n/a | yes |
| <a name="input_eks_cluster_names"></a> [eks\_cluster\_names](#input\_eks\_cluster\_names) | The names of the EKS clusters deployed to the VPC. | `set(string)` | n/a | yes |
| <a name="input_internal_subnet_cidr_blocks"></a> [internal\_subnet\_cidr\_blocks](#input\_internal\_subnet\_cidr\_blocks) | An optional list of CIDR blocks to use for private subnets with no access outside of the VPC.  Primarily intendend to be used with VPC-enabled AWS services. | `list(string)` | `[]` | no |
| <a name="input_nat_subnet_cidr_blocks"></a> [nat\_subnet\_cidr\_blocks](#input\_nat\_subnet\_cidr\_blocks) | A list of CIDR blocks to use for the subnets dedicated to NAT gateways.  One gateway is created in each of the CIDR blocks. | `list(string)` | n/a | yes |
| <a name="input_node_subnet_cidr_blocks"></a> [node\_subnet\_cidr\_blocks](#input\_node\_subnet\_cidr\_blocks) | A list of CIDR block to use for subnets where EKS nodes run. | `list(string)` | n/a | yes |
| <a name="input_pod_subnet_cidr_blocks"></a> [pod\_subnet\_cidr\_blocks](#input\_pod\_subnet\_cidr\_blocks) | A list of CIDR block to use for subnets where EKS pod ENIs are created. | `list(string)` | n/a | yes |
| <a name="input_private_subnet_cidr_blocks"></a> [private\_subnet\_cidr\_blocks](#input\_private\_subnet\_cidr\_blocks) | An optional list of CIDR blocks to use for private subnets with Internet access through the NAT gateways. Private subnets are tagged with the 'kubernetes.io/role/internal-elb' tag. | `list(string)` | `[]` | no |
| <a name="input_public_subnet_cidr_blocks"></a> [public\_subnet\_cidr\_blocks](#input\_public\_subnet\_cidr\_blocks) | An optional list of CIDR blocks to use for public subnets.  Public subnets are tagged with the 'kubernetes.io/role/elb' tag. | `list(string)` | `[]` | no |
| <a name="input_route53_firewall_rule_group_ids"></a> [route53\_firewall\_rule\_group\_ids](#input\_route53\_firewall\_rule\_group\_ids) | An optional list of identifiers of Route53 firewall rule groups to associate with the VPC.  The priorities assigned to the rule groups is based on the ordering of the list, from highest to lowest. | `list(string)` | `[]` | no |
| <a name="input_route53_query_log_config_ids"></a> [route53\_query\_log\_config\_ids](#input\_route53\_query\_log\_config\_ids) | An optional list of identifiers of Rout53 query log configurations to associate with the VPC. | `set(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | An optional map of AWS tags to apply to every resource created by the module. | `map(string)` | `{}` | no |
| <a name="input_vpc_name"></a> [vpc\_name](#input\_vpc\_name) | The value to use for the Name tag on the VPC. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_availability_zone_names"></a> [availability\_zone\_names](#output\_availability\_zone\_names) | The names of every availability zone containing a subnet. |
| <a name="output_cidr_block"></a> [cidr\_block](#output\_cidr\_block) | The primary CIDR block of the VPC created by this module. |
| <a name="output_internal_docdb_subnet_group"></a> [internal\_docdb\_subnet\_group](#output\_internal\_docdb\_subnet\_group) | The ID of the DocumentDB subnet group for the internal subnets or null if there are no internal subnets. |
| <a name="output_internal_elasticache_subnet_group"></a> [internal\_elasticache\_subnet\_group](#output\_internal\_elasticache\_subnet\_group) | The ID of the ElastiCache subnet group for the internal subnets or null if there are no internal subnets. |
| <a name="output_internal_rds_subnet_group"></a> [internal\_rds\_subnet\_group](#output\_internal\_rds\_subnet\_group) | The ID of RDS subnet group for the internal subnets or null if there are no internal subnets. |
| <a name="output_internal_route_table_ids"></a> [internal\_route\_table\_ids](#output\_internal\_route\_table\_ids) | A list of the unique identifiers assigned to the route tables associated with the subnets that have no access to the Internet. |
| <a name="output_internal_subnet_cidr_blocks"></a> [internal\_subnet\_cidr\_blocks](#output\_internal\_subnet\_cidr\_blocks) | A list of the CIDR blocks assigned to the internal subnets. |
| <a name="output_internal_subnet_ids"></a> [internal\_subnet\_ids](#output\_internal\_subnet\_ids) | A list of the unique identifiers assigned to the internal subnets. |
| <a name="output_internal_subnet_resources"></a> [internal\_subnet\_resources](#output\_internal\_subnet\_resources) | A list of objects containing the attributes of the internal subnet resources. |
| <a name="output_internal_subnet_resources_by_az"></a> [internal\_subnet\_resources\_by\_az](#output\_internal\_subnet\_resources\_by\_az) | A map whose key is the name of an availability zone and whose value is an object containing the attributes of the internal subnet resource in that zone. |
| <a name="output_nat_public_ip_addresses"></a> [nat\_public\_ip\_addresses](#output\_nat\_public\_ip\_addresses) | The public IPv4 addresses of the NAT gateways. |
| <a name="output_node_subnet_cidr_blocks"></a> [node\_subnet\_cidr\_blocks](#output\_node\_subnet\_cidr\_blocks) | A list of the CIDR blocks assigned to the node subnets. |
| <a name="output_node_subnet_ids"></a> [node\_subnet\_ids](#output\_node\_subnet\_ids) | A list of the unique identifiers assigned to the node subnets. |
| <a name="output_node_subnet_resources"></a> [node\_subnet\_resources](#output\_node\_subnet\_resources) | A list of objects containing the attributes of the private subnet resources. |
| <a name="output_node_subnet_resources_by_az"></a> [node\_subnet\_resources\_by\_az](#output\_node\_subnet\_resources\_by\_az) | A map whose key is the name of an availability zone and whose value is an object containing the attributes of the node subnet resource in that zone. |
| <a name="output_pod_subnet_cidr_blocks"></a> [pod\_subnet\_cidr\_blocks](#output\_pod\_subnet\_cidr\_blocks) | A list of the CIDR blocks assigned to the pod subnets. |
| <a name="output_pod_subnet_ids"></a> [pod\_subnet\_ids](#output\_pod\_subnet\_ids) | A list of the unique identifiers assigned to the pod subnets or null if there are no private subnets. |
| <a name="output_pod_subnet_resources"></a> [pod\_subnet\_resources](#output\_pod\_subnet\_resources) | A list of objects containing the attributes of the pod subnet resources. |
| <a name="output_pod_subnet_resources_by_az"></a> [pod\_subnet\_resources\_by\_az](#output\_pod\_subnet\_resources\_by\_az) | A map whose key is the name of an availability zone and whose value is an object containing the attributes of the private subnet resource in that zone. |
| <a name="output_pod_subnets"></a> [pod\_subnets](#output\_pod\_subnets) | A map of availability zone names to objects containing the attributes of the private subnet in the zone. |
| <a name="output_private_docdb_subnet_group"></a> [private\_docdb\_subnet\_group](#output\_private\_docdb\_subnet\_group) | The ID of the DocumentDB subnet group for the private subnets or null if there are no private subnets. |
| <a name="output_private_elasticache_subnet_group"></a> [private\_elasticache\_subnet\_group](#output\_private\_elasticache\_subnet\_group) | The ID of the ElastiCache subnet group for the private subnets or null if there are no private subnets. |
| <a name="output_private_rds_subnet_group"></a> [private\_rds\_subnet\_group](#output\_private\_rds\_subnet\_group) | The ID of RDS subnet group for the private subnets. |
| <a name="output_private_route_table_ids"></a> [private\_route\_table\_ids](#output\_private\_route\_table\_ids) | A list of the unique identifiers assigned to the route tables associated with the subnets that have access to the Internet through the NAT gateways. |
| <a name="output_private_route_tables_by_az"></a> [private\_route\_tables\_by\_az](#output\_private\_route\_tables\_by\_az) | A map whose key is the name of an availability zone and whose value is an object containing the attributes of the private route table resource in that zone. |
| <a name="output_private_route_tables_list"></a> [private\_route\_tables\_list](#output\_private\_route\_tables\_list) | A map whose key is the name of an availability zone and whose value is an object containing the attributes of the private route table resource in that zone. |
| <a name="output_private_subnet_cidr_blocks"></a> [private\_subnet\_cidr\_blocks](#output\_private\_subnet\_cidr\_blocks) | A list of the CIDR blocks assigned to the private subnets. |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | A list of the unique identifiers assigned to the private subnets. |
| <a name="output_private_subnet_resources"></a> [private\_subnet\_resources](#output\_private\_subnet\_resources) | A list of objects containing the attributes of the private subnet resources. |
| <a name="output_private_subnet_resources_by_az"></a> [private\_subnet\_resources\_by\_az](#output\_private\_subnet\_resources\_by\_az) | A map whose key is the name of an availability zone and whose value is an object containing the attributes of the private subnet resource in that zone. |
| <a name="output_public_route_table_ids"></a> [public\_route\_table\_ids](#output\_public\_route\_table\_ids) | A list of the unique identifiers assigned to the route tables associated with the subnets that have direct access to the Internet. |
| <a name="output_public_subnet_cidr_blocks"></a> [public\_subnet\_cidr\_blocks](#output\_public\_subnet\_cidr\_blocks) | A list of the CIDR blocks assigned to the public subnets. |
| <a name="output_public_subnet_ids"></a> [public\_subnet\_ids](#output\_public\_subnet\_ids) | A list of the unique identifiers assigned to the public subnets. |
| <a name="output_public_subnet_resources"></a> [public\_subnet\_resources](#output\_public\_subnet\_resources) | A list of objects containing the attributes of the public subnet resources. |
| <a name="output_public_subnet_resources_by_az"></a> [public\_subnet\_resources\_by\_az](#output\_public\_subnet\_resources\_by\_az) | A map whose key is the name of an availability zone and whose value is an object containing the attributes of the public subnet resource in that zone. |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | The unique identifier of the VPC created by this module. |
| <a name="output_vpc_name"></a> [vpc\_name](#output\_vpc\_name) | The value of the Name tag on the VPC. |
<!-- END_TF_DOCS -->