# terraform-oci-database

Terraform module that manages an [Oracle Cloud Infrastructure](https://www.oracle.com/cloud/)
Autonomous Database. It supports OLTP, Data Warehouse, JSON and APEX workloads, ECPU/OCPU
compute models, auto-scaling and Always Free provisioning.

## Network placement is mandatory

An Autonomous Database created with neither a private endpoint nor an access control list
gets a **public endpoint that accepts connections from every address on the internet**, with
the ADMIN password as the only thing standing in the way. The module refuses to build that
shape: you must set exactly one of

- `subnet_id` — put the database on a private endpoint inside a VCN (optionally with
  `nsg_ids` and `private_endpoint_label`), or
- `whitelisted_ips` — keep the public endpoint but restrict it to specific addresses,
  CIDR blocks or VCN OCIDs.

Anything else fails at plan time with an explanatory error.

## Usage

```hcl
module "database" {
  source = "github.com/moveeeax/terraform-oci-database"

  compartment_id = var.compartment_id
  display_name   = "prod-adb"
  db_name        = "proddb"
  db_workload    = "OLTP"

  compute_count            = 4
  data_storage_size_in_tbs = 2
  is_auto_scaling_enabled  = true
  admin_password           = var.admin_password

  # Private endpoint: no public endpoint at all.
  subnet_id = var.subnet_id
  nsg_ids   = [var.database_nsg_id]

  # Customer-managed encryption key (optional; omit for the Oracle-managed key).
  kms_key_id = var.kms_key_id
  vault_id   = var.vault_id

  backup_retention_period_in_days = 60

  freeform_tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

A runnable example lives in [`examples/basic`](examples/basic).

## Backups and destroy semantics

Automatic backups cannot be turned off for an Autonomous Database, and
`backup_retention_period_in_days` controls how long they are kept (1-60 days, OCI defaults
to 60). There is **no final-backup option on delete**: terminating the database removes its
automatic backups along with it. If the data has to outlive the instance, take a long-term
backup before destroying, or set `is_backup_retention_locked = true` so backups cannot be
removed before the retention period expires — note that the lock cannot be undone.

`admin_password` is marked sensitive and has no default. Pass it from a secret store; the
module validates it against OCI's complexity rules at plan time rather than letting the
create call fail half-way through.

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| oci       | >= 5.0   |

Running the test suite additionally requires Terraform/OpenTofu >= 1.7 for `mock_provider`.

## Inputs

| Name                              | Description                                                                                 | Type           | Default              | Required |
|-----------------------------------|---------------------------------------------------------------------------------------------|----------------|----------------------|:--------:|
| `compartment_id`                  | OCID of the compartment in which to create the database.                                    | `string`       | n/a                  |   yes    |
| `display_name`                    | Human-readable name for the autonomous database.                                            | `string`       | n/a                  |   yes    |
| `db_name`                         | Database name (1-14 alphanumeric, starts with a letter).                                    | `string`       | n/a                  |   yes    |
| `subnet_id`                       | Subnet OCID for a private endpoint. Mutually exclusive with `whitelisted_ips`.               | `string`       | `null`               |  see above |
| `whitelisted_ips`                 | Access control list for the public endpoint. Mutually exclusive with `subnet_id`.            | `list(string)` | `null`               |  see above |
| `nsg_ids`                         | Network security group OCIDs for the private endpoint.                                      | `list(string)` | `[]`                 |    no    |
| `private_endpoint_label`          | Hostname prefix for the private endpoint.                                                   | `string`       | `null`               |    no    |
| `is_mtls_connection_required`     | Whether mutual TLS is required for client connections.                                      | `bool`         | `true`               |    no    |
| `db_workload`                     | Workload type (`OLTP`, `DW`, `AJD`, `APEX`).                                                | `string`       | `"OLTP"`             |    no    |
| `db_version`                      | Oracle Database version; `null` takes the version OCI provisions by default.                 | `string`       | `null`               |    no    |
| `compute_model`                   | Compute model (`ECPU` or `OCPU`).                                                           | `string`       | `"ECPU"`             |    no    |
| `compute_count`                   | Number of compute units allocated.                                                          | `number`       | `2`                  |    no    |
| `data_storage_size_in_tbs`        | Data storage size in terabytes.                                                             | `number`       | `1`                  |    no    |
| `is_auto_scaling_enabled`         | Whether compute auto-scaling is enabled.                                                    | `bool`         | `true`               |    no    |
| `is_free_tier`                    | Whether the database is Always Free.                                                        | `bool`         | `false`              |    no    |
| `admin_password`                  | ADMIN user password (sensitive); required by OCI for a real deployment.                      | `string`       | `null`               |    no    |
| `license_model`                   | License model.                                                                              | `string`       | `"LICENSE_INCLUDED"` |    no    |
| `kms_key_id`                      | Customer-managed Vault key OCID. Must be set with `vault_id`.                                | `string`       | `null`               |    no    |
| `vault_id`                        | Vault OCID holding `kms_key_id`. Must be set with `kms_key_id`.                              | `string`       | `null`               |    no    |
| `backup_retention_period_in_days` | Automatic backup retention, 1-60 days. `null` uses the OCI default.                          | `number`       | `null`               |    no    |
| `is_backup_retention_locked`      | Lock the retention period so backups cannot be deleted early. Cannot be undone.              | `bool`         | `false`              |    no    |
| `freeform_tags`                   | Free-form tags applied to the database.                                                     | `map(string)`  | `{}`                 |    no    |
| `defined_tags`                    | Defined tags applied to the database, keyed `namespace.key`.                                | `map(string)`  | `{}`                 |    no    |

## Outputs

| Name                  | Description                                                     |
|-----------------------|-----------------------------------------------------------------|
| `id`                  | OCID of the autonomous database.                                |
| `db_name`             | Database name.                                                  |
| `connection_strings`  | Connection strings for the database (sensitive).                |
| `service_console_url` | URL of the database service console.                            |
| `private_endpoint`    | Private endpoint hostname, empty when the endpoint is public.   |
| `state`               | Lifecycle state of the autonomous database.                     |

## Testing

The suite in [`tests/`](tests) runs offline against a mocked provider — no OCI credentials,
no API calls:

```sh
terraform init -backend=false
terraform test
```

## License

[MIT](LICENSE)
