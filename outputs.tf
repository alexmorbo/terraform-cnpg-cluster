output "connection_uri" {
  value = kubernetes_secret_v1.auth.data.uri

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
      secret_name = role.login ? kubernetes_secret_v1.role_credentials[role.name].metadata[0].name : null
    }
  }
  description = "Map of roles with secret names"
}

output "role_credentials" {
  value = {
    for role in var.roles : role.name => merge(
      kubernetes_secret_v1.role_credentials[role.name].data,
      { secret_name = kubernetes_secret_v1.role_credentials[role.name].metadata[0].name }
    )
    if role.login == true
  }
  sensitive   = true
  description = "Credentials for roles with login (includes URIs for direct and pooler connections)"
}

output "backups_enabled" {
  value       = local.backups_enabled
  description = "Whether continuous backup through the Barman Cloud Plugin is configured"
}

output "object_store_name" {
  value       = local.backups_enabled ? local.object_store_name : null
  description = "Name of the ObjectStore the cluster archives to"
}

output "barman_secret_name" {
  value       = local.barman_secret_name
  description = "Secret holding the S3 credentials used by the backup sidecar"
}

output "image_name" {
  value       = local.image_name
  description = "Image the cluster actually runs"
}
