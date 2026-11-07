# Changelog

All notable changes to this module are documented in this file. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the module follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `admin_password_secret` input (`{ secret_id, version }`) that reads the ADMIN password from an
  OCI Vault secret through the provider's `secret_id` and `secret_version_number` arguments, so
  the password is no longer in tfvars or state (#3).

### Changed

- Exactly one of `admin_password` or `admin_password_secret` must now be set. Before,
  `admin_password` could be left null and the plan succeeded, with OCI rejecting the create call
  later; that configuration now fails at plan time instead. Configurations that could be applied
  before are unaffected.
