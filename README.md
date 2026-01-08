# terraform-cnpg-cluster

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.17.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.37.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.7.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | 2.17.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.37.1 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.database](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace.default](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_secret.auth](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.role_credentials](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [random_password.database_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_password.role_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_backups_path"></a> [backups\_path](#input\_backups\_path) | n/a | `string` | `"/"` | no |
| <a name="input_backups_provider"></a> [backups\_provider](#input\_backups\_provider) | n/a | `string` | `"s3"` | no |
| <a name="input_backups_retention_policy"></a> [backups\_retention\_policy](#input\_backups\_retention\_policy) | n/a | `string` | `"10d"` | no |
| <a name="input_barman_object_store"></a> [barman\_object\_store](#input\_barman\_object\_store) | n/a | <pre>object({<br/>    endpointURL = string<br/>    s3 = object({<br/>      bucket    = string<br/>      path      = string<br/>      accessKey = string<br/>      secretKey = string<br/>    })<br/>  })</pre> | `null` | no |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | n/a | `string` | `"0.5.0"` | no |
| <a name="input_create_namespace"></a> [create\_namespace](#input\_create\_namespace) | n/a | `bool` | `false` | no |
| <a name="input_database_locale_collate"></a> [database\_locale\_collate](#input\_database\_locale\_collate) | n/a | `string` | `"en_US.UTF8"` | no |
| <a name="input_database_locale_ctype"></a> [database\_locale\_ctype](#input\_database\_locale\_ctype) | n/a | `string` | `"en_US.UTF8"` | no |
| <a name="input_database_name"></a> [database\_name](#input\_database\_name) | n/a | `string` | `null` | no |
| <a name="input_database_password"></a> [database\_password](#input\_database\_password) | n/a | `string` | `null` | no |
| <a name="input_database_password_length"></a> [database\_password\_length](#input\_database\_password\_length) | n/a | `number` | `24` | no |
| <a name="input_database_password_special"></a> [database\_password\_special](#input\_database\_password\_special) | n/a | `bool` | `true` | no |
| <a name="input_database_post_init_sql"></a> [database\_post\_init\_sql](#input\_database\_post\_init\_sql) | n/a | `list(string)` | `[]` | no |
| <a name="input_database_user"></a> [database\_user](#input\_database\_user) | n/a | `string` | `null` | no |
| <a name="input_databases"></a> [databases](#input\_databases) | Additional databases to create (CNPG 0.5.0+) | <pre>list(object({<br/>    name                  = string<br/>    ensure                = optional(string, "present")<br/>    owner                 = optional(string)<br/>    encoding              = optional(string, "UTF8")<br/>    template              = optional(string)<br/>    tablespace            = optional(string)<br/>    connectionLimit       = optional(number, -1)<br/>    isTemplate            = optional(bool, false)<br/>    locale                = optional(string)<br/>    localeProvider        = optional(string)<br/>    localeCollate         = optional(string)<br/>    localeCType           = optional(string)<br/>    icuLocale             = optional(string)<br/>    icuRules              = optional(string)<br/>    databaseReclaimPolicy = optional(string, "retain")<br/>    extensions = optional(list(object({<br/>      name    = string<br/>      ensure  = optional(string, "present")<br/>      version = optional(string)<br/>      schema  = optional(string)<br/>    })), [])<br/>    schemas = optional(list(object({<br/>      name   = string<br/>      owner  = optional(string)<br/>      ensure = optional(string, "present")<br/>    })), [])<br/>  }))</pre> | `[]` | no |
| <a name="input_mode"></a> [mode](#input\_mode) | n/a | `string` | `"standalone"` | no |
| <a name="input_monitoring_enabled"></a> [monitoring\_enabled](#input\_monitoring\_enabled) | n/a | `bool` | `false` | no |
| <a name="input_name"></a> [name](#input\_name) | n/a | `string` | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | n/a | `string` | `null` | no |
| <a name="input_node_selector"></a> [node\_selector](#input\_node\_selector) | n/a | `map(string)` | `{}` | no |
| <a name="input_override_cluster_name"></a> [override\_cluster\_name](#input\_override\_cluster\_name) | n/a | `string` | `null` | no |
| <a name="input_poolers"></a> [poolers](#input\_poolers) | PgBouncer connection poolers (CNPG 0.5.0+) | <pre>list(object({<br/>    name      = string<br/>    type      = optional(string, "rw")<br/>    instances = optional(number, 3)<br/>    poolMode  = optional(string, "transaction")<br/>    parameters = optional(map(string), {<br/>      max_client_conn   = "1000"<br/>      default_pool_size = "25"<br/>    })<br/>    monitoring = optional(object({<br/>      enabled = optional(bool, false)<br/>    }))<br/>    template = optional(object({<br/>      spec = optional(object({<br/>        containers = optional(list(object({<br/>          name = string<br/>          resources = optional(object({<br/>            requests = optional(map(string), {})<br/>            limits   = optional(map(string), {})<br/>          }))<br/>        })))<br/>        nodeSelector = optional(map(string))<br/>        tolerations = optional(list(object({<br/>          key      = optional(string)<br/>          operator = optional(string, "Equal")<br/>          value    = optional(string)<br/>          effect   = optional(string)<br/>        })))<br/>      }))<br/>    }))<br/>  }))</pre> | `null` | no |
| <a name="input_postgresql_version"></a> [postgresql\_version](#input\_postgresql\_version) | n/a | `string` | `"16"` | no |
| <a name="input_recovery"></a> [recovery](#input\_recovery) | n/a | `any` | `null` | no |
| <a name="input_replicas"></a> [replicas](#input\_replicas) | n/a | `number` | `1` | no |
| <a name="input_resources"></a> [resources](#input\_resources) | Resource requests and limits for PostgreSQL pods | <pre>object({<br/>    requests = optional(map(string), {})<br/>    limits   = optional(map(string), {})<br/>  })</pre> | `null` | no |
| <a name="input_roles"></a> [roles](#input\_roles) | PostgreSQL roles to create (CNPG 0.5.0+) | <pre>list(object({<br/>    name             = string<br/>    ensure           = optional(string, "present")<br/>    login            = optional(bool, true)<br/>    superuser        = optional(bool, false)<br/>    createdb         = optional(bool, false)<br/>    createrole       = optional(bool, false)<br/>    inherit          = optional(bool, true)<br/>    replication      = optional(bool, false)<br/>    bypassrls        = optional(bool, false)<br/>    connectionLimit  = optional(number, -1)<br/>    inRoles          = optional(list(string), [])<br/>    password         = optional(string)<br/>    password_length  = optional(number, 24)<br/>    password_special = optional(bool, false)<br/>  }))</pre> | `[]` | no |
| <a name="input_storage_class"></a> [storage\_class](#input\_storage\_class) | n/a | `string` | `null` | no |
| <a name="input_storage_size"></a> [storage\_size](#input\_storage\_size) | n/a | `string` | `"10Gi"` | no |
| <a name="input_tolerations"></a> [tolerations](#input\_tolerations) | n/a | `list(map(any))` | `[]` | no |
| <a name="input_wal_storage_class"></a> [wal\_storage\_class](#input\_wal\_storage\_class) | n/a | `string` | `null` | no |
| <a name="input_wal_storage_enabled"></a> [wal\_storage\_enabled](#input\_wal\_storage\_enabled) | n/a | `bool` | `false` | no |
| <a name="input_wal_storage_size"></a> [wal\_storage\_size](#input\_wal\_storage\_size) | n/a | `string` | `"1Gi"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | n/a |
| <a name="output_connection_uri"></a> [connection\_uri](#output\_connection\_uri) | n/a |
| <a name="output_database_name"></a> [database\_name](#output\_database\_name) | n/a |
| <a name="output_database_password"></a> [database\_password](#output\_database\_password) | n/a |
| <a name="output_database_user"></a> [database\_user](#output\_database\_user) | n/a |
| <a name="output_databases"></a> [databases](#output\_databases) | List of additional databases (name and owner) |
| <a name="output_host"></a> [host](#output\_host) | Direct database cluster rw endpoint |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | n/a |
| <a name="output_pooler_hosts"></a> [pooler\_hosts](#output\_pooler\_hosts) | Map of pooler hosts: pooler name => host |
| <a name="output_port"></a> [port](#output\_port) | n/a |
| <a name="output_role_credentials"></a> [role\_credentials](#output\_role\_credentials) | Credentials for roles with login (includes URIs for direct and pooler connections) |
| <a name="output_roles"></a> [roles](#output\_roles) | Map of roles with secret names |
<!-- END_TF_DOCS -->
