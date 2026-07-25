resource "oci_database_autonomous_database" "this" {
  compartment_id = var.compartment_id
  display_name   = var.display_name
  db_name        = var.db_name
  db_workload    = var.db_workload
  db_version     = var.db_version

  compute_model            = var.compute_model
  compute_count            = var.compute_count
  data_storage_size_in_tbs = var.data_storage_size_in_tbs
  is_auto_scaling_enabled  = var.is_auto_scaling_enabled
  is_free_tier             = var.is_free_tier
  admin_password           = var.admin_password
  license_model            = var.license_model

  # Network placement. Either the database is reachable only through a private
  # endpoint in `subnet_id`, or it keeps its public endpoint and that endpoint is
  # fenced off by an access control list. Setting neither leaves an Autonomous
  # Database whose public endpoint accepts connections from any address on the
  # internet, so the precondition below refuses that combination outright.
  subnet_id              = var.subnet_id
  nsg_ids                = length(var.nsg_ids) > 0 ? var.nsg_ids : null
  private_endpoint_label = var.private_endpoint_label

  # `is_access_control_enabled` only applies to public endpoints; on a private
  # endpoint database OCI rejects it, hence the null.
  is_access_control_enabled = var.subnet_id == null ? true : null
  whitelisted_ips           = var.subnet_id == null ? var.whitelisted_ips : null

  is_mtls_connection_required = var.is_mtls_connection_required

  # Encryption at rest is always on. Leaving both of these null keeps the
  # Oracle-managed key; setting both switches to a customer-managed key in Vault.
  kms_key_id = var.kms_key_id
  vault_id   = var.vault_id

  backup_retention_period_in_days = var.backup_retention_period_in_days
  is_backup_retention_locked      = var.is_backup_retention_locked

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags

  lifecycle {
    precondition {
      condition = (var.subnet_id != null) != (var.whitelisted_ips != null)
      error_message = join(" ", [
        "Set exactly one of subnet_id (private endpoint inside a VCN) or",
        "whitelisted_ips (public endpoint restricted by an access control list).",
        "Setting neither would create an Autonomous Database whose public endpoint",
        "is reachable from every address on the internet; setting both is rejected",
        "by OCI, because access control lists apply to public endpoints only.",
      ])
    }

    precondition {
      condition     = (var.kms_key_id == null) == (var.vault_id == null)
      error_message = "kms_key_id and vault_id must be set together: a customer-managed encryption key needs the OCID of the Vault that holds it."
    }
  }
}
