provider "oci" {}

module "database" {
  source = "../.."

  compartment_id = var.compartment_id
  display_name   = "example-adb"
  db_name        = "exampledb"
  db_workload    = "OLTP"

  compute_count            = 2
  data_storage_size_in_tbs = 1
  admin_password           = var.admin_password

  # The module refuses to create a database that is both public and unrestricted,
  # so pick a network mode. This example keeps the public endpoint and fences it
  # off with an access control list; set `subnet_id` instead to place the
  # database on a private endpoint inside a VCN.
  whitelisted_ips = var.whitelisted_ips

  freeform_tags = {
    Environment = "sandbox"
    ManagedBy   = "terraform"
  }
}

variable "compartment_id" {
  description = "Compartment OCID to deploy the example database into."
  type        = string
}

variable "admin_password" {
  description = "ADMIN password for the example autonomous database."
  type        = string
  sensitive   = true
}

variable "whitelisted_ips" {
  description = "Addresses, CIDR blocks or VCN OCIDs allowed to reach the public endpoint."
  type        = list(string)
  default     = ["203.0.113.0/24"]
}

output "database_id" {
  value = module.database.id
}
