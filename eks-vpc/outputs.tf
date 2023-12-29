output "availability_zone_names" {
  description = "The names of every availability zone containing a subnet."
  value       = var.availability_zones
}

output "cidr_block" {
  description = "The primary CIDR block of the VPC created by this module."
  value       = aws_vpc.main.cidr_block
}

output "internal_docdb_subnet_group" {
  description = "The ID of the DocumentDB subnet group for the internal subnets or null if there are no internal subnets."
  value       = try(aws_docdb_subnet_group.vpc["internal"].id, null)
}

output "internal_elasticache_subnet_group" {
  description = "The ID of the ElastiCache subnet group for the internal subnets or null if there are no internal subnets."
  value       = try(aws_elasticache_subnet_group.vpc["internal"].id, null)
}

output "internal_rds_subnet_group" {
  description = "The ID of RDS subnet group for the internal subnets or null if there are no internal subnets."
  value       = try(aws_db_subnet_group.vpc["internal"].id, null)
}

output "internal_subnet_cidr_blocks" {
  description = "A list of the CIDR blocks assigned to the internal subnets."
  value       = values(aws_subnet.internal)[*].cidr_block
}

output "internal_subnet_ids" {
  description = "A list of the unique identifiers assigned to the internal subnets."
  value       = values(aws_subnet.internal)[*].id
}

output "internal_subnet_resources_by_az" {
  description = "A map whose key is the name of an availability zone and whose value is an object containing the attributes of the internal subnet resource in that zone."
  value       = aws_subnet.internal
}

output "internal_subnet_resources" {
  description = "A list of objects containing the attributes of the internal subnet resources."
  value       = values(aws_subnet.internal)
}

output "internal_route_table_ids" {
  description = "A list of the unique identifiers assigned to the route tables associated with the subnets that have no access to the Internet."
  value       = [aws_route_table.internal.id]
}

output "nat_public_ip_addresses" {
  description = "The public IPv4 addresses of the NAT gateways."
  value       = values(aws_eip.nat)[*].public_ip
}

output "node_subnet_cidr_blocks" {
  description = "A list of the CIDR blocks assigned to the node subnets."
  value       = values(aws_subnet.node)[*].cidr_block
}

output "node_subnet_ids" {
  description = "A list of the unique identifiers assigned to the node subnets."
  value       = values(aws_subnet.node)[*].id
}

output "node_subnet_resources_by_az" {
  description = "A map whose key is the name of an availability zone and whose value is an object containing the attributes of the node subnet resource in that zone."
  value       = aws_subnet.node
}

output "node_subnet_resources" {
  description = "A list of objects containing the attributes of the private subnet resources."
  value       = values(aws_subnet.node)
}

output "pod_subnets" {
  description = "A map of availability zone names to objects containing the attributes of the private subnet in the zone."
  value       = aws_subnet.pod
}

output "pod_subnet_cidr_blocks" {
  description = "A list of the CIDR blocks assigned to the pod subnets."
  value       = values(aws_subnet.pod)[*].cidr_block
}
output "pod_subnet_ids" {
  description = "A list of the unique identifiers assigned to the pod subnets or null if there are no private subnets."
  value       = values(aws_subnet.pod)[*].id
}

output "pod_subnet_resources_by_az" {
  description = "A map whose key is the name of an availability zone and whose value is an object containing the attributes of the private subnet resource in that zone."
  value       = aws_subnet.pod
}

output "pod_subnet_resources" {
  description = "A list of objects containing the attributes of the pod subnet resources."
  value       = values(aws_subnet.pod)
}

output "private_docdb_subnet_group" {
  description = "The ID of the DocumentDB subnet group for the private subnets or null if there are no private subnets."
  value       = try(aws_docdb_subnet_group.vpc["private"].id, null)
}

output "private_elasticache_subnet_group" {
  description = "The ID of the ElastiCache subnet group for the private subnets or null if there are no private subnets."
  value       = try(aws_elasticache_subnet_group.vpc["private"].id, null)
}

output "private_rds_subnet_group" {
  description = "The ID of RDS subnet group for the private subnets."
  value       = try(aws_db_subnet_group.vpc["private"].id, null)
}

output "private_route_table_ids" {
  description = "A list of the unique identifiers assigned to the route tables associated with the subnets that have access to the Internet through the NAT gateways."
  value       = values(aws_route_table.private)[*].id
}

output "private_route_tables_by_az" {
  description = "A map whose key is the name of an availability zone and whose value is an object containing the attributes of the private route table resource in that zone."
  value       = aws_route_table.private
}

output "private_route_tables_list" {
  description = "A map whose key is the name of an availability zone and whose value is an object containing the attributes of the private route table resource in that zone."
  value       = values(aws_route_table.private)
}

output "private_subnet_cidr_blocks" {
  description = "A list of the CIDR blocks assigned to the private subnets."
  value       = values(aws_subnet.private)[*].cidr_block
}

output "private_subnet_ids" {
  description = "A list of the unique identifiers assigned to the private subnets."
  value       = values(aws_subnet.private)[*].id
}

output "private_subnet_resources_by_az" {
  description = "A map whose key is the name of an availability zone and whose value is an object containing the attributes of the private subnet resource in that zone."
  value       = aws_subnet.private
}

output "private_subnet_resources" {
  description = "A list of objects containing the attributes of the private subnet resources."
  value       = values(aws_subnet.private)
}

output "public_route_table_ids" {
  description = "A list of the unique identifiers assigned to the route tables associated with the subnets that have direct access to the Internet."
  value       = [aws_route_table.public]
}

output "public_subnet_cidr_blocks" {
  description = "A list of the CIDR blocks assigned to the public subnets."
  value       = values(aws_subnet.public)[*].cidr_block
}

output "public_subnet_ids" {
  description = "A list of the unique identifiers assigned to the public subnets."
  value       = values(aws_subnet.public)[*].id
}

output "public_subnet_resources_by_az" {
  description = "A map whose key is the name of an availability zone and whose value is an object containing the attributes of the public subnet resource in that zone."
  value       = aws_subnet.public
}

output "public_subnet_resources" {
  description = "A list of objects containing the attributes of the public subnet resources."
  value       = values(aws_subnet.public)
}

output "vpc_id" {
  description = "The unique identifier of the VPC created by this module."
  value       = aws_vpc.main.id
}

output "vpc_name" {
  description = "The value of the Name tag on the VPC."
  value       = var.vpc_name
}
