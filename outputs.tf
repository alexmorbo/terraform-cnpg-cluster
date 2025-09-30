output "connection_uri" {
  value = kubernetes_secret.auth.data.uri

  sensitive = true
}

output "host" {
  value       = local.pooler_host
  description = "Database host (pooler endpoint if enabled, otherwise cluster rw endpoint)"
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

output "pooler_enabled" {
  value       = var.pooler_enabled
  description = "Whether PgBouncer pooler is enabled"
}

output "pooler_host" {
  value       = var.pooler_enabled ? local.pooler_host : null
  description = "Pooler service hostname (null if pooler disabled)"
}

output "pooler_service_name" {
  value       = var.pooler_enabled ? local.pooler_name : null
  description = "Pooler service name (null if pooler disabled)"
}

output "direct_host" {
  value       = local.host
  description = "Direct database cluster rw endpoint (bypassing pooler)"
}
