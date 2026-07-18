# terraform-google-subnets

Terraform module that manages a [Google Cloud](https://cloud.google.com/)
subnetwork (`google_compute_subnetwork`). It creates a single regional subnet
with optional secondary ranges for GKE pods and services, and Private Google
Access enabled by default.

## Usage

```hcl
module "subnet" {
  source = "github.com/cybercapybara/terraform-google-subnets"

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

A runnable example lives in [`examples/basic`](examples/basic).

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| google    | >= 5.0   |

## Inputs

| Name                       | Description                                                        | Type          | Default | Required |
|----------------------------|--------------------------------------------------------------------|---------------|---------|:--------:|
| `project_id`               | ID of the project in which to create the subnetwork.               | `string`      | n/a     |   yes    |
| `name`                     | Name of the subnetwork.                                            | `string`      | n/a     |   yes    |
| `network`                  | Self link or name of the VPC network.                             | `string`      | n/a     |   yes    |
| `region`                   | Region in which to create the subnetwork.                         | `string`      | n/a     |   yes    |
| `ip_cidr_range`            | Primary IPv4 CIDR range of the subnetwork.                        | `string`      | n/a     |   yes    |
| `private_ip_google_access` | Whether VMs without external IPs can reach Google APIs.           | `bool`        | `true`  |    no    |
| `secondary_ip_ranges`      | Secondary IP ranges keyed by range name.                          | `map(string)` | `{}`    |    no    |
| `description`              | Optional description for the subnetwork.                          | `string`      | `null`  |    no    |

## Outputs

| Name              | Description                                    |
|-------------------|------------------------------------------------|
| `id`              | Identifier of the subnetwork.                 |
| `self_link`       | URI of the subnetwork.                        |
| `name`            | Name of the subnetwork.                       |
| `ip_cidr_range`   | Primary IPv4 CIDR range of the subnetwork.    |
| `gateway_address` | Gateway IP address of the subnetwork.         |

## License

[MIT](LICENSE)
