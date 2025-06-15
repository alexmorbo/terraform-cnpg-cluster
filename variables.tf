variable "name" {
  type = string
}

variable "chart_version" {
  type = string

  default = "0.3.1"
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

  default = null
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
