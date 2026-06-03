# Terraform Module: Teleport Cluster

This Terraform module deploys a
[Teleport](https://github.com/gravitational/teleport) cluster on AWS in a
high-availability configuration. v2 of the module targets Teleport 18 and
consolidates the network surface into a single Network Load Balancer running in
TLS routing (multiplex) mode.

### Features

- **High availability** auth and proxy ASGs across multiple AZs.
- **Single consolidated NLB** fronting both auth and proxy.
- **TLS routing (multiplex)** by default — every client protocol (web UI,
  `tsh ssh`, Kubernetes, databases, reverse tunnels) flows over the proxy's
  `:443` listener.
- **Defense-in-depth security groups**: the public client listener is
  CIDR-scoped while the internal auth listener is reachable only from members of
  the cluster security group.
- **Optional AWS PrivateLink** so consumers in other VPCs/accounts can reach
  Teleport without traversing the public internet.
- **CloudPosse label/context** integration for consistent naming/tagging.
- Companion submodules for on-demand SSH tunnels and database login.

## Usage

The default deployment puts the consolidated NLB in private subnets
(`nlb_internal = true`). Clients reach Teleport via PrivateLink, a VPN, Direct
Connect, or a bastion in the same VPC. Set `nlb_internal = false` and supply
`vpc_public_subnet_ids` to expose the cluster on the public internet.

```hcl
module "teleport_cluster" {
  source  = "cruxstack/teleport-cluster/aws"
  version = "2.0.0"

  teleport_letsencrypt_email = "letsencrypt@example.com"
  teleport_runtime_version   = "18.0.0"
  teleport_setup_mode        = false
  dns_parent_zone_id         = "Z0000000000000000000"
  dns_parent_zone_name       = "demo.example.com"
  vpc_id                     = "vpc-00000000000000"
  vpc_private_subnet_ids     = ["subnet-...", "subnet-...", "subnet-..."]
}
```

### Optional: PrivateLink for cross-VPC / cross-account access

The internal default pairs naturally with PrivateLink so consumers in other
VPCs/accounts can reach Teleport without traversing the public internet.

```hcl
module "teleport_cluster" {
  # ... required inputs ...

  nlb_privatelink_enabled = true
  nlb_privatelink_config = {
    acceptance_required = true
    allowed_principals = [
      "arn:aws:iam::111111111111:root",
      "arn:aws:iam::222222222222:root",
    ]
  }
}
```

Consumers in other accounts create an `aws_vpc_endpoint` against the service
name returned in `teleport_nlb_vpce_service_name`. Only the public client
listener (`:443`) is reachable through the endpoint service — auth (`:3025`)
remains gated to the cluster security group and is rejected by the NLB.

If `nlb_privatelink_config.private_dns_name` is set, the module also creates the
Route 53 TXT verification record that AWS requires before consumers can enable
`private_dns_enabled` on their VPC endpoint. The record is placed in the parent
zone (`dns_parent_zone_id`).

### Optional: internet-facing NLB

Switch to a public NLB by setting `nlb_internal = false` and supplying public
subnets. When the proxy ASG lives in the same VPC as the NLB, also set
`nlb_auth_allowed_cidrs` to the VPC's NAT gateway EIPs so the proxy's reverse
tunnel to auth on `:3025` is admitted (the source IP at the NLB is the NAT EIP,
not a cluster SG member, when traffic hairpins out and back).

```hcl
module "teleport_cluster" {
  # ... required inputs ...

  nlb_internal           = false
  vpc_public_subnet_ids  = ["subnet-...", "subnet-...", "subnet-..."]
  nlb_allowed_cidrs      = ["0.0.0.0/0"]
  nlb_auth_allowed_cidrs = ["203.0.113.10/32", "203.0.113.11/32"] # VPC NAT EIPs
}
```

## Inputs

In addition to the variables documented below, this module includes several
other optional variables (e.g., `name`, `tags`, etc.) provided by the
`cloudposse/label/null` module. See its
[documentation](https://registry.terraform.io/modules/cloudposse/label/null/latest)
for details.

| Name                          | Description                                                                                                | Type           | Default         | Required |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------- | -------------- | --------------- | :------: |
| `teleport_runtime_version`    | The runtime version of Teleport (v18 recommended).                                                         | `string`       | n/a             |   yes    |
| `teleport_letsencrypt_email`  | The email address to use for Let's Encrypt.                                                                | `string`       | n/a             |   yes    |
| `teleport_setup_mode`         | Toggle Teleport setup mode.                                                                                | `bool`         | `true`          |    no    |
| `teleport_experimental_mode`  | Toggle Teleport experimental mode.                                                                         | `bool`         | `false`         |    no    |
| `deletion_protection_enabled` | Enable deletion protection on the NLB and DynamoDB tables. `null` ⇒ follows `!teleport_experimental_mode`. | `bool`         | `null`          |    no    |
| `instance_config`             | Configuration for the auth and proxy ASGs (`auth`, `proxy` keys with `count`, `sizes`, `spot`).            | `object`       | `{}`            |    no    |
| `nlb_internal`                | Use an internal NLB (private subnets) instead of internet-facing (public subnets).                         | `bool`         | `true`          |    no    |
| `nlb_allowed_cidrs`           | CIDRs allowed on the public client port (443) of the NLB.                                                  | `list(string)` | `["0.0.0.0/0"]` |    no    |
| `nlb_auth_allowed_cidrs`      | CIDRs allowed on the auth listener (3025). Defaults to empty (cluster SG only). See bootstrap notes.       | `list(string)` | `[]`            |    no    |
| `nlb_privatelink_enabled`     | Expose the NLB as a PrivateLink endpoint service.                                                          | `bool`         | `false`         |    no    |
| `nlb_privatelink_config`      | PrivateLink config: `acceptance_required`, `allowed_principals`, `private_dns_name`, `supported_regions`.  | `object`       | `{}`            |    no    |
| `artifacts_bucket_name`       | The name of the S3 bucket for artifacts.                                                                   | `string`       | `""`            |    no    |
| `logs_bucket_name`            | The name of the S3 bucket for logs.                                                                        | `string`       | `""`            |    no    |
| `dns_parent_zone_id`          | The ID of the parent DNS zone.                                                                             | `string`       | n/a             |   yes    |
| `dns_parent_zone_name`        | The name of the parent DNS zone.                                                                           | `string`       | n/a             |   yes    |
| `vpc_id`                      | The ID of the VPC to deploy resources into.                                                                | `string`       | n/a             |   yes    |
| `vpc_private_subnet_ids`      | The IDs of the private subnets in the VPC.                                                                 | `list(string)` | n/a             |   yes    |
| `vpc_public_subnet_ids`       | The IDs of the public subnets. Required when `nlb_internal = false`; may be empty otherwise.               | `list(string)` | `[]`            |    no    |
| `aws_region_name`             | The name of the AWS region.                                                                                | `string`       | `""`            |    no    |
| `aws_account_id`              | The ID of the AWS account.                                                                                 | `string`       | `""`            |    no    |
| `aws_kv_namespace`            | The namespace or prefix for AWS SSM parameters and similar resources.                                      | `string`       | `""`            |    no    |

### Outputs

| Name                             | Description                                                    |
| -------------------------------- | -------------------------------------------------------------- |
| `teleport_dns_name`              | The DNS name of the Teleport service.                          |
| `teleport_auth_config`           | The Teleport auth configuration.                               |
| `teleport_proxy_config`          | The Teleport proxy configuration.                              |
| `teleport_nlb_dns_name`          | DNS name of the consolidated Teleport NLB.                     |
| `teleport_nlb_arn`               | ARN of the consolidated Teleport NLB.                          |
| `teleport_nlb_zone_id`           | Hosted zone ID of the consolidated Teleport NLB.               |
| `teleport_nlb_security_group_id` | Dedicated NLB security group (public CIDR ingress lives here). |
| `teleport_nlb_target_group_arns` | Map of target group ARNs (`auth_ssh`, `proxy_web`).            |
| `teleport_nlb_vpce_service_name` | PrivateLink endpoint service name (empty when disabled).       |
| `teleport_nlb_vpce_service_id`   | PrivateLink endpoint service ID (empty when disabled).         |
| `teleport_nlb_vpce_service_arn`  | PrivateLink endpoint service ARN (empty when disabled).        |
| `security_group_id`              | The ID of the cluster security group.                          |
| `security_group_name`            | The name of the cluster security group.                        |

## Network design (v2)

The consolidated NLB has exactly two listeners:

| Listener | Backend target      | Who can reach it                                                                 |
| -------- | ------------------- | -------------------------------------------------------------------------------- |
| `:443`   | proxy ASG → `:3080` | `nlb_allowed_cidrs` **plus** any member of the cluster security group.           |
| `:3025`  | auth ASG → `:3025`  | Members of the cluster security group **only**. Never reachable from the public. |

This is enforced by attaching **two** security groups to the NLB:

1. A dedicated NLB security group (managed by this module) that holds the public
   CIDR ingress rules for `:443` only.
2. The shared cluster security group, of which both auth and proxy instances are
   members. Its existing self-ingress rule grants cluster members and the NLB
   ENIs full reachability to each other on every port — which is what covers the
   proxy ⇄ auth control channel on `:3025`.

`enforce_security_group_inbound_rules_on_private_link_traffic = on` means the
same rules also apply to PrivateLink consumer traffic, so endpoint ENIs (which
are not members of the cluster SG) can never reach `:3025`.

The `proxy_web` target group has `proxy_protocol_v2 = true`, and the Teleport
proxy config carries `proxy_service.proxy_protocol = "on"`. The two together
preserve the real client IP at L7 (for the audit log) while the L3 source on the
wire is the NLB ENI — which is exactly what makes the security-group based
design work.

### Reaching the cluster

The default (`nlb_internal = true`) puts the NLB in the private subnets.
Same-VPC proxy ⇄ auth traffic stays in-VPC: the proxy resolves the NLB DNS to
private ENI IPs and the cluster SG admits the connection on `:3025`. Public
clients reach the cluster via one of:

- **PrivateLink.** Set `nlb_privatelink_enabled = true` and have consumers
  create endpoints against the resulting endpoint service.
- **VPN / Direct Connect.** Anything that puts the client in the cluster VPC's
  routable address space resolves the NLB DNS internally.
- **In-VPC bastion or operator workstation.** Same constraint as VPN: the
  resolver needs to be inside the VPC.

To expose Teleport on the public internet, set `nlb_internal = false` and supply
`vpc_public_subnet_ids`. When the proxy ASG lives in the same VPC and the NLB is
internet-facing, the proxy resolves the NLB's public DNS to its public ENI IPs
and the traffic egresses via the VPC NAT gateway. At the NLB, the apparent
source is the NAT EIP — not a member of the cluster security group — so the
SG-only `:3025` rule rejects the connection and the proxy never registers with
auth. Two ways to resolve it, in order of preference:

1. **Use `nlb_internal = false` + `nlb_auth_allowed_cidrs`.** Set the variable
   to the VPC NAT gateway EIPs so the auth listener accepts traffic arriving
   from those specific IPs. Wider scopes work but increase the public attack
   surface on `:3025`. mTLS still gates the connection at Teleport, but
   defense-in-depth is reduced.
2. **Use `nlb_internal = false` + PrivateLink for in-VPC consumers.** Deploy an
   `aws_vpc_endpoint` in the cluster VPC against the module's endpoint service
   and point the proxy at the endpoint DNS instead of the NLB DNS. More moving
   parts; only worth it if you have a wider PrivateLink story.

## Migrating from v1.x to v2

v2 is a breaking change. The major items:

1. **Single consolidated NLB.** The dedicated `auth` and `proxy` NLBs and their
   target groups/listeners are gone. AWS will replace the existing NLB(s) and
   target groups; Route53 proxy alias records are migrated in place via
   `moved {}` blocks and update to point at the new NLB.
2. **TLS routing (multiplex) is mandatory.** The proxy now uses `version: v2`
   and only opens its `web_listen_addr` (`:3080`, fronted by the NLB on `:443`).
   The auth advertises `proxy_listener_mode: multiplex`. Both halves must agree
   — see Teleport issue
   [#57009](https://github.com/gravitational/teleport/issues/57009). All client
   protocols (SSH, k8s, databases) now ride `:443`.
3. **`node` role removed.** `module.node_servers`, the `instance_config.node`
   key, and the `teleport_node_config` output are gone. Pre-existing node ASGs
   are destroyed on the next `terraform apply`.
4. **`vpc_security_group_allowed_cidrs` / `instance_config.*.allowed_cidrs`
   removed.** Client allow-lists moved to `nlb_allowed_cidrs` on the
   consolidated NLB.
5. **PROXY protocol.** Connections from the NLB to the proxy carry PROXY
   protocol v2. Anything bypassing the NLB and hitting the proxy on `:3080`
   directly will be rejected — by design.
6. **`nlb_internal` defaults to `true`.** v1 was implicitly internet-facing for
   the proxy NLB. The v2 default is internal so same-VPC proxy ⇄ auth traffic
   works without extra config. Pass `nlb_internal = false` and
   `vpc_public_subnet_ids` to restore public exposure.
7. **Deletion protection unified.** `ddb_deletion_protection_enabled` and
   `nlb_deletion_protection` are removed. Use `deletion_protection_enabled`
   (default `null` ⇒ follows `!teleport_experimental_mode`) instead.
8. **Terraform `required_version` bumped to `>= 1.9.0`** to use cross-variable
   references in `validation` blocks.

## Contributing

We welcome contributions. See [CONTRIBUTING](./CONTRIBUTING.md) for setup and
contribution guidelines.
