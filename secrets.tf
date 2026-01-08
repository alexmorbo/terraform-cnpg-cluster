resource "random_password" "database_password" {
  count = var.database_password == null ? 1 : 0

  length  = var.database_password_length
  special = var.database_password_special
}

resource "random_password" "role_password" {
  for_each = {
    for role in var.roles : role.name => role
    if role.password == null && role.login == true
  }

  length  = each.value.password_length
  special = each.value.password_special
}

locals {
  # Pre-compute role passwords for reuse
  role_passwords = {
    for role in var.roles : role.name => (
      role.password != null ? role.password : random_password.role_password[role.name].result
    ) if role.login == true
  }

  # Pooler hosts map
  pooler_hosts = {
    for p in coalesce(var.poolers, []) : p.name => "${local.cluster_name}-pooler-${p.name}.${local.namespace}.svc.cluster.local"
  }
}

resource "kubernetes_secret" "role_credentials" {
  for_each = {
    for role in var.roles : role.name => role
    if role.login == true
  }

  type = "kubernetes.io/basic-auth"

  metadata {
    name      = "${local.cluster_name}-role-${each.key}"
    namespace = local.namespace
    labels = {
      "cnpg.io/reload" = "true"
    }
  }

  data = merge(
    {
      username = each.key
      password = local.role_passwords[each.key]
      host     = local.host
      port     = local.port
    },
    # Direct cluster URIs
    {
      uri      = "postgresql://${each.key}:${local.role_passwords[each.key]}@${local.host}:${local.port}"
      jdbc-uri = "jdbc:postgresql://${local.host}:${local.port}/?user=${each.key}&password=${local.role_passwords[each.key]}"
    },
    # Pooler URIs for each pooler
    {
      for name, host in local.pooler_hosts : "pooler-${name}-host" => host
    },
    {
      for name, host in local.pooler_hosts : "pooler-${name}-uri" => "postgresql://${each.key}:${local.role_passwords[each.key]}@${host}:${local.port}"
    },
    {
      for name, host in local.pooler_hosts : "pooler-${name}-jdbc-uri" => "jdbc:postgresql://${host}:${local.port}/?user=${each.key}&password=${local.role_passwords[each.key]}"
    }
  )
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
