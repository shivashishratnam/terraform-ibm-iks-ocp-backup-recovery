##############################################################################
# Source Registration
##############################################################################

# DSC needs time to stabilize after the pod reports ready before BRS can
# successfully reach it for source registration.
resource "time_sleep" "wait_for_dsc_stabilization" {
  count = local.deploy_dsc ? 1 : 0

  depends_on      = [helm_release.data_source_connector]
  create_duration = var.dsc_stabilization_wait
}

resource "ibm_backup_recovery_source_registration" "source_registration" {
  count = local.deploy_source_registration ? 1 : 0

  x_ibm_tenant_id = local.brs_tenant_id
  environment     = "kKubernetes"
  connection_id   = local.connection_id
  endpoint_type   = var.brs_endpoint_type
  instance_id     = local.brs_instance_guid
  region          = local.brs_instance_region

  kubernetes_params {
    endpoint                = local.cluster_endpoint
    kubernetes_distribution = var.kube_type == "openshift" ? "kROKS" : "kIKS"
    dynamic "auto_protect_config" {
      for_each = var.enable_auto_protect && var.auto_protect_policy_name != null ? [1] : []
      content {
        is_default_auto_protected = true
        policy_id                 = local.resolved_policy_ids[var.auto_protect_policy_name]
      }
    }
    data_mover_image_location                  = var.registration_images.data_mover
    velero_image_location                      = var.registration_images.velero
    velero_aws_plugin_image_location           = var.registration_images.velero_aws_plugin
    velero_openshift_plugin_image_location     = var.registration_images.velero_openshift_plugin
    init_container_image_location              = var.registration_images.init_container
    cohesity_dataprotect_plugin_image_location = var.registration_images.cohesity_dataprotect_plugin
    kubernetes_type                            = "kCluster"
    client_private_key                         = chomp(kubernetes_secret_v1.brsagent_token[0].data["token"])
  }

  depends_on = [
    helm_release.data_source_connector,
    time_sleep.wait_for_dsc_stabilization,
    time_sleep.brs_source_deregistration_wait,
    module.backup_recovery_instance,
  ]
}

# BRS source deregistration is async on the backend. Without this sleep,
# DeleteDataSourceConnectionWithContext fails with "can't be deleted as it is
# being used by the source" because the connection is still referenced when
# helm_release attempts to delete it.
resource "time_sleep" "brs_source_deregistration_wait" {
  count = local.deploy_source_registration ? 1 : 0

  depends_on       = [terraform_data.wait_before_helm_destroy]
  destroy_duration = var.source_deregistration_wait
}

# Wait for BRS asynchronous discovery to stabilize before reading protection sources.
resource "time_sleep" "wait_for_source_discovery" {
  count = local.deploy_source_registration ? 1 : 0

  depends_on = [
    ibm_backup_recovery_source_registration.source_registration,
    helm_release.data_source_connector,
    terraform_data.install_dependencies
  ]

  triggers = {
    connection_id = local.connection_id
    dsc_version   = var.dsc_image_version
  }

  create_duration = var.source_discovery_wait
}

data "ibm_backup_recovery_protection_sources" "sources" {
  count = 1

  x_ibm_tenant_id = local.brs_tenant_id
  environment     = "kKubernetes"
  instance_id     = local.brs_instance_guid
  region          = local.brs_instance_region
  endpoint_type   = var.brs_endpoint_type

  depends_on = [time_sleep.wait_for_source_discovery]
}

##############################################################################
# Cluster Tagging
##############################################################################

resource "ibm_resource_tag" "cluster_brs_tag" {
  count = var.add_cluster_tags ? 1 : 0

  resource_id = local.cluster_crn
  tag_type    = "user"
  tags        = ["brs-region:${local.brs_instance_region}", "brs-guid:${local.brs_instance_guid}"]
}

##############################################################################
# Auto-Protect Cleanup
##############################################################################

# Auto-protect creates a protection group that cannot be deleted via the provider;
# this provisioner calls a script to delete it on destroy.
resource "terraform_data" "delete_auto_protect_pg" {
  count      = local.deploy_source_registration && var.enable_auto_protect && var.auto_protect_policy_name != null ? 1 : 0
  depends_on = [terraform_data.install_dependencies]

  input = {
    url                 = local.backup_recovery_instance_url
    tenant              = local.brs_tenant_id
    endpoint_type       = var.brs_endpoint_type
    protection_group_id = ibm_backup_recovery_source_registration.source_registration[0].kubernetes_params[0].auto_protect_config[0].protection_group_id
    registration_id     = replace(ibm_backup_recovery_source_registration.source_registration[0].id, "${local.brs_tenant_id}::", "")
    api_key             = sensitive(var.ibmcloud_api_key)
  }

  triggers_replace = {
    api_key = sensitive(var.ibmcloud_api_key)
  }

  provisioner "local-exec" {
    when        = destroy
    command     = "${path.module}/scripts/delete_auto_protect_pg.sh 'https://${self.input.url}' '${self.input.tenant}' '${self.input.endpoint_type}' '${self.input.protection_group_id}' '${self.input.registration_id}'"
    interpreter = ["/bin/bash", "-c"]
    environment = {
      API_KEY = self.triggers_replace.api_key
    }
  }
}
