# Example: Complete

This directory contains a complete example of how to use the Teleport Cluster
Terraform module in a real-world scenario.

## Overview

This example deploys a Teleport cluster with the following configuration:

- Teleport auth, node, and proxy services deployed in a high-availability (HA)
  configuration.
- Deployment into a specified AWS VPC and subnets.

## Usage

To run this example, provide your own values for the following variables in a
`.terraform.tfvars` file:

```hcl
teleport_letsencrypt_email = "your-email@example.com"
dns_parent_zone_id         = "your-dns-zone-id"
dns_parent_zone_name       = "your-dns-zone-name"
vpc_id                     = "your-vpc-id"
vpc_private_subnet_ids     = ["your-private-subnet-id"]
vpc_public_subnet_ids      = ["your-public-subnet-id"]
```

## Inputs

| Name                       | Description                                                         | Type           | Default | Required |
|----------------------------|---------------------------------------------------------------------|----------------|---------|:--------:|
| teleport_letsencrypt_email | The email address to use for Let's Encrypt.                         | `string`       | n/a     |   yes    |
| dns_parent_zone_id         | The ID of the parent DNS zone.                                      | `string`       | n/a     |   yes    |
| dns_parent_zone_name       | The name of the parent DNS zone.                                    | `string`       | n/a     |   yes    |
| vpc_id                     | The ID of the VPC to deploy resources into.                         | `string`       | n/a     |   yes    |
| vpc_private_subnet_ids     | The IDs of the private subnets in the VPC to deploy resources into. | `list(string)` | n/a     |   yes    |
| vpc_public_subnet_ids      | The IDs of the public subnets in the VPC to deploy resources into.  | `list(string)` | n/a     |   yes    |

## Outputs

| Name                    | Description                           |
|-------------------------|---------------------------------------|
| teleport_dns_name       | The DNS name of the Teleport service. |
| teleport_web_portal_url | The URL of the Teleport web portal.   |
```
