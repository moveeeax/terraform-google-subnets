# Changelog

All notable changes to this module are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the module uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.2.0] - 2026-11-07

### Added

- `network_users` input (default `[]`) that grants `roles/compute.networkUser` on the
  subnetwork to each listed IAM member via `google_compute_subnetwork_iam_member`, for
  Shared VPC service projects. The plan fails if it is set on a reserved purpose. New
  `network_users` output lists the granted members. ([#3](https://github.com/moveeeax/terraform-google-subnets/issues/3))

[Unreleased]: https://github.com/moveeeax/terraform-google-subnets/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/moveeeax/terraform-google-subnets/compare/v1.1.0...v1.2.0
