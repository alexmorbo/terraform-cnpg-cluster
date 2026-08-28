variable "name" {
  type = string
}

variable "chart_version" {
  type = string

  description = "Version of the cloudnative-pg/cluster chart. 0.8.0 is the minimum: earlier releases cannot render the Barman Cloud Plugin wiring this module depends on."

  default = "0.8.1"
}

variable "override_cluster_name" {
  type = string

  default = null
}

variable "create_namespace" {
  type = bool

  default = false
}

variable "namespace" {
  type = string

  default = null
}

variable "database_name" {
  type = string

  default = null
}

variable "database_user" {
  type = string

  default = null
}

variable "database_password" {
  type      = string
  sensitive = true

  default = null
}

variable "database_password_length" {
  type = number

  default = 24
}

variable "database_password_special" {
  type = bool

  default = true
}

variable "mode" {
  type = string

  default = "standalone"

  validation {
    condition     = contains(["standalone", "recovery", "replica"], var.mode)
    error_message = "mode must be one of: standalone, recovery, replica."
  }
}

variable "postgresql_version" {
  type = string

  default = "18"
}

variable "image_registry" {
  type = string

  description = "Registry the PostgreSQL image is pulled from. Split from the repository so a mirror or a pull-through proxy is a one-line change."

  default = "ghcr.io"
}

variable "image_repository" {
  type = string

  description = "Image path inside the registry. Combined with image_registry, postgresql_version, image_flavour and image_distro unless image_name is set."

  default = "cloudnative-pg/postgresql"
}

variable "image_flavour" {
  type = string

  description = "`standard` or `minimal`. Upstream recommends standard alongside the plugin; the bare tags the chart derives on its own are the deprecated system images."

  default = "standard"

  validation {
    condition     = contains(["standard", "minimal"], var.image_flavour)
    error_message = "image_flavour must be one of: standard, minimal."
  }
}

variable "image_distro" {
  type = string

  description = "Debian release the image is built on, e.g. trixie or bookworm."

  default = "trixie"
}

variable "image_name" {
  type = string

  description = "Full image reference passed to spec.imageName verbatim. Overrides the repository/version/flavour/distro combination, e.g. for an image bundling extra extensions."

  default = null
}

variable "shared_preload_libraries" {
  type = list(string)

  description = "Libraries preloaded at server start, passed to spec.postgresql.shared_preload_libraries."

  default = []
}

variable "replicas" {
  type = number

  default = 1
}

variable "storage_size" {
  type = string

  default = "10Gi"
}

variable "storage_class" {
  type = string

  default = null
}

variable "wal_storage_enabled" {
  type = bool

  default = false
}

variable "wal_storage_size" {
  type = string

  default = "1Gi"
}

variable "wal_storage_class" {
  type = string

  default = null
}

variable "postgresql_parameters" {
  type = map(string)

  description = "PostgreSQL parameters passed to spec.postgresql.parameters."

  default = {}
}

variable "node_selector" {
  type = map(string)

  default = {}
}

variable "tolerations" {
  type = list(map(any))

  default = []
}

variable "enable_pod_anti_affinity" {
  type = bool

  description = "Keep instances of this cluster apart. CloudNativePG enables this by default."

  default = true
}

variable "topology_key" {
  type = string

  description = "Node label the anti-affinity rule spreads instances over. The chart's `topology.kubernetes.io/zone` degrades to nothing wherever zones are not modelled."

  default = "kubernetes.io/hostname"
}

variable "pod_anti_affinity_type" {
  type = string

  description = "`preferred` lets instances share a node when they have nowhere else to go; `required` leaves them Pending instead. Pair `preferred` with the CNPGClusterInstancesOnSameNode alert so a collapse does not go unnoticed."

  default = "preferred"

  validation {
    condition     = contains(["preferred", "required"], var.pod_anti_affinity_type)
    error_message = "pod_anti_affinity_type must be one of: preferred, required."
  }
}

variable "enable_superuser_access" {
  type = bool

  description = "Create the `postgres` superuser secret. CloudNativePG defaults this to false since 1.21; the chart flips it back on. Useful while migrating data in, worth turning off once the cluster settles."

  default = false
}

variable "enable_pdb" {
  type = bool

  description = "Let CloudNativePG maintain a PodDisruptionBudget so draining a node cannot take the cluster below quorum."

  default = true
}

variable "monitoring" {
  type = object({
    enabled = optional(bool, true)

    pod_monitor     = optional(bool, true)
    prometheus_rule = optional(bool, true)

    exclude_rules     = optional(list(string), [])
    additional_labels = optional(map(string), {})

    tls_enabled             = optional(bool, false)
    disable_default_queries = optional(bool, false)
    custom_queries          = optional(list(any), [])

    instrumentation_logical_replication = optional(bool, false)
    instrumentation_pg_stat_statements  = optional(bool, false)
  })

  default = {}
}

variable "database_locale_collate" {
  type = string

  default = "en_US.UTF8"
}

variable "database_locale_ctype" {
  type = string

  default = "en_US.UTF8"
}

variable "database_post_init_sql" {
  type = list(string)

  default = []
}

variable "resources" {
  type = object({
    requests = optional(map(string), {})
    limits   = optional(map(string), {})
  })

  description = "Resource requests and limits for PostgreSQL pods."

  default = null
}

