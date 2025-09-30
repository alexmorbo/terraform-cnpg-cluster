locals {
  pooler_name = "${local.cluster_name}-pooler-${var.pooler_type}"
  pooler_host = var.pooler_enabled ? "${local.pooler_name}.${local.namespace}.svc.cluster.local" : local.host

  # Convert tolerations to proper Kubernetes format
  pooler_tolerations = [
    for t in var.tolerations : {
      key               = lookup(t, "key", null)
      operator          = lookup(t, "operator", "Equal")
      value             = lookup(t, "value", null)
      effect            = lookup(t, "effect", null)
      tolerationSeconds = lookup(t, "tolerationSeconds", null)
    }
  ]
}

resource "kubernetes_manifest" "pooler" {
  count = var.pooler_enabled ? 1 : 0

  manifest = {
    apiVersion = "postgresql.cnpg.io/v1"
    kind       = "Pooler"
    metadata = {
      name      = local.pooler_name
      namespace = local.namespace
    }
    spec = merge(
      {
        cluster = {
          name = local.cluster_name
        }
        instances = var.pooler_instances
        type      = var.pooler_type
        pgbouncer = {
          poolMode   = var.pooler_pool_mode
          parameters = var.pooler_parameters
        }
      },
      length(var.node_selector) > 0 || length(var.tolerations) > 0 || var.pooler_resources != null ? {
        template = {
          spec = merge(
            length(var.node_selector) > 0 ? { nodeSelector = var.node_selector } : {},
            length(var.tolerations) > 0 ? { tolerations = local.pooler_tolerations } : {},
            var.pooler_resources != null ? {
              containers = [{
                name      = "pgbouncer"
                resources = var.pooler_resources
              }]
            } : {}
          )
        }
      } : {}
    )
  }

  depends_on = [helm_release.database]
}
