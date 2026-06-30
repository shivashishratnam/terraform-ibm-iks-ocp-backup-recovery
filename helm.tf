##############################################################################
# Data Source Connector Namespace
##############################################################################

resource "kubernetes_namespace_v1" "dsc_namespace" {
  count = local.deploy_dsc ? 1 : 0

  metadata {
    name = var.dsc_namespace
  }

  timeouts {
    delete = "10m"
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
      metadata[0].labels
    ]
  }
}

##############################################################################
# Data Source Connector Helm Release
##############################################################################

resource "helm_release" "data_source_connector" {
  count = local.deploy_dsc ? 1 : 0

  name             = var.dsc_name
  chart            = local.dsc_chart
  repository       = local.dsc_chart_location
  namespace        = kubernetes_namespace_v1.dsc_namespace[0].metadata[0].name
  version          = local.dsc_chart_version
  create_namespace = false
  timeout          = var.dsc_helm_timeout
  wait             = true
  atomic           = var.rollback_on_failure

  values = [
    yamlencode({
      secrets = {
        registrationToken = local.registration_token
      }
      image = {
        registry   = var.dsc_registry
        namespace  = element(split("/", var.dsc_image_version), 1)
        repository = "${element(split("/", var.dsc_image_version), 2)}/${element(split("/", split(":", var.dsc_image_version)[0]), 3)}"
        tag        = split("@", split(":", var.dsc_image_version)[1])[0]
      }
      replicaCount     = var.dsc_replicas
      fullnameOverride = var.dsc_name
      resources = {
        limits = {
          cpu    = var.dsc_pod_cpu_limits
          memory = var.dsc_pod_memory_limits
        }
        requests = {
          cpu    = var.dsc_pod_cpu_requests
          memory = var.dsc_pod_memory_requests
        }
      }
      nodeSelector = local.is_vpc && var.create_dsc_worker_pool ? {
        "dedicated" = "data-source-connector"
      } : {}
      tolerations = local.deploy_dsc && local.is_vpc && var.create_dsc_worker_pool ? [
        {
          key      = "dedicated"
          operator = "Equal"
          value    = "data-source-connector"
          effect   = "NoSchedule"
        }
      ] : []
      volumeClaimTemplate = {
        storageClass = var.dsc_storage_class != null ? var.dsc_storage_class : (local.is_vpc ? "ibmc-vpc-block-metro-5iops-tier" : "ibmc-block-silver")
      }
    })
  ]

  depends_on = [
    ibm_container_vpc_worker_pool.data_source_connector,
    kubernetes_namespace_v1.dsc_namespace,
  ]

  lifecycle {
    precondition {
      condition = (
        var.kube_type == "kubernetes" ? contains(["kIksVpc", "kIksClassic"], var.connection_env_type) :
        var.kube_type == "openshift" ? contains(["kRoksVpc", "kRoksClassic"], var.connection_env_type) :
        false
      )
      error_message = "Invalid connection_env_type '${var.connection_env_type}' for kube_type '${var.kube_type}'. When kube_type is 'kubernetes', connection_env_type must be 'kIksVpc' or 'kIksClassic'. When kube_type is 'openshift', connection_env_type must be 'kRoksVpc' or 'kRoksClassic'."
    }
  }
}

##############################################################################
# BRS Agent Service Account & RBAC
##############################################################################

# The cluster mutates image_pull_secret, secret, and annotations outside Terraform;
# ignoring them prevents spurious drift on every plan.
resource "kubernetes_service_account_v1" "brsagent" {
  count = local.deploy_source_registration ? 1 : 0

  metadata {
    name      = "brsagent"
    namespace = var.dsc_namespace
  }

  lifecycle {
    ignore_changes = [
      image_pull_secret,
      secret,
      metadata[0].annotations,
    ]
  }
  depends_on = [kubernetes_namespace_v1.dsc_namespace]
}

# The BRS agent requires cluster-admin to read and snapshot resources across all
# namespaces and to manage Velero/OADP objects during backup and restore. A
# least-privilege custom ClusterRole is not supported by the IBM BRS agent.
# This is an accepted security trade-off documented in the module README.
resource "kubernetes_cluster_role_binding_v1" "brsagent_admin" {
  count = local.deploy_source_registration ? 1 : 0

  metadata {
    name = "brsagent-admin"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.brsagent[0].metadata[0].name
    namespace = kubernetes_service_account_v1.brsagent[0].metadata[0].namespace
  }
}

resource "kubernetes_secret_v1" "brsagent_token" {
  count = local.deploy_source_registration ? 1 : 0

  metadata {
    name      = "brsagent-token"
    namespace = kubernetes_service_account_v1.brsagent[0].metadata[0].namespace
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.brsagent[0].metadata[0].name
    }
  }
  type                           = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true
}

##############################################################################
# Helm Destroy Ordering
##############################################################################

# Keeps brsagent RBAC and token alive during destroy so BRS can clean up
# brs-backup-agent-* namespaces via the DSC pod after source deregistration.
resource "terraform_data" "wait_before_helm_destroy" {
  count = local.deploy_dsc ? 1 : 0

  depends_on = [
    helm_release.data_source_connector,
    kubernetes_cluster_role_binding_v1.brsagent_admin,
    kubernetes_secret_v1.brsagent_token,
  ]

  triggers_replace = {
    helm_release_id = helm_release.data_source_connector[0].id
    kubeconfig_path = data.ibm_container_cluster_config.cluster_config.config_file_path
    dsc_namespace   = var.dsc_namespace
  }

  provisioner "local-exec" {
    when    = destroy
    command = "${path.module}/scripts/wait_for_namespace_cleanup.sh '${self.triggers_replace.dsc_namespace}'"
    environment = {
      KUBECONFIG = self.triggers_replace.kubeconfig_path
    }
  }
}
