locals {
  cluster_name = coalesce(var.override_cluster_name, var.name)
  namespace    = var.create_namespace ? kubernetes_namespace_v1.default[0].metadata[0].name : coalesce(var.namespace, local.cluster_name)

  database_name     = coalesce(var.database_name, var.name)
  database_user     = coalesce(var.database_user, var.name)
  database_password = var.database_password == null ? random_password.database_password[0].result : var.database_password

  host     = "${local.cluster_name}-rw.${local.namespace}.svc.cluster.local"
  port     = "5432"
  dbname   = local.database_name
  user     = local.database_user
  username = local.database_user

  image_name = coalesce(
    var.image_name,
    "${var.image_registry}/${var.image_repository}:${var.postgresql_version}-${var.image_flavour}-${var.image_distro}",
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

  databases_values = [
    for db in var.databases : {
      for k, v in {
        name                  = db.name
        ensure                = db.ensure
        owner                 = db.owner
        encoding              = db.encoding
        template              = db.template
        tablespace            = db.tablespace
        connectionLimit       = db.connectionLimit != -1 ? db.connectionLimit : null
        isTemplate            = db.isTemplate == true ? true : null
        locale                = db.locale
        localeProvider        = db.localeProvider
        localeCollate         = db.localeCollate
        localeCType           = db.localeCType
        icuLocale             = db.icuLocale
        icuRules              = db.icuRules
        databaseReclaimPolicy = db.databaseReclaimPolicy
        extensions = length(db.extensions) > 0 ? [
          for ext in db.extensions : {
            for ek, ev in {
              name    = ext.name
              ensure  = ext.ensure
              version = ext.version
              schema  = ext.schema
            } : ek => ev if ev != null
          }
        ] : null
        schemas = length(db.schemas) > 0 ? [
          for schema in db.schemas : {
            for sk, sv in {
              name   = schema.name
              owner  = schema.owner
              ensure = schema.ensure
            } : sk => sv if sv != null
          }
        ] : null
      } : k => v if v != null
    }
  ]

  roles_values = [
    for role in var.roles : {
      for k, v in {
        name            = role.name
        ensure          = role.ensure
        login           = role.login
        superuser       = role.superuser
        createdb        = role.createdb
        createrole      = role.createrole
        inherit         = role.inherit
        replication     = role.replication
        bypassrls       = role.bypassrls
        connectionLimit = role.connectionLimit != -1 ? role.connectionLimit : null
        inRoles         = length(role.inRoles) > 0 ? role.inRoles : null
        passwordSecret  = role.login == true ? { name = kubernetes_secret_v1.role_credentials[role.name].metadata[0].name } : null
      } : k => v if v != null
    }
  ]

  affinity = merge(
    {
      enablePodAntiAffinity = var.enable_pod_anti_affinity
      podAntiAffinityType   = var.pod_anti_affinity_type
      topologyKey           = var.topology_key
    },
    length(var.node_selector) > 0 ? { nodeSelector = var.node_selector } : {},
    length(var.tolerations) > 0 ? { tolerations = var.tolerations } : {},
  )

  monitoring_values = {
    enabled = var.monitoring.enabled
    podMonitor = {
      enabled = var.monitoring.pod_monitor
      labels  = var.monitoring.additional_labels
    }
    prometheusRule = {
      enabled          = var.monitoring.prometheus_rule
      excludeRules     = var.monitoring.exclude_rules
      additionalLabels = var.monitoring.additional_labels
    }
    instrumentation = {
      logicalReplication = var.monitoring.instrumentation_logical_replication
      pgStatStatements   = var.monitoring.instrumentation_pg_stat_statements
    }
    tls                   = { enabled = var.monitoring.tls_enabled }
    disableDefaultQueries = var.monitoring.disable_default_queries
    customQueries         = var.monitoring.custom_queries
  }

  values = merge(local.values_base, local.values_optional)

  values_optional = merge(
    var.recovery != null ? { recovery = local.recovery_values } : {},
    length(local.databases_values) > 0 ? { databases = local.databases_values } : {},
    var.poolers != null ? { poolers = var.poolers } : {},
  )

  recovery_values = var.recovery == null ? null : merge(
    var.recovery,
    local.create_recovery_secret ? {
      secret = {
        create = false
        name   = local.recovery_secret_name
      }
    } : {},
  )

  values_base = {
    fullnameOverride = local.cluster_name
    type             = "postgresql"
    mode             = var.mode
    version = {
      postgresql = var.postgresql_version
    }

    cluster = merge(
      {
        instances             = var.replicas
        imageName             = local.image_name
        affinity              = local.affinity
        monitoring            = local.monitoring_values
        enableSuperuserAccess = var.enable_superuser_access
        enablePDB             = var.enable_pdb

        plugins = local.backups_enabled ? [
          {
            name          = local.barman_plugin_name
            enabled       = true
            isWALArchiver = true
            parameters = {
              barmanObjectName = local.object_store_name
            }
          }
        ] : []

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
        initdb = merge(
          {
            database = local.dbname
            owner    = local.username
            secret = {
              name = kubernetes_secret_v1.auth.metadata[0].name
            }
            localeCollate = var.database_locale_collate
            localeCType   = var.database_locale_ctype
          },
          local.database_post_init_sql != null ? { postInitSQL = local.database_post_init_sql } : {}
        )
      },
      var.resources != null ? { resources = var.resources } : {},
      length(var.postgresql_parameters) > 0 || length(var.shared_preload_libraries) > 0 ? {
        postgresql = merge(
          length(var.postgresql_parameters) > 0 ? { parameters = var.postgresql_parameters } : {},
          length(var.shared_preload_libraries) > 0 ? { shared_preload_libraries = var.shared_preload_libraries } : {},
        )
      } : {},
      length(local.roles_values) > 0 ? { roles = local.roles_values } : {}
    )

    backups = { enabled = false }
  }
}
