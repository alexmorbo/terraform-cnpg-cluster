resource "random_password" "database_password" {
  count = var.database_password == null ? 1 : 0

  length  = var.database_password_length
  special = var.database_password_special
}

resource "kubernetes_secret" "auth" {
  type = "kubernetes.io/basic-auth"

  metadata {
    name      = "${local.cluster_name}-database-credentials"
    namespace = local.namespace
  }

  data = {
    dbname   = local.database_name
    host     = "${local.cluster_name}-rw.${local.namespace}.svc.cluster.local"
    jdbc-uri = "jdbc:postgresql://${local.cluster_name}-rw.${local.namespace}:5432/${local.database_name}?password=${local.database_password}&user=${local.database_user}"
    password = local.database_password
    pgpass   = "${local.cluster_name}-rw.${local.namespace}:5432:${local.database_name}:${local.database_user}:${local.database_password}"
    port     = "5432"
    uri      = "postgresql://${local.database_user}:${local.database_password}@${local.cluster_name}-rw.${local.namespace}.svc.cluster.local:5432"
    user     = local.database_user
    username = local.database_user
  }
}
