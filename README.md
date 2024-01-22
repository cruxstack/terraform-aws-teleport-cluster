# Terraform Module: Teleport Cluster

This Terraform module deploys a Teleport cluster in high availability (HA)
configuration. [Teleport](https://github.com/gravitational/teleport) is a modern
zero-trust solution by Gravitational. This module has been tested with Teleport
version v10 and v14.

### Features

- **High Availability**: Deploys Teleport in a highly available configuration to
  ensure uninterrupted access.
- **Managed Upgrades**: Supports controlled upgrades to new versions of
  Teleport.
- **Secure**: Uses AWS Key Management Service (KMS) to secure sensitive data.
- **Scalable**: Can handle growth in your user base and infrastructure without a
  corresponding increase in complexity.
- **Integrated**: Works well with your existing infrastructure by following
  CloudPosse's context and labeling patterns.
- **Automation** to create teleport connection to resources on-demand via
  included submodules.

## Usage

Deploy it using the block below. For the first time deployments, it make take 10
minutes before the web portal is available.

```hcl
module "teleport_cluster" {
  source  = "cruxstack/teleport-cluster/aws"
  version = "x.x.x"

  teleport_letsencrypt_email = "letencrypt@example.com"
  teleport_runtime_version   = "14.3.3"
  teleport_setup_mode        = false
  dns_parent_zone_id         = "Z0000000000000000000"
  dns_parent_zone_name       = "demo.example.com"
  vpc_id                     = "vpc-00000000000000"
  vpc_subnet_ids             = ["subnet-00000000000000", "subnet-11111111111111111", "subnet-22222222222222222"]
  vpc_public_subnet_ids      = ["subnet-33333333333333", "subnet-44444444444444444", "subnet-55555555555555555"]
}
```

## Inputs

In addition to the variables documented below, this module includes several
other optional variables (e.g., `name`, `tags`, etc.) provided by the
`cloudposse/label/null` module. Please refer to its [documentation](https://registry.terraform.io/modules/cloudposse/label/null/latest)
for more details on these variables.

| Name                         | Description                                                                                                       | Type           | Default | Required |
|------------------------------|-------------------------------------------------------------------------------------------------------------------|----------------|---------|:--------:|
| `teleport_runtime_version`   | The runtime version of Teleport.                                                                                  | `string`       | n/a     |   yes    |
| `teleport_letsencrypt_email` | The email address to use for Let's Encrypt.                                                                       | `string`       | n/a     |   yes    |
| `teleport_setup_mode`        | Toggle Teleport setup mode.                                                                                       | `bool`         | `true`  |    no    |
| `teleport_experimental_mode` | Toggle Teleport experimental mode.                                                                                | `bool`         | `false` |    no    |
| `instance_config`            | Configuration for the instances. Each type (`auth`, `node`, `proxy`) contains an object with `count` and `sizes`. | `object`       | `{}`    |    no    |
| `artifacts_bucket_name`      | The name of the S3 bucket for artifacts.                                                                          | `string`       | `""`    |    no    |
| `logs_bucket_name`           | The name of the S3 bucket for logs.                                                                               | `string`       | `""`    |    no    |
| `dns_parent_zone_id`         | The ID of the parent DNS zone.                                                                                    | `string`       | n/a     |   yes    |
| `dns_parent_zone_name`       | The name of the parent DNS zone.                                                                                  | `string`       | n/a     |   yes    |
| `vpc_id`                     | The ID of the VPC to deploy resources into.                                                                       | `string`       | n/a     |   yes    |
| `vpc_private_subnet_ids`     | The IDs of the private subnets in the VPC to deploy resources into.                                               | `list(string)` | n/a     |   yes    |
| `vpc_public_subnet_ids`      | The IDs of the public subnets in the VPC to deploy resources into.                                                | `list(string)` | n/a     |   yes    |
| `aws_region_name`            | The name of the AWS region.                                                                                       | `string`       | `""`    |    no    |
| `aws_account_id`             | The ID of the AWS account.                                                                                        | `string`       | `""`    |    no    |
| `aws_kv_namespace`           | The namespace or prefix for AWS SSM parameters and similar resources.                                             | `string`       | `""`    |    no    |

### Outputs

| Name                    | Description                                                      |
|-------------------------|------------------------------------------------------------------|
| `teleport_dns_name`     | The DNS name of the Teleport service.                            |
| `teleport_auth_config`  | The configuration details for the Teleport auth service.         |
| `teleport_node_config`  | The configuration details for the Teleport node service.         |
| `teleport_proxy_config` | The configuration details for the Teleport proxy service.        |
| `security_group_id`     | The ID of the security group created for the Teleport service.   |
| `security_group_name`   | The name of the security group created for the Teleport service. |

## Contributing

We welcome contributions to this project. For information on setting up a
development environment and how to make a contribution, see [CONTRIBUTING](./CONTRIBUTING.md)
documentation.
