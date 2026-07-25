variable "compartment_id" {
  description = "OCID of the compartment in which to create the autonomous database."
  type        = string
}

variable "display_name" {
  description = "Human-readable name for the autonomous database."
  type        = string
}

variable "db_name" {
  description = "Database name (alphanumeric, up to 14 characters, no reserved words)."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9]{0,13}$", var.db_name))
    error_message = "db_name must start with a letter and be 1-14 alphanumeric characters."
  }
}

variable "db_workload" {
  description = "Autonomous database workload type."
  type        = string
  default     = "OLTP"

  validation {
    condition     = contains(["OLTP", "DW", "AJD", "APEX"], var.db_workload)
    error_message = "db_workload must be OLTP, DW, AJD, or APEX."
  }
}

variable "db_version" {
  description = "Oracle Database version, for example \"23ai\". Leave null to take the version OCI currently provisions by default, which avoids pinning consumers to a release that later goes end-of-life."
  type        = string
  default     = null
}

variable "compute_model" {
  description = "Compute model for the database (ECPU or OCPU)."
  type        = string
  default     = "ECPU"

  validation {
    condition     = contains(["ECPU", "OCPU"], var.compute_model)
    error_message = "compute_model must be ECPU or OCPU."
  }
}

variable "compute_count" {
  description = "Number of compute units (ECPUs or OCPUs) allocated to the database."
  type        = number
  default     = 2
}

variable "data_storage_size_in_tbs" {
  description = "Data storage size in terabytes."
  type        = number
  default     = 1
}

variable "is_auto_scaling_enabled" {
  description = "Whether compute auto-scaling is enabled."
  type        = bool
  default     = true
}

variable "is_free_tier" {
  description = "Whether the database is an Always Free autonomous database."
  type        = bool
  default     = false
}

variable "admin_password" {
  description = "Password for the ADMIN user. OCI rejects the create call when this is unset, so it must be supplied for any real deployment; it is left optional only so the module can be planned without a credential. Never hard-code it - pass it from a secret store or a sensitive variable."
  type        = string
  default     = null
  sensitive   = true

  validation {
    # OCI password rules for the ADMIN user. Checked here so a bad password
    # fails at plan time rather than half-way through provisioning.
    condition = var.admin_password == null ? true : (
      length(var.admin_password) >= 12 &&
      length(var.admin_password) <= 30 &&
      can(regex("[A-Z]", var.admin_password)) &&
      can(regex("[a-z]", var.admin_password)) &&
      can(regex("[0-9]", var.admin_password)) &&
      !can(regex("\"", var.admin_password)) &&
      !can(regex("(?i)admin", var.admin_password))
    )
    error_message = "admin_password must be 12-30 characters long, contain at least one uppercase letter, one lowercase letter and one digit, must not contain a double quote, and must not contain the string \"admin\"."
  }
}

variable "license_model" {
  description = "License model for the database."
  type        = string
  default     = "LICENSE_INCLUDED"

  validation {
    condition     = contains(["LICENSE_INCLUDED", "BRING_YOUR_OWN_LICENSE"], var.license_model)
    error_message = "license_model must be LICENSE_INCLUDED or BRING_YOUR_OWN_LICENSE."
  }
}

# --- Network placement -------------------------------------------------------
# Exactly one of subnet_id or whitelisted_ips must be supplied; see the
# precondition on oci_database_autonomous_database.this in main.tf.

variable "subnet_id" {
  description = "OCID of the subnet to place a private endpoint in. Set this to keep the database off the public internet. Mutually exclusive with whitelisted_ips."
  type        = string
  default     = null
}

variable "nsg_ids" {
  description = "OCIDs of network security groups applied to the private endpoint. Only meaningful together with subnet_id."
  type        = list(string)
  default     = []
}

variable "private_endpoint_label" {
  description = "Hostname prefix for the private endpoint. Only meaningful together with subnet_id."
  type        = string
  default     = null
}

variable "whitelisted_ips" {
  description = "Access control list for the public endpoint: IP addresses, CIDR blocks or VCN OCIDs allowed to connect. Set this only when the database must keep a public endpoint. Mutually exclusive with subnet_id."
  type        = list(string)
  default     = null

  validation {
    condition     = var.whitelisted_ips == null ? true : length(var.whitelisted_ips) > 0
    error_message = "whitelisted_ips must contain at least one entry; an empty list would leave the public endpoint open to every address on the internet. Use subnet_id instead if the database should have no public endpoint."
  }
}

variable "is_mtls_connection_required" {
  description = "Whether mutual TLS is required for client connections. Leave true unless a private-endpoint deployment specifically needs one-way TLS."
  type        = bool
  default     = true
}

# --- Encryption and backups --------------------------------------------------

variable "kms_key_id" {
  description = "OCID of a customer-managed Vault key used to encrypt the database. Leave null to use the Oracle-managed key. Must be set together with vault_id."
  type        = string
  default     = null
}

variable "vault_id" {
  description = "OCID of the Vault holding kms_key_id. Must be set together with kms_key_id."
  type        = string
  default     = null
}

variable "backup_retention_period_in_days" {
  description = "Retention period for automatic backups, 1-60 days. Leave null to use the OCI default (60 days). Terminating the database deletes its automatic backups, so take a long-term backup first if the data must outlive the instance."
  type        = number
  default     = null

  validation {
    condition     = var.backup_retention_period_in_days == null ? true : (var.backup_retention_period_in_days >= 1 && var.backup_retention_period_in_days <= 60)
    error_message = "backup_retention_period_in_days must be between 1 and 60."
  }
}

variable "is_backup_retention_locked" {
  description = "Whether to lock the backup retention period. Once locked, the retention period cannot be shortened and backups cannot be deleted before it expires. Enable this for databases whose backups must survive an operator mistake; note the lock cannot be undone."
  type        = bool
  default     = false
}

# --- Tagging -----------------------------------------------------------------

variable "freeform_tags" {
  description = "Free-form tags applied to the autonomous database."
  type        = map(string)
  default     = {}
}

variable "defined_tags" {
  description = "Defined tags applied to the autonomous database, keyed as \"namespace.key\"."
  type        = map(string)
  default     = {}
}
