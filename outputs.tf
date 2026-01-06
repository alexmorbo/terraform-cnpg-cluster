output "connection_uri" {
  value = kubernetes_secret.auth.data.uri

  sensitive = true
}

output "host" {
  value       = local.host
  description = "Direct database cluster rw endpoint"
}

output "port" {
  value = local.port
}

output "database_name" {
  value = local.database_name
}

output "database_user" {
  value = local.database_user
}

output "database_password" {
  value     = local.database_password
  sensitive = true
}

output "cluster_name" {
  value = local.cluster_name
}

output "namespace" {
  value = local.namespace
}

output "pooler_hosts" {
  value       = local.pooler_hosts
  description = "Map of pooler hosts: pooler name => host"
}

output "databases" {
  value = [
    for db in var.databases : {
      name  = db.name
      owner = db.owner
    }
  ]
  description = "List of additional databases (name and owner)"
}

output "roles" {
  value = {
    for role in var.roles : role.name => {
      name        = role.name
      login       = role.login
      secret_name = role.login ? kubernetes_secret.role_credentials[role.name].metadata[0].name : null
    }
  }
  description = "Map of roles with secret names"
}

output "role_credentials" {
  value = {
    for role in var.roles : role.name => merge(
      kubernetes_secret.role_credentials[role.name].data,
      { secret_name = kubernetes_secret.role_credentials[role.name].metadata[0].name }
    )
    if role.login == true
  }
  sensitive   = true
  description = "Credentials for roles with login (includes URIs for direct and pooler connections)"
}
