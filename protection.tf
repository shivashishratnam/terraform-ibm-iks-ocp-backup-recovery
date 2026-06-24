##############################################################################
# Protection Groups
##############################################################################

resource "ibm_backup_recovery_protection_group" "protection_group" {
  for_each = { for pg in var.protection_groups : pg.name => pg }

  x_ibm_tenant_id    = local.brs_tenant_id
  name               = each.value.name
  environment        = "kKubernetes"
  policy_id          = local.resolved_policy_ids[each.value.policy_name]
  description        = each.value.description
  is_paused          = each.value.is_paused
  abort_in_blackouts = each.value.abort_in_blackouts
  pause_in_blackouts = each.value.pause_in_blackouts
  priority           = each.value.priority
  qos_policy         = each.value.qos_policy
  endpoint_type      = var.brs_endpoint_type
  instance_id        = local.brs_instance_guid
  region             = local.brs_instance_region

  kubernetes_params {
    enable_indexing       = each.value.enable_indexing
    leverage_csi_snapshot = each.value.leverage_csi_snapshot
    non_snapshot_backup   = each.value.non_snapshot_backup
    volume_backup_failure = each.value.volume_backup_failure
    exclude_object_ids    = each.value.exclude_object_ids != null ? each.value.exclude_object_ids : []
    label_ids             = each.value.label_ids != null ? each.value.label_ids : []
    exclude_label_ids     = each.value.exclude_label_ids != null ? each.value.exclude_label_ids : []

    dynamic "objects" {
      for_each = each.value.objects != null ? each.value.objects : []
      content {
        id                          = objects.value.id != null ? objects.value.id : try(local.object_name_to_id[objects.value.name][0], null)
        backup_only_pvc             = objects.value.backup_only_pvc
        fail_backup_on_hook_failure = objects.value.fail_backup_on_hook_failure
        included_resources          = objects.value.included_resources
        excluded_resources          = objects.value.excluded_resources

        dynamic "include_pvcs" {
          for_each = objects.value.include_pvcs != null ? objects.value.include_pvcs : []
          content {
            id   = include_pvcs.value.id != null ? include_pvcs.value.id : try(local.object_name_to_id[include_pvcs.value.name][0], null)
            name = include_pvcs.value.name
          }
        }

        dynamic "exclude_pvcs" {
          for_each = objects.value.exclude_pvcs != null ? objects.value.exclude_pvcs : []
          content {
            id   = exclude_pvcs.value.id != null ? exclude_pvcs.value.id : try(local.object_name_to_id[exclude_pvcs.value.name][0], null)
            name = exclude_pvcs.value.name
          }
        }

        dynamic "include_params" {
          for_each = objects.value.include_params != null ? [objects.value.include_params] : []
          content {
            label_combination_method = include_params.value.label_combination_method

            dynamic "label_vector" {
              for_each = include_params.value.label_vector != null ? include_params.value.label_vector : []
              content {
                key   = label_vector.value.key
                value = label_vector.value.value
              }
            }

            dynamic "selected_resources" {
              for_each = include_params.value.selected_resources != null ? include_params.value.selected_resources : []
              content {
                api_group         = selected_resources.value.api_group
                is_cluster_scoped = selected_resources.value.is_cluster_scoped
                kind              = selected_resources.value.kind
                name              = selected_resources.value.name
                version           = selected_resources.value.version

                dynamic "resource_list" {
                  for_each = selected_resources.value.resource_list != null ? selected_resources.value.resource_list : []
                  content {
                    entity_id = resource_list.value.entity_id
                    name      = resource_list.value.name
                  }
                }
              }
            }
          }
        }

        dynamic "exclude_params" {
          for_each = objects.value.exclude_params != null ? [objects.value.exclude_params] : []
          content {
            label_combination_method = exclude_params.value.label_combination_method

            dynamic "label_vector" {
              for_each = exclude_params.value.label_vector != null ? exclude_params.value.label_vector : []
              content {
                key   = label_vector.value.key
                value = label_vector.value.value
              }
            }

            dynamic "selected_resources" {
              for_each = exclude_params.value.selected_resources != null ? exclude_params.value.selected_resources : []
              content {
                api_group         = selected_resources.value.api_group
                is_cluster_scoped = selected_resources.value.is_cluster_scoped
                kind              = selected_resources.value.kind
                name              = selected_resources.value.name
                version           = selected_resources.value.version

                dynamic "resource_list" {
                  for_each = selected_resources.value.resource_list != null ? selected_resources.value.resource_list : []
                  content {
                    entity_id = resource_list.value.entity_id
                    name      = resource_list.value.name
                  }
                }
              }
            }
          }
        }

        dynamic "quiesce_groups" {
          for_each = objects.value.quiesce_groups != null ? objects.value.quiesce_groups : []
          content {
            quiesce_mode = quiesce_groups.value.quiesce_mode

            dynamic "quiesce_rules" {
              for_each = quiesce_groups.value.quiesce_rules
              content {
                dynamic "pod_selector_labels" {
                  for_each = quiesce_rules.value.pod_selector_labels != null ? quiesce_rules.value.pod_selector_labels : []
                  content {
                    key   = pod_selector_labels.value.key
                    value = pod_selector_labels.value.value
                  }
                }

                dynamic "pre_snapshot_hooks" {
                  for_each = quiesce_rules.value.pre_snapshot_hooks
                  content {
                    commands      = pre_snapshot_hooks.value.commands
                    container     = pre_snapshot_hooks.value.container
                    fail_on_error = pre_snapshot_hooks.value.fail_on_error
                    timeout       = pre_snapshot_hooks.value.timeout
                  }
                }

                dynamic "post_snapshot_hooks" {
                  for_each = quiesce_rules.value.post_snapshot_hooks
                  content {
                    commands      = post_snapshot_hooks.value.commands
                    container     = post_snapshot_hooks.value.container
                    fail_on_error = post_snapshot_hooks.value.fail_on_error
                    timeout       = post_snapshot_hooks.value.timeout
                  }
                }
              }
            }
          }
        }
      }
    }

    dynamic "include_params" {
      for_each = each.value.include_params != null ? [each.value.include_params] : []
      content {
        label_combination_method = include_params.value.label_combination_method

        dynamic "label_vector" {
          for_each = include_params.value.label_vector != null ? include_params.value.label_vector : []
          content {
            key   = label_vector.value.key
            value = label_vector.value.value
          }
        }

        dynamic "selected_resources" {
          for_each = include_params.value.selected_resources != null ? include_params.value.selected_resources : []
          content {
            api_group         = selected_resources.value.api_group
            is_cluster_scoped = selected_resources.value.is_cluster_scoped
            kind              = selected_resources.value.kind
            name              = selected_resources.value.name
            version           = selected_resources.value.version

            dynamic "resource_list" {
              for_each = selected_resources.value.resource_list != null ? selected_resources.value.resource_list : []
              content {
                entity_id = resource_list.value.entity_id
                name      = resource_list.value.name
              }
            }
          }
        }
      }
    }

    dynamic "exclude_params" {
      for_each = each.value.exclude_params != null ? [each.value.exclude_params] : []
      content {
        label_combination_method = exclude_params.value.label_combination_method

        dynamic "label_vector" {
          for_each = exclude_params.value.label_vector != null ? exclude_params.value.label_vector : []
          content {
            key   = label_vector.value.key
            value = label_vector.value.value
          }
        }

        dynamic "selected_resources" {
          for_each = exclude_params.value.selected_resources != null ? exclude_params.value.selected_resources : []
          content {
            api_group         = selected_resources.value.api_group
            is_cluster_scoped = selected_resources.value.is_cluster_scoped
            kind              = selected_resources.value.kind
            name              = selected_resources.value.name
            version           = selected_resources.value.version

            dynamic "resource_list" {
              for_each = selected_resources.value.resource_list != null ? selected_resources.value.resource_list : []
              content {
                entity_id = resource_list.value.entity_id
                name      = resource_list.value.name
              }
            }
          }
        }
      }
    }
  }

  dynamic "alert_policy" {
    for_each = each.value.alert_policy != null ? [each.value.alert_policy] : []
    content {
      backup_run_status                                   = alert_policy.value.backup_run_status
      raise_object_level_failure_alert                    = alert_policy.value.raise_object_level_failure_alert
      raise_object_level_failure_alert_after_each_attempt = alert_policy.value.raise_object_level_failure_alert_after_each_attempt
      raise_object_level_failure_alert_after_last_attempt = alert_policy.value.raise_object_level_failure_alert_after_last_attempt

      dynamic "alert_targets" {
        for_each = alert_policy.value.alert_targets != null ? alert_policy.value.alert_targets : []
        content {
          email_address  = alert_targets.value.email_address
          language       = alert_targets.value.language
          recipient_type = alert_targets.value.recipient_type
        }
      }
    }
  }

  dynamic "sla" {
    for_each = each.value.sla != null ? each.value.sla : []
    content {
      backup_run_type = sla.value.backup_run_type
      sla_minutes     = sla.value.sla_minutes
    }
  }

  dynamic "start_time" {
    for_each = each.value.start_time != null ? [each.value.start_time] : []
    content {
      hour      = start_time.value.hour
      minute    = start_time.value.minute
      time_zone = start_time.value.time_zone
    }
  }

  dynamic "advanced_configs" {
    for_each = each.value.advanced_configs != null ? each.value.advanced_configs : []
    content {
      key   = advanced_configs.value.key
      value = advanced_configs.value.value
    }
  }

  depends_on = [
    data.ibm_backup_recovery_protection_sources.sources,
    time_sleep.wait_for_source_discovery
  ]

  lifecycle {
    precondition {
      condition     = length(local.all_flat_objects) > 0
      error_message = <<-EOT
        Protection sources are empty. The Data Source Connector may not have completed
        its initial discovery yet. Wait a few minutes and run 'terraform apply' again.
      EOT
    }

    # The API returns include_params as empty when not explicitly set; ignoring
    # it prevents perpetual drift when include_params is omitted from the config.
    ignore_changes = [
      kubernetes_params[0].objects[0].include_params
    ]
  }
}

##############################################################################
# Cancel Running Backup Jobs Before Protection Group Deletion
##############################################################################

# Cancels any active backup run during destroy so the provider can delete the
# group without hitting "backup in progress" errors from the BRS API.
resource "terraform_data" "cancel_pg_runs" {
  for_each = { for pg in var.protection_groups : pg.name => pg }

  input = {
    url                 = local.backup_recovery_instance_url
    tenant              = local.brs_tenant_id
    endpoint_type       = var.brs_endpoint_type
    protection_group_id = ibm_backup_recovery_protection_group.protection_group[each.key].id
  }

  triggers_replace = {
    api_key = sensitive(var.ibmcloud_api_key)
  }

  provisioner "local-exec" {
    when        = destroy
    command     = "${path.module}/scripts/cancel_pg_runs.sh 'https://${self.input.url}' '${self.input.tenant}' '${self.input.endpoint_type}' '${self.input.protection_group_id}'"
    interpreter = ["/bin/bash", "-c"]
    environment = {
      API_KEY = self.triggers_replace.api_key
    }
  }

  depends_on = [ibm_backup_recovery_protection_group.protection_group]
}
