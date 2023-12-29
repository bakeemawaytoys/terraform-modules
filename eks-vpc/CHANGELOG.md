# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## 3.0.0

### Changed

- **Breaking Change**: The minium supported version of the AWS provider has been changed from 4.67 to 5.0.  The `aws_eip` resource contains deprecations in version 5.0.  The module has been modified to remove the use of those deprecations.

## 2.0.1

### Fixed

- Explicitly assigned every subnet to the `aws_default_network_acl` resource to eliminate perpetual drift.

## 2.0.0

### Added

- The `aws_default_network_acl`,`aws_default_route_table`, and `aws_default_security_group` resources have been added to the module.  A goal of the module is to avoid accidentally exposing network access to a resource by forcing explicit configuration of access.  The default resources, by their very nature, grant implicit access.  The resources can't be deleted but they can be rendered useless by removing the security group's rules and route table's routes.  The network ACLs are unchanged from the default.
- The module now includes an `aws_vpc_dhcp_options` resource and an `aws_vpc_dhcp_options_association` resource.  It no longer relies on the default DHCP options so that the expected options are controlled by the module.

### Fixed

- The value of the `Name` tags on the private resources have been updated to use casing consistent with the other resource names.

### Removed

- **Breaking Change**: The `default_network_acl_id` output has been removed due to the introduction of the `aws_default_network_acl` resource.

## 1.4.0

### Added

- A new output named `nat_public_ip_addresses` exposes the collection of public IP addresses assigned to the NAT gateways.
- The `internal_subnet_resources`, `node_subnet_resources`, `pod_subnet_resources`, and `private_subnet_resources` outputs have been added to expose all attributes of the subnet resources of the subnet resources.
- The `internal_subnet_resources_by_az`, `node_subnet_resources_by_az`, `pod_subnet_resources_by_az`, and `private_subnet_resources_by_az` outputs have been added to allow for referencing the subnet resource attributes by availability zone name.
- The `private_route_tables_by_az` and `private_route_tables_list` outputs have been added to expose the attributes of the route table resources.

## 1.3.0

### Added

- The module now includes `aws_db_subnet_group`, `aws_elasticache_subnet_group` and `aws_docdb_subnet_group` resources.  One of each is created for the private subnets and one if each is created for the internal subnets.  New outputs have been added to expose the identifiers of each resource.  Including the subnet group resources in the module will reduce code duplication across environments as a well as ensure consistent naming across environments.

### Fixed

- A few of the resources did not include the value of the `tags` in their `tags` argument.  They do now.

## 1.2.0

### Added

- Route53 resolver firewall rule groups can now be assigned to the VPC.  Rule group identifiers can be passed to the module using the `route53_firewall_rule_group_ids` variable.
- Route53 query logging can now be enabled on the VPC.  Logging config identifiers can be passed to the module using the `route53_query_log_config_ids` variable.

### Changed

- The `nullable` argument has been added to every required variable.

## 1.1.0

### Added

- Set the minimum AWS provider version to 4.35 to expose the `enable_network_address_usage_metrics` attribute on the `aws_vpc` resource.  Set the attribue to `true`.

## 1.0.0

### Added

- Initial release !1
