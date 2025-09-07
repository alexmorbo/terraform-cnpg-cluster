output "connection_uri" {
  value = kubernetes_secret.auth.data.uri

  sensitive = true
}

output "host" {
  value = local.host
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
