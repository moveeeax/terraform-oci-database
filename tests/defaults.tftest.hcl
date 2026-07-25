# Offline test suite for the module's safety-relevant defaults.
#
# Run with `terraform test` (or `tofu test`) from the repository root. These
# tests need no OCI credentials and make no API calls: `mock_provider` supplies
# every provider response.
#
# NOTE: `mock_provider` requires Terraform >= 1.7 / OpenTofu >= 1.7. That is a
# requirement of the test tooling only - the module itself still supports the
# `>= 1.5` declared in versions.tf, so do not raise required_version for this.

mock_provider "oci" {}

variables {
  compartment_id = "ocid1.compartment.oc1..aaaaaaaaexamplecompartment"
  display_name   = "test-adb"
  db_name        = "testdb"
  admin_password = "Str0ngPassphrase!7"
}

# The finding this module was fixed for: with no subnet and no access control
# list, the database would come up with a public endpoint open to the internet.
run "rejects_public_endpoint_without_access_control" {
  command = plan

  expect_failures = [oci_database_autonomous_database.this]
}

# Access control lists apply to public endpoints only, so the two network modes
# cannot be combined.
run "rejects_subnet_and_whitelist_together" {
  command = plan

  variables {
    subnet_id       = "ocid1.subnet.oc1..aaaaaaaaexamplesubnet"
    whitelisted_ips = ["10.0.0.0/16"]
  }

  expect_failures = [oci_database_autonomous_database.this]
}

run "private_endpoint_placement" {
  command = plan

  variables {
    subnet_id              = "ocid1.subnet.oc1..aaaaaaaaexamplesubnet"
    nsg_ids                = ["ocid1.networksecuritygroup.oc1..aaaaaaaaexamplensg"]
    private_endpoint_label = "testdb"
  }

  assert {
    condition     = oci_database_autonomous_database.this.subnet_id == "ocid1.subnet.oc1..aaaaaaaaexamplesubnet"
    error_message = "subnet_id must be passed through so the database gets a private endpoint."
  }

  assert {
    condition     = oci_database_autonomous_database.this.whitelisted_ips == null
    error_message = "whitelisted_ips must not be sent for a private-endpoint database; OCI rejects the combination."
  }

  assert {
    condition     = oci_database_autonomous_database.this.is_mtls_connection_required == true
    error_message = "Mutual TLS must be required by default."
  }
}

run "public_endpoint_with_access_control" {
  command = plan

  variables {
    whitelisted_ips = ["203.0.113.0/24"]
  }

  assert {
    condition     = oci_database_autonomous_database.this.is_access_control_enabled == true
    error_message = "A public endpoint must have database-level access control enabled, otherwise whitelisted_ips is ignored."
  }

  assert {
    condition     = tolist(oci_database_autonomous_database.this.whitelisted_ips) == tolist(["203.0.113.0/24"])
    error_message = "whitelisted_ips must be passed through to the access control list."
  }
}

run "customer_managed_key_passthrough" {
  command = plan

  variables {
    whitelisted_ips = ["203.0.113.0/24"]
    kms_key_id      = "ocid1.key.oc1..aaaaaaaaexamplekey"
    vault_id        = "ocid1.vault.oc1..aaaaaaaaexamplevault"
  }

  assert {
    condition     = oci_database_autonomous_database.this.kms_key_id == "ocid1.key.oc1..aaaaaaaaexamplekey"
    error_message = "kms_key_id must be passed through so the database is encrypted with the customer-managed key."
  }

  assert {
    condition     = oci_database_autonomous_database.this.vault_id == "ocid1.vault.oc1..aaaaaaaaexamplevault"
    error_message = "vault_id must be passed through alongside kms_key_id."
  }
}

run "rejects_customer_managed_key_without_vault" {
  command = plan

  variables {
    whitelisted_ips = ["203.0.113.0/24"]
    kms_key_id      = "ocid1.key.oc1..aaaaaaaaexamplekey"
  }

  expect_failures = [oci_database_autonomous_database.this]
}

run "rejects_empty_access_control_list" {
  command = plan

  variables {
    whitelisted_ips = []
  }

  expect_failures = [var.whitelisted_ips]
}

run "rejects_weak_admin_password" {
  command = plan

  variables {
    whitelisted_ips = ["203.0.113.0/24"]
    admin_password  = "password"
  }

  expect_failures = [var.admin_password]
}

run "rejects_admin_password_containing_admin" {
  command = plan

  variables {
    whitelisted_ips = ["203.0.113.0/24"]
    admin_password  = "SuperAdmin1234"
  }

  expect_failures = [var.admin_password]
}

run "rejects_invalid_workload" {
  command = plan

  variables {
    whitelisted_ips = ["203.0.113.0/24"]
    db_workload     = "NotAWorkload"
  }

  expect_failures = [var.db_workload]
}

run "rejects_out_of_range_backup_retention" {
  command = plan

  variables {
    whitelisted_ips                 = ["203.0.113.0/24"]
    backup_retention_period_in_days = 90
  }

  expect_failures = [var.backup_retention_period_in_days]
}

run "rejects_invalid_db_name" {
  command = plan

  variables {
    whitelisted_ips = ["203.0.113.0/24"]
    db_name         = "9-bad-name"
  }

  expect_failures = [var.db_name]
}
