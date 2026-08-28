
locals {
  barman_plugin_name = "barman-cloud.cloudnative-pg.io"

  backups_enabled   = var.backups != null
  object_store_name = "${local.cluster_name}-backups"

  barman_secret_name = local.backups_enabled ? coalesce(
    var.backups.existing_secret,
    "${local.cluster_name}-barman-s3",
  ) : null

  create_barman_secret = local.backups_enabled && var.backups.existing_secret == null && var.backups_credentials != null

  # Revision derived from the credentials so a rotation upstream carries through.
  barman_secret_revision = local.create_barman_secret ? nonsensitive(parseint(substr(
    sha256("${var.backups_credentials.access_key}:${var.backups_credentials.secret_key}"), 0, 8
  ), 16)) : 0

  recovery_secret_name   = "${local.cluster_name}-recovery-s3"
  create_recovery_secret = var.recovery != null && var.recovery_credentials != null
  recovery_secret_revision = local.create_recovery_secret ? nonsensitive(parseint(substr(
    sha256("${var.recovery_credentials.access_key}:${var.recovery_credentials.secret_key}"), 0, 8
  ), 16)) : 0

  backups_wal = local.backups_enabled ? merge(
    {
      compression = var.backups.wal.compression
      maxParallel = var.backups.wal.max_parallel
    },
    var.backups.wal.encryption != "" ? { encryption = var.backups.wal.encryption } : {},
    var.backups.wal.archive_additional_command_args != null ? {
      archiveAdditionalCommandArgs = var.backups.wal.archive_additional_command_args
    } : {},
    var.backups.wal.restore_additional_command_args != null ? {
      restoreAdditionalCommandArgs = var.backups.wal.restore_additional_command_args
    } : {},
  ) : null

  backups_data = local.backups_enabled ? merge(
    {
      compression         = var.backups.data.compression
      jobs                = var.backups.data.jobs
      immediateCheckpoint = var.backups.data.immediate_checkpoint
    },
    var.backups.data.encryption != "" ? { encryption = var.backups.data.encryption } : {},
    var.backups.data.additional_command_args != null ? {
      additionalCommandArgs = var.backups.data.additional_command_args
    } : {},
    var.backups.data.restore_additional_command_args != null ? {
      restoreAdditionalCommandArgs = var.backups.data.restore_additional_command_args
    } : {},
  ) : null

  backups_sidecar = local.backups_enabled ? merge(
    {
      logLevel                       = var.backups.sidecar.log_level
      retentionPolicyIntervalSeconds = var.backups.sidecar.retention_policy_interval_seconds
    },
    var.backups.sidecar.resources != null ? { resources = var.backups.sidecar.resources } : {},
    var.backups.sidecar.additional_container_args != null ? {
      additionalContainerArgs = var.backups.sidecar.additional_container_args
    } : {},
  ) : null

  object_store_configuration = local.backups_enabled ? merge(
    {
      destinationPath = "s3://${var.backups.bucket}${var.backups.path}"
      endpointURL     = var.backups.endpoint_url
      s3Credentials = {
        accessKeyId = {
          name = local.barman_secret_name
          key  = var.backups.access_key_key
        }
        secretAccessKey = {
          name = local.barman_secret_name
          key  = var.backups.secret_key_key
        }
      }
      wal  = local.backups_wal
      data = local.backups_data
    },
    var.backups.endpoint_ca != null ? {
      endpointCA = {
        name = var.backups.endpoint_ca.name
        key  = var.backups.endpoint_ca.key
      }
    } : {},
    var.backups.tags != null ? { tags = var.backups.tags } : {},
    var.backups.history_tags != null ? { historyTags = var.backups.history_tags } : {},
  ) : null
}

resource "kubernetes_secret_v1" "barman" {
  count = local.create_barman_secret ? 1 : 0

  type = "Opaque"

  metadata {
    name      = local.barman_secret_name
    namespace = local.namespace

    labels = {
      "cnpg.io/cluster" = local.cluster_name
      "cnpg.io/reload"  = "true"
    }
  }

  data_wo = {
    (var.backups.access_key_key) = var.backups_credentials.access_key
    (var.backups.secret_key_key) = var.backups_credentials.secret_key
  }

  data_wo_revision = local.barman_secret_revision
}

resource "kubernetes_secret_v1" "recovery" {
  count = local.create_recovery_secret ? 1 : 0

  type = "Opaque"

  metadata {
    name      = local.recovery_secret_name
    namespace = local.namespace

    labels = {
      "cnpg.io/cluster" = local.cluster_name
      "cnpg.io/reload"  = "true"
    }
  }

  data_wo = {
    ACCESS_KEY_ID     = var.recovery_credentials.access_key
    ACCESS_SECRET_KEY = var.recovery_credentials.secret_key
  }

  data_wo_revision = local.recovery_secret_revision
}

resource "kubernetes_manifest" "object_store" {
  count = local.backups_enabled ? 1 : 0

  manifest = {
    apiVersion = "barmancloud.cnpg.io/v1"
    kind       = "ObjectStore"

    metadata = {
      name      = local.object_store_name
      namespace = local.namespace
      labels = {
        "cnpg.io/cluster" = local.cluster_name
      }
    }

    spec = {
      retentionPolicy = var.backups.retention_policy

      configuration                = local.object_store_configuration
      instanceSidecarConfiguration = local.backups_sidecar
    }
  }

  depends_on = [kubernetes_secret_v1.barman]
}

resource "kubernetes_manifest" "scheduled_backup" {
  for_each = local.backups_enabled ? { for s in var.backups.scheduled : s.name => s } : {}

  manifest = {
    apiVersion = "postgresql.cnpg.io/v1"
    kind       = "ScheduledBackup"

    metadata = {
      name      = "${local.cluster_name}-${each.key}"
      namespace = local.namespace
      labels = {
        "cnpg.io/cluster"             = local.cluster_name
        "app.kubernetes.io/component" = "backups"
      }
    }

    spec = {
      schedule  = each.value.schedule
      immediate = each.value.immediate
      suspend   = each.value.suspend

      backupOwnerReference = each.value.backup_owner_reference
      target               = each.value.target

      method = "plugin"
      pluginConfiguration = {
        name = local.barman_plugin_name
      }

      cluster = {
        name = local.cluster_name
      }
    }
  }

  depends_on = [helm_release.database]
}
