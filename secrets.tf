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
    dbname   = local.dbname
    host     = local.host
    jdbc-uri = "jdbc:postgresql://${local.host}:${local.port}/${local.dbname}?password=${local.database_password}&user=${local.user}"
    password = local.database_password
    pgpass   = "${local.host}:${local.port}:${local.dbname}:${local.user}:${local.database_password}"
    port     = local.port
    uri      = "postgresql://${local.user}:${local.database_password}@${local.host}:${local.port}"
    user     = local.user
    username = local.username
  }
}
