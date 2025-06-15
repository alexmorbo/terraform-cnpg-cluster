locals {
  cluster_name = coalesce(var.override_cluster_name, var.name)
  namespace    = var.create_namespace ? coalesce(kubernetes_namespace.default[0].metadata[0].name, local.cluster_name) : coalesce(var.namespace, local.cluster_name)

  database_name     = coalesce(var.database_name, var.name)
  database_user     = coalesce(var.database_user, var.name)
  database_password = var.database_password == null ? random_password.database_password[0].result : var.database_password

  barman_object_store = try(var.barman_object_store, {})
  backup = merge(
    {
      enabled = var.barman_object_store != null ? true : false
    },
    merge(local.barman_object_store, {
      provider        = var.backups_provider
      retentionPolicy = var.backups_retention_policy
      s3 = merge(can(local.barman_object_store.s3) ? var.barman_object_store.s3 : {}, {
        path = var.backups_path
      })
    })
  )

  database_post_init_sql = [
    for sql in var.database_post_init_sql : replace(
      sql,
      "%DB_OWNER%", local.database_user
    )
  ]

  values = {
    fullnameOverride = local.cluster_name
    type             = "postgresql"
    mode             = var.mode
    version = {
      postgresql = var.postgresql_version
    }
    cluster = {
      instances = var.replicas
      storage = {
        size         = var.storage_size
        storageClass = var.storage_class
      }
      affinity = {
        nodeSelector = var.node_selector
        tolerations  = var.tolerations
      }
      monitoring = {
        enabled = var.monitoring_enabled
      }
      initdb = {
        database = kubernetes_secret.auth.data.dbname
        owner    = kubernetes_secret.auth.data.username
        secret = {
          name = kubernetes_secret.auth.metadata[0].name
        }
        localeCollate = var.database_locale_collate
        localeCType   = var.database_locale_ctype
        postInitSQL   = local.database_post_init_sql
      }
    }
    backups = local.backup
  }
}
