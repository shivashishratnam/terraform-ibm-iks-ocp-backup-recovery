locals {
  # --- Environment type detection ---
  is_vpc     = length(regexall("Vpc$", var.connection_env_type)) > 0
  is_classic = length(regexall("Classic$", var.connection_env_type)) > 0

  # --- Deployment mode flags (always true; kept as named booleans for readability) ---
  deploy_dsc                 = true
  deploy_source_registration = true
  deploy_protection_groups   = true

  # --- BRS region: cluster region for new instances, existing instance region otherwise ---
  brs_region = var.existing_brs_instance_crn != null ? module.crn_parser.region : var.region

  # --- Cluster attributes resolved from VPC or Classic data sources ---
  cluster_crn                  = local.is_vpc ? data.ibm_container_vpc_cluster.vpc_cluster[0].crn : data.ibm_container_cluster.classic_cluster[0].crn
  cluster_private_endpoint_url = local.is_vpc ? data.ibm_container_vpc_cluster.vpc_cluster[0].private_service_endpoint_url : data.ibm_container_cluster.classic_cluster[0].private_service_endpoint_url
  cluster_public_endpoint_url  = local.is_vpc ? data.ibm_container_vpc_cluster.vpc_cluster[0].public_service_endpoint_url : data.ibm_container_cluster.classic_cluster[0].public_service_endpoint_url
  cluster_private_available    = local.is_vpc ? data.ibm_container_vpc_cluster.vpc_cluster[0].private_service_endpoint : data.ibm_container_cluster.classic_cluster[0].private_service_endpoint
  cluster_endpoint             = var.cluster_config_endpoint_type == "private" && local.cluster_private_available ? local.cluster_private_endpoint_url : local.cluster_public_endpoint_url
  cluster_endpoint_port        = element(split(":", local.cluster_endpoint), -1)

  # --- Helm chart URI parsing ---
  uri_no_digest      = split("@", var.dsc_chart_uri)[0]
  chart_with_version = element(split("/", local.uri_no_digest), -1)
  dsc_chart          = split(":", local.chart_with_version)[0]
  dsc_chart_version  = replace(local.chart_with_version, "${local.dsc_chart}:", "")
  dsc_chart_location = replace(local.uri_no_digest, "/${local.chart_with_version}", "")

  # --- BRS instance attributes ---
  brs_tenant_id                        = module.backup_recovery_instance.tenant_id
  connection_id                        = module.backup_recovery_instance.connection_id
  registration_token                   = module.backup_recovery_instance.registration_token
  backup_recovery_instance_public_url  = module.backup_recovery_instance.brs_instance.extensions["endpoints.public"]
  backup_recovery_instance_private_url = module.backup_recovery_instance.brs_instance.extensions["endpoints.private"]
  brs_instance_guid                    = module.backup_recovery_instance.brs_instance_guid
  brs_instance_region                  = element(split(":", module.backup_recovery_instance.brs_instance_crn), 5)
  backup_recovery_instance_url         = var.brs_endpoint_type == "public" ? local.backup_recovery_instance_public_url : local.backup_recovery_instance_private_url
  resolved_policy_ids                  = module.backup_recovery_instance.resolved_policy_ids

  binaries_path = "/tmp"

  # --- DSC worker pool zone distribution ---
  # num_zones is derived from var.dsc_worker_pool_zones (known at plan time) so the
  # resource count remains stable across applies.
  num_zones     = local.deploy_dsc && local.is_vpc && var.create_dsc_worker_pool ? var.dsc_worker_pool_zones : 0
  zones_list    = local.deploy_dsc && local.is_vpc && var.create_dsc_worker_pool ? [for zone in data.ibm_container_vpc_worker_pool.pool[0].zones : zone] : []
  base_workers  = local.num_zones > 0 ? floor(var.dsc_replicas / local.num_zones) : 0
  extra_workers = local.num_zones > 0 ? var.dsc_replicas % local.num_zones : 0

  # --- Protection source object map (name → ID, flattened 3 levels deep) ---
  all_env_nodes = local.deploy_protection_groups ? flatten([
    for env in(try(data.ibm_backup_recovery_protection_sources.sources[0].protection_sources, []) != null ? data.ibm_backup_recovery_protection_sources.sources[0].protection_sources : []) :
    (env.nodes != null ? env.nodes : [])
  ]) : []

  all_l1_ps = flatten([
    for node in local.all_env_nodes : [
      for ps in(node.protection_source != null ? node.protection_source : []) : {
        id   = ps.id
        name = ps.name
      }
    ]
  ])

  all_l2_nodes = flatten([
    for node in local.all_env_nodes :
    (node.nodes != null ? node.nodes : [])
  ])

  all_l2_ps = flatten([
    for node in local.all_l2_nodes : [
      for ps in(node.protection_source != null ? node.protection_source : []) : {
        id   = ps.id
        name = ps.name
      }
    ]
  ])

  all_l3_nodes = flatten([
    for node in local.all_l2_nodes :
    (node.nodes != null ? node.nodes : [])
  ])

  all_l3_ps = flatten([
    for node in local.all_l3_nodes : [
      for ps in(node.protection_source != null ? node.protection_source : []) : {
        id   = ps.id
        name = ps.name
      }
    ]
  ])

  all_flat_objects  = concat(local.all_l1_ps, local.all_l2_ps, local.all_l3_ps)
  object_name_to_id = { for obj in local.all_flat_objects : obj.name => obj.id... }

}
