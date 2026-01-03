locals {
  cluster_name = coalesce(var.override_cluster_name, var.name)
  namespace    = var.create_namespace ? coalesce(kubernetes_namespace.default[0].metadata[0].name, local.cluster_name) : coalesce(var.namespace, local.cluster_name)

  database_name     = coalesce(var.database_name, var.name)
  database_user     = coalesce(var.database_user, var.name)
  database_password = var.database_password == null ? random_password.database_password[0].result : var.database_password

  # Connection details
  host     = "${local.cluster_name}-rw.${local.namespace}.svc.cluster.local"
  port     = "5432"
  dbname   = local.database_name
  user     = local.database_user
  username = local.database_user

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

  database_post_init_sql = (
    var.database_post_init_sql == null || length(var.database_post_init_sql) == 0
    ? null
    : [
      for sql in var.database_post_init_sql : replace(
        sql,
        "%DB_OWNER%", local.database_user
      )
    ]
  )

  values = {
    fullnameOverride = local.cluster_name
    type             = "postgresql"
    mode             = var.mode
    version = {
      postgresql = var.postgresql_version
    }
    cluster = merge(
      {
        instances = var.replicas
        storage = merge(
          { size = var.storage_size },
          var.storage_class != null ? { storageClass = var.storage_class } : {}
        )
        walStorage = merge(
          {
            enabled = var.wal_storage_enabled
            size    = var.wal_storage_size
          },
          var.wal_storage_class != null ? { storageClass = var.wal_storage_class } : {}
        )
        monitoring = {
          enabled = var.monitoring_enabled
        }
        initdb = merge(
          {
            database = kubernetes_secret.auth.data.dbname
            owner    = kubernetes_secret.auth.data.username
            secret = {
              name = kubernetes_secret.auth.metadata[0].name
            }
            localeCollate = var.database_locale_collate
            localeCType   = var.database_locale_ctype
          },
          local.database_post_init_sql != null ? { postInitSQL = local.database_post_init_sql } : {}
        )
      },
      length(var.node_selector) > 0 || length(var.tolerations) > 0 ? {
        affinity = merge(
          length(var.node_selector) > 0 ? { nodeSelector = var.node_selector } : {},
          length(var.tolerations) > 0 ? { tolerations = var.tolerations } : {}
        )
      } : {},
      var.resources != null ? { resources = var.resources } : {}
    )
    backups = local.backup
  }
}
