variable "name" {
  type = string
}

variable "chart_version" {
  type = string

  default = "0.5.0"
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
  type = string

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
}

variable "postgresql_version" {
  type = string

  default = "16"
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

variable "node_selector" {
  type = map(string)

  default = {}
}

variable "tolerations" {
  type = list(map(any))

  default = []
}

variable "monitoring_enabled" {
  type = bool

  default = false
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

variable "barman_object_store" {
  type = object({
    endpointURL = string
    s3 = object({
      bucket    = string
      path      = string
      accessKey = string
      secretKey = string
    })
  })

  default = null
}

variable "backups_provider" {
  type = string

  default = "s3"
}

variable "backups_retention_policy" {
  type = string

  default = "10d"
}

variable "backups_path" {
  type = string

  default = "/"
}

variable "resources" {
  type = object({
    requests = optional(map(string), {})
    limits   = optional(map(string), {})
  })
  description = "Resource requests and limits for PostgreSQL pods"

  default = null
}

variable "poolers" {
  description = "PgBouncer connection poolers (CNPG 0.5.0+)"
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

  default = []
}

variable "recovery" {
  type = any

  default = null
}

variable "databases" {
  description = "Additional databases to create (CNPG 0.5.0+)"
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

  default = []
}

variable "roles" {
  description = "PostgreSQL roles to create (CNPG 0.5.0+)"
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

  default = []
}
