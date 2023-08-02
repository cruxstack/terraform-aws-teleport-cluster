# Terraform Module: AWS Teleport Cluster

This project is under development. See `dev` branch for latest activity.

## Prerequisites

- Terraform v0.13.0 or newer
- An AWS account

## Usage

```hcl
module "teleport_cluster" {
  source  = "cruxstack/teleport-cluster/aws"
  version = "x.x.x"

  # TBD
}
```

## Requirements

- Terraform 0.13.0 or later
- AWS provider

## Inputs

In addition to the variables documented below, this module includes several
other optional variables (e.g., `name`, `tags`, etc.) provided by the
`cloudposse/label/null` module. Please refer to the [`cloudposse/label` documentation](https://registry.terraform.io/modules/cloudposse/label/null/latest) for more details on these variables.

| Name        | Description |  Type  | Default | Required |
|-------------|-------------|:------:|:-------:|:--------:|
| `placehold` | N/A         | string |  null   |    No    |

## Outputs

| Name        | Description |
|-------------|-------------|
| `placehold` | N/A         |

## Contributing

We welcome contributions to this project. For information on setting up a
development environment and how to make a contribution, see [CONTRIBUTING](./CONTRIBUTING.md)
documentation.
