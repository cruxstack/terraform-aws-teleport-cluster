# Terraform SSH Tunnel

This Terraform submodule creates an SSH tunnel using Teleport. It encapsulates
the logic needed to securely connect to a target host through a specific gateway
within a Teleport cluster.

## Overview

- Sets up an SSH tunnel via Teleport.
- Utilizes the Teleport cluster and gateway to route the tunnel.
- Connects to a specified target host and port.

## Usage

```hcl
module "teleport_ssh_tunnel" {
  source  = "cruxstack/teleport-cluster/aws//modules/teleport-ssh-tunnel"
  version = "x.x.x"

  target_cluster    = "your-target-cluster.teleport.example.com"
  terraform_gateway = "name-of-terraform-gateway"
  target_host       = "your-target-database.example.com"
  target_host       = "5439" # example for redshift
}

# configure redshift (eg, `brainly/redshift`) provider to connect to the db
provider "redshift" {
  host     = module.teleport_ssh_tunnel.host
  port     = module.teleport_ssh_tunnel.port
  database = "<db-name>"
  username = "<db-user>"
  password = "<db-pass>"
}
```

## Requirements

- Terraform host requires `tsh` and `jq` to be installed.
- Teleport cluster must be preconfigured with the target databases.
- Active login in session is required before using this module.
  - eg, `tsh login --proxy=teleport.example.com --user=<user>`

## Inputs

| Name              | Description                                              | Type     | Default | Required |
|-------------------|----------------------------------------------------------|----------|---------|:--------:|
| `tp_proxy`        | Domain to the Teleport cluster proxy for database login. | `string` | ""      |    no    |
| `tp_cluster`      | Domain to the Teleport cluster for database login.       | `string` | n/a     |   yes    |
| `tp_gateway_node` | Teleport node to use as the gateway for the connection.  | `string` | n/a     |   yes    |
| `target_host`     | Target user.                                             | `number` | n/a     |   yes    |
| `target_port`     | Target port.                                             | `number` | n/a     |   yes    |

## Outputs

| Name   | Description      |
|--------|------------------|
| `host` | SSH tunnel host. |
| `port` | SSH tunnel port. |
