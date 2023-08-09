# Terraform Database Login

This Terraform submodule enables Teleport database login functionality. It e
ncapsulates the logic needed for logging into a database via Teleport, allowing
for a secure and reusable way to handle database authentication.

## Overview

- Retrieves and sets the database connection information such as host, port, SSL
  CA, SSL certificate, and SSL key.
- Executes the `db-login` command of Teleport's CLI to authenticate with the
  specified database.
- Accepts parameters for the target Teleport cluster and database to enable a
  targeted login process.

## Usage

```hcl
module "teleport_db_login" {
  source  = "cruxstack/teleport-cluster/aws//modules/teleport-db-login"
  version = "x.x.x"

  target_cluster = "your-target-cluster.teleport.example.com"
  target_db      = "your-target-database"
}

# configure pgsql (eg, `cyrilgdn/postgresql`) provider to connect to the db
provider "postgresql" {
  scheme      = "postgres"
  host        = module.teleport_db_login.db_host
  port        = module.teleport_db_login.db_port
  username    = "<db-user>"
  password    = "<db-pass>"
  sslmode     = "require"
  sslrootcert = module.teleport_db_login.db_ssl_ca
  superuser   = false

  clientcert {
    cert = module.teleport_db_login.db_ssl_cert
    key  = module.teleport_db_login.db_ssl_key
  }
}
```

## Requirements

- Terraform host requires `tsh` and `jq` to be installed.
- Teleport cluster must be preconfigured with the target databases.
- Active login in session is required before using this module.
  - eg, `tsh login --proxy=teleport.example.com --user=<user>`

## Inputs

| Name             | Description                                              | Type     | Default | Required |
|------------------|----------------------------------------------------------|----------|---------|:--------:|
| `target_cluster` | Domain to the Teleport cluster for database login.       | `string` | n/a     |   yes    |
| `target_db`      | Name of the target database within the Teleport cluster. | `string` | n/a     |   yes    |

## Outputs

| Name          | Description                   |
|---------------|-------------------------------|
| `db_host`     | Database host address.        |
| `db_port`     | Database port number.         |
| `db_ssl_ca`   | SSL CA for database.          |
| `db_ssl_cert` | SSL certificate for database. |
| `db_ssl_key`  | SSL key for database.         |
