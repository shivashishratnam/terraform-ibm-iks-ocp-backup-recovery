##############################################################################
# CRN Parser (resolves region from an existing BRS instance CRN)
##############################################################################

module "crn_parser" {
  source  = "terraform-ibm-modules/common-utilities/ibm//modules/crn-parser"
  version = "1.5.0"
  crn     = var.existing_brs_instance_crn != null ? var.existing_brs_instance_crn : ""
}

##############################################################################
# Backup Recovery Service Instance
##############################################################################

module "backup_recovery_instance" {
  source                    = "terraform-ibm-modules/backup-recovery/ibm"
  version                   = "v1.10.4"
  region                    = local.brs_region
  resource_group_id         = var.cluster_resource_group_id
  ibmcloud_api_key          = var.ibmcloud_api_key
  instance_name             = var.brs_instance_name
  existing_brs_instance_crn = var.existing_brs_instance_crn
  connection_name           = var.brs_connection_name
  create_new_connection     = var.brs_create_new_connection
  resource_tags             = var.resource_tags
  access_tags               = var.access_tags
  connection_env_type       = var.connection_env_type
  policies                  = var.policies
}

##############################################################################
# Runtime Dependency Installation
##############################################################################

resource "terraform_data" "install_dependencies" {
  count = var.install_required_binaries ? 1 : 0
  input = {
    binaries_path = local.binaries_path
  }
  provisioner "local-exec" {
    command     = "${path.module}/scripts/install-binaries.sh ${self.input.binaries_path}"
    interpreter = ["/bin/bash", "-c"]
  }

  provisioner "local-exec" {
    when        = destroy
    command     = "${path.module}/scripts/install-binaries.sh ${self.input.binaries_path}"
    interpreter = ["/bin/bash", "-c"]
  }
}
