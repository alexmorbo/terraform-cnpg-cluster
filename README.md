# terraform-cnpg-cluster

Creates a single CloudNativePG cluster on top of the `cloudnative-pg/cluster`
chart, together with its credentials secrets and its continuous backup.

The operator itself and the Barman Cloud Plugin are out of scope — install both
in the operator namespace (usually `cnpg-system`) before using this module.

## Backups

Backups go through the [Barman Cloud Plugin][plugin]. The in-tree
`spec.backup.barmanObjectStore` route, deprecated upstream since CloudNativePG
1.26, is not offered.

The `ObjectStore`, the `ScheduledBackup` objects and the S3 credentials secret
are managed by this module rather than by the chart. The chart renders the
`ObjectStore` as a `pre-install,pre-upgrade` helm hook, and hook resources stay
out of the release manifest, never appear in a plan, and outlive an uninstall —
where their finalizer then blocks the namespace from going away.

Two defaults are worth knowing about:

- **Server-side encryption is left to the bucket.** The chart forces
  `encryption: AES256`, which asks for SSE-S3 explicitly and so overrides a
  bucket configured for SSE-KMS. Objects still land encrypted, but under a key
  held by the storage rather than by the KMS. This module sends no encryption
  header unless you ask for one.
- **The image is a `standard` one.** The chart derives bare tags such as
  `ghcr.io/cloudnative-pg/postgresql:18`, which are the deprecated `system`
  images. Those bundle barman-cloud, which the plugin makes redundant since the
  binaries now live in the instance sidecar. The reference is assembled from
  `image_registry`, `image_repository`, `postgresql_version`, `image_flavour`
  and `image_distro`; set `image_name` to bypass all five.

```hcl
module "head" {
  source = "github.com/alexmorbo/terraform-cnpg-cluster?ref=v0.4.0"

  name      = "head"
  namespace = "cnpg-head"

  replicas            = 3
  postgresql_version  = "18"
  storage_size        = "20Gi"
  storage_class       = "pve-lvm-ssd"
  wal_storage_enabled = true
  wal_storage_size    = "10Gi"
  wal_storage_class   = "pve-lvm-ssd"

  backups = {
    endpoint_url = "http://seaweedfs-s3.seaweedfs.svc:8333"
    bucket       = "cnpg-head"

    scheduled = [{ name = "daily", schedule = "0 0 3 * * *" }]
  }

  backups_credentials = {
    access_key = var.s3_access_key
    secret_key = var.s3_secret_key
  }

  monitoring = {
    # Fires forever where every node reports the same zone.
    exclude_rules = ["CNPGClusterZoneSpreadWarning"]
  }
}
```

## Anti-affinity

`topology_key` defaults to `kubernetes.io/hostname`, not to the chart's
`topology.kubernetes.io/zone`. On a single-zone cluster the zone key degrades
to nothing: every node reports the same value, the rule is trivially satisfied,
and every instance may end up on one node with nothing to report it. Keep the
`CNPGClusterInstancesOnSameNode` alert enabled as a backstop for the default
`preferred` policy.

## Upgrading from 0.3.x

Breaking. Backups moved to the plugin and the resources were renamed:

| 0.3.x | 0.4.0 |
|---|---|
| `barman_object_store` | `backups` plus `backups_credentials` |
| `backups_provider`, `backups_retention_policy`, `backups_path` | fields of `backups` |
| `kubernetes_secret`, `kubernetes_namespace` | `kubernetes_secret_v1`, `kubernetes_namespace_v1` |

Existing state needs `terraform state mv` for the renamed resources; the
schemas are identical, so nothing is recreated. Clusters still on in-tree
backups have to be migrated to the plugin — see the [upstream migration
guide][migration] — because this module no longer renders
`spec.backup.barmanObjectStore`.

