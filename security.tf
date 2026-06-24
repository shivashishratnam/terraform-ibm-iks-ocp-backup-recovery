##############################################################################
# Security Group Rules for Data Source Connector
##############################################################################

module "dsc_sg_rule" {
  count = local.deploy_dsc && var.add_dsc_rules_to_cluster_sg && local.is_vpc ? 1 : 0

  source                       = "terraform-ibm-modules/security-group/ibm"
  version                      = "v2.9.1"
  resource_group               = var.cluster_resource_group_id
  existing_security_group_name = "kube-${var.cluster_id}"
  use_existing_security_group  = true
  security_group_rules = [
    {
      name      = "allow-outbound-443-from-cdsc-to-brs-dataplane"
      direction = "outbound"
      remote    = "0.0.0.0/0"
      protocol  = "tcp"
      port_min  = 443
      port_max  = 443
    },
    {
      name      = "allow-outbound-29991-from-cdsc-to-brs-dataplane"
      direction = "outbound"
      remote    = "0.0.0.0/0"
      protocol  = "tcp"
      port_min  = 29991
      port_max  = 29991
    },
    {
      name      = "allow-outbound-${local.cluster_endpoint_port}-from-cdsc-to-cluster-api"
      direction = "outbound"
      remote    = "0.0.0.0/0"
      protocol  = "tcp"
      port_min  = local.cluster_endpoint_port
      port_max  = local.cluster_endpoint_port
    }
  ]
}
