##############################################################################
# Cluster Data Sources
##############################################################################

data "ibm_container_vpc_cluster" "vpc_cluster" {
  count = local.is_vpc ? 1 : 0

  name              = var.cluster_id
  resource_group_id = var.cluster_resource_group_id
  wait_till         = var.wait_till
  wait_till_timeout = var.wait_till_timeout
}

data "ibm_container_cluster" "classic_cluster" {
  count = local.is_classic ? 1 : 0

  name              = var.cluster_id
  resource_group_id = var.cluster_resource_group_id
  wait_till         = var.wait_till
  wait_till_timeout = var.wait_till_timeout
}

data "ibm_container_cluster_config" "cluster_config" {
  cluster_name_id   = var.cluster_id
  resource_group_id = var.cluster_resource_group_id
  config_dir        = "${path.module}/kubeconfig"
  endpoint_type     = var.cluster_config_endpoint_type != "default" ? var.cluster_config_endpoint_type : null
  admin             = true

  # Ensures the cluster is ready before fetching the config, preventing timeouts
  # when the cluster is still provisioning.
  depends_on = [
    data.ibm_container_vpc_cluster.vpc_cluster,
    data.ibm_container_cluster.classic_cluster
  ]
}

data "ibm_container_vpc_worker_pool" "pool" {
  count = local.is_vpc ? 1 : 0

  cluster          = data.ibm_container_vpc_cluster.vpc_cluster[0].id
  worker_pool_name = data.ibm_container_vpc_cluster.vpc_cluster[0].worker_pools[0].name
}

##############################################################################
# Data Source Connector Worker Pool
##############################################################################

resource "ibm_container_vpc_worker_pool" "data_source_connector" {
  count = local.deploy_dsc && local.is_vpc && var.create_dsc_worker_pool ? local.num_zones : 0

  cluster           = data.ibm_container_vpc_cluster.vpc_cluster[0].id
  worker_pool_name  = "dsc-pool-zone-${count.index + 1}"
  flavor            = var.dsc_worker_pool_flavor
  vpc_id            = data.ibm_container_vpc_worker_pool.pool[0].vpc_id
  worker_count      = count.index < local.extra_workers ? local.base_workers + 1 : local.base_workers
  resource_group_id = var.cluster_resource_group_id

  zones {
    name      = local.zones_list[count.index].name
    subnet_id = local.zones_list[count.index].subnet_id
  }

  labels = {
    "dedicated" = "data-source-connector"
  }

  taints {
    key    = "dedicated"
    value  = "data-source-connector"
    effect = "NoSchedule"
  }
}