[plugin]: https://cloudnative-pg.io/plugin-barman-cloud/
[migration]: https://cloudnative-pg.io/plugin-barman-cloud/docs/migration/

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 3.2 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 3.2 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.7.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | 3.2.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 3.2.1 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.9.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.database](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_manifest.object_store](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_manifest.scheduled_backup](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_namespace_v1.default](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_secret_v1.auth](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.barman](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.recovery](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.role_credentials](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [random_password.database_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_password.role_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_backups"></a> [backups](#input\_backups) | Continuous backup through the Barman Cloud Plugin. Null disables backups entirely — no ObjectStore, no WAL archiving, no schedules. | <pre>object({<br/>    endpoint_url = string<br/>    bucket       = string<br/>    path         = optional(string, "/")<br/><br/>    existing_secret = optional(string)<br/>    access_key_key  = optional(string, "ACCESS_KEY_ID")<br/>    secret_key_key  = optional(string, "ACCESS_SECRET_KEY")<br/><br/>    retention_policy = optional(string, "30d")<br/><br/>    wal = optional(object({<br/>      compression = optional(string, "gzip")<br/><br/>      # Empty obeys the bucket policy; the chart's AES256 forces SSE-S3 and<br/>      # overrides a bucket configured for SSE-KMS.<br/>      encryption = optional(string, "")<br/><br/>      max_parallel = optional(number, 1)<br/><br/>      archive_additional_command_args = optional(list(string))<br/>      restore_additional_command_args = optional(list(string))<br/>    }), {})<br/><br/>    data = optional(object({<br/>      compression          = optional(string, "gzip")<br/>      encryption           = optional(string, "")<br/>      jobs                 = optional(number, 2)<br/>      immediate_checkpoint = optional(bool, false)<br/><br/>      additional_command_args         = optional(list(string))<br/>      restore_additional_command_args = optional(list(string))<br/>    }), {})<br/><br/>    endpoint_ca = optional(object({<br/>      name = string<br/>      key  = optional(string, "ca.crt")<br/>    }))<br/><br/>    tags         = optional(map(string))<br/>    history_tags = optional(map(string))<br/><br/>    scheduled = optional(list(object({<br/>      name      = string<br/>      schedule  = string<br/>      immediate = optional(bool, true)<br/>      suspend   = optional(bool, false)<br/><br/>      backup_owner_reference = optional(string, "self")<br/><br/>      target = optional(string, "prefer-standby")<br/>    })), [{ name = "daily", schedule = "0 0 3 * * *" }])<br/><br/>    sidecar = optional(object({<br/>      log_level                         = optional(string, "info")<br/>      retention_policy_interval_seconds = optional(number, 1800)<br/>      resources                         = optional(any)<br/>      additional_container_args         = optional(list(string))<br/>    }), {})<br/>  })</pre> | `null` | no |
| <a name="input_backups_credentials"></a> [backups\_credentials](#input\_backups\_credentials) | S3 credentials for the backup object store. Kept out of `backups` because a sensitive object propagates the mark to everything derived from it. Written through `data_wo`, so the values never reach state. Ignored when `backups.existing_secret` is set. | <pre>object({<br/>    access_key = string<br/>    secret_key = string<br/>  })</pre> | `null` | no |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | Version of the cloudnative-pg/cluster chart. 0.8.0 is the minimum: earlier releases cannot render the Barman Cloud Plugin wiring this module depends on. | `string` | `"0.8.1"` | no |
| <a name="input_create_namespace"></a> [create\_namespace](#input\_create\_namespace) | n/a | `bool` | `false` | no |
| <a name="input_database_locale_collate"></a> [database\_locale\_collate](#input\_database\_locale\_collate) | n/a | `string` | `"en_US.UTF8"` | no |
| <a name="input_database_locale_ctype"></a> [database\_locale\_ctype](#input\_database\_locale\_ctype) | n/a | `string` | `"en_US.UTF8"` | no |
| <a name="input_database_name"></a> [database\_name](#input\_database\_name) | n/a | `string` | `null` | no |
| <a name="input_database_password"></a> [database\_password](#input\_database\_password) | n/a | `string` | `null` | no |
| <a name="input_database_password_length"></a> [database\_password\_length](#input\_database\_password\_length) | n/a | `number` | `24` | no |
| <a name="input_database_password_special"></a> [database\_password\_special](#input\_database\_password\_special) | n/a | `bool` | `true` | no |
| <a name="input_database_post_init_sql"></a> [database\_post\_init\_sql](#input\_database\_post\_init\_sql) | n/a | `list(string)` | `[]` | no |
| <a name="input_database_user"></a> [database\_user](#input\_database\_user) | n/a | `string` | `null` | no |
| <a name="input_databases"></a> [databases](#input\_databases) | Additional databases to create. | <pre>list(object({<br/>    name                  = string<br/>    ensure                = optional(string, "present")<br/>    owner                 = optional(string)<br/>    encoding              = optional(string, "UTF8")<br/>    template              = optional(string)<br/>    tablespace            = optional(string)<br/>    connectionLimit       = optional(number, -1)<br/>    isTemplate            = optional(bool, false)<br/>    locale                = optional(string)<br/>    localeProvider        = optional(string)<br/>    localeCollate         = optional(string)<br/>    localeCType           = optional(string)<br/>    icuLocale             = optional(string)<br/>    icuRules              = optional(string)<br/>    databaseReclaimPolicy = optional(string, "retain")<br/>    extensions = optional(list(object({<br/>      name    = string<br/>      ensure  = optional(string, "present")<br/>      version = optional(string)<br/>      schema  = optional(string)<br/>    })), [])<br/>    schemas = optional(list(object({<br/>      name   = string<br/>      owner  = optional(string)<br/>      ensure = optional(string, "present")<br/>    })), [])<br/>  }))</pre> | `[]` | no |
| <a name="input_enable_pdb"></a> [enable\_pdb](#input\_enable\_pdb) | Let CloudNativePG maintain a PodDisruptionBudget so draining a node cannot take the cluster below quorum. | `bool` | `true` | no |
| <a name="input_enable_pod_anti_affinity"></a> [enable\_pod\_anti\_affinity](#input\_enable\_pod\_anti\_affinity) | Keep instances of this cluster apart. CloudNativePG enables this by default. | `bool` | `true` | no |
| <a name="input_enable_superuser_access"></a> [enable\_superuser\_access](#input\_enable\_superuser\_access) | Create the `postgres` superuser secret. CloudNativePG defaults this to false since 1.21; the chart flips it back on. Useful while migrating data in, worth turning off once the cluster settles. | `bool` | `false` | no |
| <a name="input_image_distro"></a> [image\_distro](#input\_image\_distro) | Debian release the image is built on, e.g. trixie or bookworm. | `string` | `"trixie"` | no |
| <a name="input_image_flavour"></a> [image\_flavour](#input\_image\_flavour) | `standard` or `minimal`. Upstream recommends standard alongside the plugin; the bare tags the chart derives on its own are the deprecated system images. | `string` | `"standard"` | no |
| <a name="input_image_name"></a> [image\_name](#input\_image\_name) | Full image reference passed to spec.imageName verbatim. Overrides the repository/version/flavour/distro combination, e.g. for an image bundling extra extensions. | `string` | `null` | no |
| <a name="input_image_registry"></a> [image\_registry](#input\_image\_registry) | Registry the PostgreSQL image is pulled from. Split from the repository so a mirror or a pull-through proxy is a one-line change. | `string` | `"ghcr.io"` | no |
| <a name="input_image_repository"></a> [image\_repository](#input\_image\_repository) | Image path inside the registry. Combined with image\_registry, postgresql\_version, image\_flavour and image\_distro unless image\_name is set. | `string` | `"cloudnative-pg/postgresql"` | no |
| <a name="input_mode"></a> [mode](#input\_mode) | n/a | `string` | `"standalone"` | no |
| <a name="input_monitoring"></a> [monitoring](#input\_monitoring) | n/a | <pre>object({<br/>    enabled = optional(bool, true)<br/><br/>    pod_monitor     = optional(bool, true)<br/>    prometheus_rule = optional(bool, true)<br/><br/>    exclude_rules     = optional(list(string), [])<br/>    additional_labels = optional(map(string), {})<br/><br/>    tls_enabled             = optional(bool, false)<br/>    disable_default_queries = optional(bool, false)<br/>    custom_queries          = optional(list(any), [])<br/><br/>    instrumentation_logical_replication = optional(bool, false)<br/>    instrumentation_pg_stat_statements  = optional(bool, false)<br/>  })</pre> | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | n/a | `string` | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | n/a | `string` | `null` | no |
| <a name="input_node_selector"></a> [node\_selector](#input\_node\_selector) | n/a | `map(string)` | `{}` | no |
| <a name="input_override_cluster_name"></a> [override\_cluster\_name](#input\_override\_cluster\_name) | n/a | `string` | `null` | no |
| <a name="input_pod_anti_affinity_type"></a> [pod\_anti\_affinity\_type](#input\_pod\_anti\_affinity\_type) | `preferred` lets instances share a node when they have nowhere else to go; `required` leaves them Pending instead. Pair `preferred` with the CNPGClusterInstancesOnSameNode alert so a collapse does not go unnoticed. | `string` | `"preferred"` | no |
| <a name="input_poolers"></a> [poolers](#input\_poolers) | PgBouncer connection poolers. | <pre>list(object({<br/>    name      = string<br/>    type      = optional(string, "rw")<br/>    instances = optional(number, 3)<br/>    poolMode  = optional(string, "transaction")<br/>    parameters = optional(map(string), {<br/>      max_client_conn   = "1000"<br/>      default_pool_size = "25"<br/>    })<br/>    monitoring = optional(object({<br/>      enabled = optional(bool, false)<br/>    }))<br/>    template = optional(object({<br/>      spec = optional(object({<br/>        containers = optional(list(object({<br/>          name = string<br/>          resources = optional(object({<br/>            requests = optional(map(string), {})<br/>            limits   = optional(map(string), {})<br/>          }))<br/>        })))<br/>        nodeSelector = optional(map(string))<br/>        tolerations = optional(list(object({<br/>          key      = optional(string)<br/>          operator = optional(string, "Equal")<br/>          value    = optional(string)<br/>          effect   = optional(string)<br/>        })))<br/>      }))<br/>    }))<br/>  }))</pre> | `null` | no |
| <a name="input_postgresql_parameters"></a> [postgresql\_parameters](#input\_postgresql\_parameters) | PostgreSQL parameters passed to spec.postgresql.parameters. | `map(string)` | `{}` | no |
| <a name="input_postgresql_version"></a> [postgresql\_version](#input\_postgresql\_version) | n/a | `string` | `"18"` | no |
| <a name="input_recovery"></a> [recovery](#input\_recovery) | Passed to the chart's `recovery` values verbatim. The chart owns the recovery ObjectStore because it hardcodes its name into externalClusters; supply `recovery.secret.create = false` with a secret of your own to keep the keys out of the release values. | `any` | `null` | no |
| <a name="input_recovery_credentials"></a> [recovery\_credentials](#input\_recovery\_credentials) | S3 credentials for the recovery object store. When set, the module creates the secret and points the chart's `recovery.secret` at it, so the keys stay out of the release values. Split from `recovery` for the same reason as `backups_credentials`. | <pre>object({<br/>    access_key = string<br/>    secret_key = string<br/>  })</pre> | `null` | no |
| <a name="input_replicas"></a> [replicas](#input\_replicas) | n/a | `number` | `1` | no |
| <a name="input_resources"></a> [resources](#input\_resources) | Resource requests and limits for PostgreSQL pods. | <pre>object({<br/>    requests = optional(map(string), {})<br/>    limits   = optional(map(string), {})<br/>  })</pre> | `null` | no |
| <a name="input_roles"></a> [roles](#input\_roles) | PostgreSQL roles to create. | <pre>list(object({<br/>    name             = string<br/>    ensure           = optional(string, "present")<br/>    login            = optional(bool, true)<br/>    superuser        = optional(bool, false)<br/>    createdb         = optional(bool, false)<br/>    createrole       = optional(bool, false)<br/>    inherit          = optional(bool, true)<br/>    replication      = optional(bool, false)<br/>    bypassrls        = optional(bool, false)<br/>    connectionLimit  = optional(number, -1)<br/>    inRoles          = optional(list(string), [])<br/>    password         = optional(string)<br/>    password_length  = optional(number, 24)<br/>    password_special = optional(bool, false)<br/>  }))</pre> | `[]` | no |
| <a name="input_shared_preload_libraries"></a> [shared\_preload\_libraries](#input\_shared\_preload\_libraries) | Libraries preloaded at server start, passed to spec.postgresql.shared\_preload\_libraries. | `list(string)` | `[]` | no |
| <a name="input_storage_class"></a> [storage\_class](#input\_storage\_class) | n/a | `string` | `null` | no |
| <a name="input_storage_size"></a> [storage\_size](#input\_storage\_size) | n/a | `string` | `"10Gi"` | no |
| <a name="input_tolerations"></a> [tolerations](#input\_tolerations) | n/a | `list(map(any))` | `[]` | no |
| <a name="input_topology_key"></a> [topology\_key](#input\_topology\_key) | Node label the anti-affinity rule spreads instances over. The chart's `topology.kubernetes.io/zone` degrades to nothing wherever zones are not modelled. | `string` | `"kubernetes.io/hostname"` | no |
| <a name="input_wal_storage_class"></a> [wal\_storage\_class](#input\_wal\_storage\_class) | n/a | `string` | `null` | no |
| <a name="input_wal_storage_enabled"></a> [wal\_storage\_enabled](#input\_wal\_storage\_enabled) | n/a | `bool` | `false` | no |
| <a name="input_wal_storage_size"></a> [wal\_storage\_size](#input\_wal\_storage\_size) | n/a | `string` | `"1Gi"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_backups_enabled"></a> [backups\_enabled](#output\_backups\_enabled) | Whether continuous backup through the Barman Cloud Plugin is configured |
| <a name="output_barman_secret_name"></a> [barman\_secret\_name](#output\_barman\_secret\_name) | Secret holding the S3 credentials used by the backup sidecar |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | n/a |
| <a name="output_connection_uri"></a> [connection\_uri](#output\_connection\_uri) | n/a |
| <a name="output_database_name"></a> [database\_name](#output\_database\_name) | n/a |
| <a name="output_database_password"></a> [database\_password](#output\_database\_password) | n/a |
| <a name="output_database_user"></a> [database\_user](#output\_database\_user) | n/a |
| <a name="output_databases"></a> [databases](#output\_databases) | List of additional databases (name and owner) |
| <a name="output_host"></a> [host](#output\_host) | Direct database cluster rw endpoint |
| <a name="output_image_name"></a> [image\_name](#output\_image\_name) | Image the cluster actually runs |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | n/a |
| <a name="output_object_store_name"></a> [object\_store\_name](#output\_object\_store\_name) | Name of the ObjectStore the cluster archives to |
| <a name="output_pooler_hosts"></a> [pooler\_hosts](#output\_pooler\_hosts) | Map of pooler hosts: pooler name => host |
| <a name="output_port"></a> [port](#output\_port) | n/a |
| <a name="output_role_credentials"></a> [role\_credentials](#output\_role\_credentials) | Credentials for roles with login (includes URIs for direct and pooler connections) |
| <a name="output_roles"></a> [roles](#output\_roles) | Map of roles with secret names |
<!-- END_TF_DOCS -->
