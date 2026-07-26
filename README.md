# terraform-google-subnets

Terraform module that manages a [Google Cloud](https://cloud.google.com/)
subnetwork (`google_compute_subnetwork`). It creates a single regional subnet
with optional secondary ranges for GKE pods and services, and it defaults to
Private Google Access **and VPC flow logs** enabled.

The companion [`terraform-google-vpc`](https://github.com/moveeeax/terraform-google-vpc)
module manages the `google_compute_network` only; everything subnet-shaped —
ranges, Private Google Access, flow logs — lives here.

## Usage

```hcl
module "subnet" {
  source = "github.com/moveeeax/terraform-google-subnets"

  project_id    = var.project_id
  name          = "prod-subnet"
  network       = module.vpc.self_link
  region        = "us-central1"
  ip_cidr_range = "10.20.0.0/24"

  secondary_ip_ranges = {
    pods     = "10.21.0.0/16"
    services = "10.22.0.0/20"
  }
}
```

Runnable examples live in [`examples/basic`](examples/basic) and
[`examples/proxy-only`](examples/proxy-only).

## Defaults worth knowing

- **VPC flow logs are on.** The Compute API leaves them off, which means a
  subnet has no record of accepted or denied traffic — exactly what you need
  during an incident. The module enables them at the API's own defaults
  (5-second aggregation, 0.5 sampling, all metadata). Flow logs are billed on
  log volume; turn the sampling rate down, or opt out entirely, with
  `flow_logs`:

  ```hcl
  flow_logs = {
    aggregation_interval = "INTERVAL_15_MIN"
    flow_sampling        = 0.1
    metadata             = "EXCLUDE_ALL_METADATA"
  }

  # or
  flow_logs = { enabled = false }
  ```

- **Private Google Access is on.** Without it, a VM with no external IP cannot
  reach Google APIs at all.

- **Ranges are validated before the plan is applied.** `ip_cidr_range` and every
  entry of `secondary_ip_ranges` must be a well-formed IPv4 CIDR whose host bits
  are clear, and no two ranges on the subnet may overlap. Google enforces all of
  this too, but only once the request is in flight.

## Subnet purposes

`purpose` defaults to `PRIVATE`, an ordinary subnet for VMs. The proxy, Private
Service Connect and NAT purposes reserve the range for a Google-managed control
plane instead, and the API rejects Private Google Access, flow logs and
secondary ranges on them — so the module leaves all three off for those
purposes rather than letting the apply fail.

`role` is the other half of the pairing. It is **required** for
`REGIONAL_MANAGED_PROXY` and `GLOBAL_MANAGED_PROXY`, and **rejected** for
`PRIVATE`, `PRIVATE_SERVICE_CONNECT` and `PRIVATE_NAT`. Get that combination
wrong and Google fails the apply; the module fails the plan instead.

```hcl
module "proxy_only_subnet" {
  source = "github.com/moveeeax/terraform-google-subnets"

  project_id    = var.project_id
  name          = "prod-proxy-only"
  network       = module.vpc.self_link
  region        = "us-central1"
  ip_cidr_range = "10.30.0.0/24"
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}
```

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| google    | >= 5.0   |

Running the test suite additionally needs Terraform or OpenTofu >= 1.7 for
`mock_provider`. That is a requirement of the tests only, not of the module.

## Inputs

| Name                       | Description                                                                                       | Type          | Default     | Required |
|----------------------------|---------------------------------------------------------------------------------------------------|---------------|-------------|:--------:|
| `project_id`               | ID of the project in which to create the subnetwork.                                              | `string`      | n/a         |   yes    |
| `name`                     | Name of the subnetwork. Must be a valid RFC 1035 name.                                            | `string`      | n/a         |   yes    |
| `network`                  | Self link or name of the VPC network.                                                             | `string`      | n/a         |   yes    |
| `region`                   | Region in which to create the subnetwork.                                                         | `string`      | n/a         |   yes    |
| `ip_cidr_range`            | Primary IPv4 CIDR range, `/29` or larger, with no host bits set.                                  | `string`      | n/a         |   yes    |
| `private_ip_google_access` | Whether VMs without external IPs can reach Google APIs. Forced off for reserved purposes.         | `bool`        | `true`      |    no    |
| `secondary_ip_ranges`      | Secondary IP ranges keyed by range name.                                                          | `map(string)` | `{}`        |    no    |
| `description`              | Optional description for the subnetwork.                                                          | `string`      | `null`      |    no    |
| `purpose`                  | Subnet purpose. See [Subnet purposes](#subnet-purposes).                                          | `string`      | `"PRIVATE"` |    no    |
| `role`                     | `ACTIVE` or `BACKUP`. Required for proxy-only purposes, rejected for the rest.                     | `string`      | `null`      |    no    |
| `flow_logs`                | VPC flow log settings. See [Defaults worth knowing](#defaults-worth-knowing).                      | `object`      | `{}`        |    no    |

### `flow_logs`

| Field                  | Type           | Default                  | Description                                                                 |
|------------------------|----------------|--------------------------|-----------------------------------------------------------------------------|
| `enabled`              | `bool`         | `true`                   | Whether to enable VPC flow logs.                                            |
| `aggregation_interval` | `string`       | `"INTERVAL_5_SEC"`       | `INTERVAL_5_SEC`, `_30_SEC`, `_1_MIN`, `_5_MIN`, `_10_MIN` or `_15_MIN`.    |
| `flow_sampling`        | `number`       | `0.5`                    | Sampling rate, greater than 0 and at most 1.                                |
| `metadata`             | `string`       | `"INCLUDE_ALL_METADATA"` | `INCLUDE_ALL_METADATA`, `EXCLUDE_ALL_METADATA` or `CUSTOM_METADATA`.        |
| `metadata_fields`      | `list(string)` | `null`                   | Fields to report. Required with, and only used by, `CUSTOM_METADATA`.       |
| `filter_expr`          | `string`       | `null`                   | CEL expression selecting which flows to log.                                |

## Outputs

| Name                  | Description                                                          |
|-----------------------|----------------------------------------------------------------------|
| `id`                  | Identifier of the subnetwork.                                        |
| `self_link`           | URI of the subnetwork.                                               |
| `name`                | Name of the subnetwork.                                              |
| `ip_cidr_range`       | Primary IPv4 CIDR range of the subnetwork.                           |
| `gateway_address`     | Gateway IP address of the subnetwork.                                |
| `secondary_ip_ranges` | Secondary IP ranges keyed by range name, ready to hand to GKE.       |
| `flow_logs_enabled`   | Whether VPC flow logs are enabled on the subnetwork.                 |

## Known limitation

Removing every entry from `secondary_ip_ranges` does not remove the ranges from
an existing subnet. The provider needs `send_secondary_ip_range_if_empty` for
that, which does not exist in google `5.0`, this module's declared floor.
Delete the ranges out of band, or pin a newer provider and set the attribute
yourself, until the floor is raised.

## Development

```sh
terraform fmt -recursive
terraform init -backend=false && terraform validate
terraform test          # mocked provider: no credentials, no API calls
```

## License

[MIT](LICENSE)