variable "backups" {
  type = object({
    endpoint_url = string
    bucket       = string
    path         = optional(string, "/")

    existing_secret = optional(string)
    access_key_key  = optional(string, "ACCESS_KEY_ID")
    secret_key_key  = optional(string, "ACCESS_SECRET_KEY")

    retention_policy = optional(string, "30d")

    wal = optional(object({
      compression = optional(string, "gzip")

      # Empty obeys the bucket policy; the chart's AES256 forces SSE-S3 and
      # overrides a bucket configured for SSE-KMS.
      encryption = optional(string, "")

      max_parallel = optional(number, 1)

      archive_additional_command_args = optional(list(string))
      restore_additional_command_args = optional(list(string))
    }), {})

    data = optional(object({
      compression          = optional(string, "gzip")
      encryption           = optional(string, "")
      jobs                 = optional(number, 2)
      immediate_checkpoint = optional(bool, false)

      additional_command_args         = optional(list(string))
      restore_additional_command_args = optional(list(string))
    }), {})

    endpoint_ca = optional(object({
      name = string
      key  = optional(string, "ca.crt")
    }))

    tags         = optional(map(string))
    history_tags = optional(map(string))

    scheduled = optional(list(object({
      name      = string
      schedule  = string
      immediate = optional(bool, true)
      suspend   = optional(bool, false)

      backup_owner_reference = optional(string, "self")

      target = optional(string, "prefer-standby")
    })), [{ name = "daily", schedule = "0 0 3 * * *" }])

    sidecar = optional(object({
      log_level                         = optional(string, "info")
      retention_policy_interval_seconds = optional(number, 1800)
      resources                         = optional(any)
      additional_container_args         = optional(list(string))
    }), {})
  })

  description = "Continuous backup through the Barman Cloud Plugin. Null disables backups entirely — no ObjectStore, no WAL archiving, no schedules."

  default = null
}

variable "backups_credentials" {
  type = object({
    access_key = string
    secret_key = string
  })

  description = "S3 credentials for the backup object store. Kept out of `backups` because a sensitive object propagates the mark to everything derived from it. Written through `data_wo`, so the values never reach state. Ignored when `backups.existing_secret` is set."

  sensitive = true

  default = null
}

variable "recovery" {
  type = any

  description = "Passed to the chart's `recovery` values verbatim. The chart owns the recovery ObjectStore because it hardcodes its name into externalClusters; supply `recovery.secret.create = false` with a secret of your own to keep the keys out of the release values."

  default = null
}

variable "recovery_credentials" {
  type = object({
    access_key = string
    secret_key = string
  })

  description = "S3 credentials for the recovery object store. When set, the module creates the secret and points the chart's `recovery.secret` at it, so the keys stay out of the release values. Split from `recovery` for the same reason as `backups_credentials`."

  sensitive = true

  default = null
}

variable "poolers" {
  type = list(object({
    name      = string
    type      = optional(string, "rw")
    instances = optional(number, 3)
    poolMode  = optional(string, "transaction")
    parameters = optional(map(string), {
      max_client_conn   = "1000"
      default_pool_size = "25"
    })
    monitoring = optional(object({
      enabled = optional(bool, false)
    }))
    template = optional(object({
      spec = optional(object({
        containers = optional(list(object({
          name = string
          resources = optional(object({
            requests = optional(map(string), {})
            limits   = optional(map(string), {})
          }))
        })))
        nodeSelector = optional(map(string))
        tolerations = optional(list(object({
          key      = optional(string)
          operator = optional(string, "Equal")
          value    = optional(string)
          effect   = optional(string)
        })))
      }))
    }))
  }))

  description = "PgBouncer connection poolers."

  default = null
}

variable "databases" {
  type = list(object({
    name                  = string
    ensure                = optional(string, "present")
    owner                 = optional(string)
    encoding              = optional(string, "UTF8")
    template              = optional(string)
    tablespace            = optional(string)
    connectionLimit       = optional(number, -1)
    isTemplate            = optional(bool, false)
    locale                = optional(string)
    localeProvider        = optional(string)
    localeCollate         = optional(string)
    localeCType           = optional(string)
    icuLocale             = optional(string)
    icuRules              = optional(string)
    databaseReclaimPolicy = optional(string, "retain")
    extensions = optional(list(object({
      name    = string
      ensure  = optional(string, "present")
      version = optional(string)
      schema  = optional(string)
    })), [])
    schemas = optional(list(object({
      name   = string
      owner  = optional(string)
      ensure = optional(string, "present")
    })), [])
  }))

  description = "Additional databases to create."

  default = []
}

variable "roles" {
  type = list(object({
    name             = string
    ensure           = optional(string, "present")
    login            = optional(bool, true)
    superuser        = optional(bool, false)
    createdb         = optional(bool, false)
    createrole       = optional(bool, false)
    inherit          = optional(bool, true)
    replication      = optional(bool, false)
    bypassrls        = optional(bool, false)
    connectionLimit  = optional(number, -1)
    inRoles          = optional(list(string), [])
    password         = optional(string)
    password_length  = optional(number, 24)
    password_special = optional(bool, false)
  }))

  description = "PostgreSQL roles to create."

  default = []
}
