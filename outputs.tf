##############################################################################
# Outputs
##############################################################################

output "source_registration_id" {
  description = "ID of the registered Kubernetes source. Null if source registration is skipped."
  value       = length(ibm_backup_recovery_source_registration.source_registration) > 0 ? ibm_backup_recovery_source_registration.source_registration[0].id : null
}

output "brs_instance_crn" {
  description = "CRN of the Backup & Recovery Service instance."
  value       = module.backup_recovery_instance.brs_instance_crn
}

output "brs_instance_guid" {
  description = "GUID of the Backup & Recovery Service instance."
  value       = local.brs_instance_guid
}

output "brs_tenant_id" {
  description = "Tenant ID of the Backup & Recovery Service instance."
  value       = local.brs_tenant_id
}

output "connection_id" {
  description = "ID of the data source connection to the Backup & Recovery Service instance."
  value       = local.connection_id
}

output "protection_group_ids" {
  description = "Map of protection group names to their IDs. Empty if protection groups are not deployed."
  value       = { for k, v in ibm_backup_recovery_protection_group.protection_group : k => v.id }
}

output "protection_sources" {
  description = "List of protection sources. Null if protection groups are not deployed."
  value       = length(data.ibm_backup_recovery_protection_sources.sources) > 0 ? data.ibm_backup_recovery_protection_sources.sources[0] : null
}


output "brs_instance_url" {
  description = "Endpoint URL for the BRS instance, derived from the IBM Cloud resource extensions. Correct for both staging and production environments."
  value       = "https://${local.backup_recovery_instance_url}"
}

output "brs_tags" {
  description = "BRS tags that should be added to the cluster to prevent tag drift. Include these in your cluster's tags input."
  value       = ["brs-region:${local.brs_instance_region}", "brs-guid:${local.brs_instance_guid}"]
}
