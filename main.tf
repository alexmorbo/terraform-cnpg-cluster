resource "kubernetes_namespace" "default" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = coalesce(var.namespace, local.cluster_name)
  }
}

resource "helm_release" "database" {
  chart      = "cluster"
  repository = "https://cloudnative-pg.io/charts/"
  name       = "${local.cluster_name}-cnpg-cluster"
  atomic     = true
  namespace  = local.namespace
  version    = var.chart_version

  values = [yamlencode(local.values)]
}
