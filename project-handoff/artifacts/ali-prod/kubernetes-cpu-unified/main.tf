terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "2.19.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"
    }
  }
}

provider "coder" {
}

provider "kubernetes" {
  config_path    = "/mnt/secrets/kube/config"
  config_context = data.coder_parameter.cluster.value
}

data "coder_parameter" "cluster" {
  name         = "cluster"
  display_name = "部署集群"
  order        = 1
  description  = "创建后不可更改，PVC 保留在所选集群。"
  type         = "string"
  default      = "beast01"
  mutable      = false
  option {
    name  = "beast01"
    value = "beast01"
  }
  option {
    name  = "yunqiao"
    value = "yunqiao"
  }
  option {
    name  = "beast03"
    value = "beast03"
  }
}

data "coder_parameter" "dev_image" {
  name         = "dev_image"
  display_name = "开发镜像"
  description  = "填写完整镜像地址（tag 或 digest）。镜像需包含 sh 和 apt-get，或预装启动脚本所需工具；原 ENTRYPOINT 会被替换。私有仓库需预先配置集群拉取权限。修改后需重建工作空间，原 PVC 保留。"
  type         = "string"
  default      = "swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/ubuntu:22.04"
  mutable      = true
  order        = 3
  icon         = "/icon/docker.svg"
  validation {
    # POSIX class [:space:] is not supported by the browser-side JS regex
    # validation on the create form; \S is equivalent in Go and JavaScript.
    regex = "^\\S+$"
    error = "请填写非空镜像地址，不要包含空格，例如 harbor.magikcloud.cn/library/cpu-dev:v1。"
  }
}

data "coder_parameter" "home_disk_size" {
  name         = "home_disk_size"
  display_name = "Home disk size"
  order        = 4
  description  = "The size of the home disk in GB"
  default      = "100"
  type         = "number"
  icon         = "/emojis/1f4be.png"
  mutable      = true
  validation {
    min = 1
    max = 99999
    # Shrinking is forbidden because Kubernetes cannot shrink a PVC; a smaller
    # value would make every later build fail on the update-rollback attempt.
    monotonic = "increasing"
  }
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

resource "coder_agent" "main" {
  display_apps {
    vscode = false
  }
  os   = "linux"
  arch = "amd64"
  env = {
    WORKSPACE_SERVICE_HOST                             = local.peer_hosts[0]
    WORKSPACE_PEERS                                    = join(" ", local.peer_hosts)
    WORKSPACE_NODE_NAME                                = "main"
    HOME                                               = "/home/coder"
    CODER_AGENT_DEVCONTAINERS_ENABLE                   = "false"
    CODER_AGENT_DEVCONTAINERS_PROJECT_DISCOVERY_ENABLE = "false"
  }
  startup_script = <<-EOT
    set -e

    # Add any commands that should be executed at workspace startup (e.g install requirements, start a program, etc) here
  EOT

  # The following metadata blocks are optional. They are used to display
  # information about your workspace in the dashboard. You can remove them
  # if you don't want to display any information.
  # For basic resources, you can use the `coder stat` command.
  # If you need more control, you can write your own script.
  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Home Disk"
    key          = "3_home_disk"
    script       = "coder stat disk --path $${HOME}"
    interval     = 60
    timeout      = 1
  }

  metadata {
    display_name = "CPU Usage (Host)"
    key          = "4_cpu_usage_host"
    script       = "coder stat cpu --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Memory Usage (Host)"
    key          = "5_mem_usage_host"
    script       = "coder stat mem --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Load Average (Host)"
    key          = "6_load_host"
    # get load avg scaled by number of cores
    script   = <<EOT
      echo "`cat /proc/loadavg | awk '{ print $1 }'` `nproc`" | awk '{ printf "%0.2f", $1/$2 }'
    EOT
    interval = 60
    timeout  = 1
  }
}

resource "kubernetes_persistent_volume_claim_v1" "home" {
  metadata {
    name      = "coder-${data.coder_workspace.me.id}-home"
    namespace = "coder-workspaces"
    labels = {
      "app.kubernetes.io/name"     = "coder-pvc"
      "app.kubernetes.io/instance" = "coder-pvc-${data.coder_workspace.me.id}"
      "app.kubernetes.io/part-of"  = "coder"
      //Coder-specific labels.
      "com.coder.resource"       = "true"
      "com.coder.workspace.id"   = data.coder_workspace.me.id
      "com.coder.workspace.name" = data.coder_workspace.me.name
      "com.coder.user.id"        = data.coder_workspace_owner.me.id
      "com.coder.user.username"  = data.coder_workspace_owner.me.name
    }
    annotations = {
      "com.coder.user.email" = data.coder_workspace_owner.me.email
    }
  }
  wait_until_bound = false
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "ceph-fs"
    resources {
      requests = {
        storage = "${data.coder_parameter.home_disk_size.value}Gi"
      }
    }
  }
}

resource "kubernetes_deployment_v1" "main" {
  count = data.coder_workspace.me.start_count
  depends_on = [
    kubernetes_persistent_volume_claim_v1.home
  ]
  wait_for_rollout = false
  metadata {
    name      = "coder-${data.coder_workspace.me.id}"
    namespace = "coder-workspaces"
    labels = {
      "app.kubernetes.io/name"     = "coder-workspace"
      "app.kubernetes.io/instance" = "coder-workspace-${data.coder_workspace.me.id}"
      "app.kubernetes.io/part-of"  = "coder"
      "com.coder.resource"         = "true"
      "com.coder.workspace.id"     = data.coder_workspace.me.id
      "com.coder.workspace.name"   = data.coder_workspace.me.name
      "com.coder.user.id"          = data.coder_workspace_owner.me.id
      "com.coder.user.username"    = data.coder_workspace_owner.me.name
    }
    annotations = {
      "com.coder.user.email" = data.coder_workspace_owner.me.email
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        "app.kubernetes.io/name"     = "coder-workspace"
        "app.kubernetes.io/instance" = "coder-workspace-${data.coder_workspace.me.id}"
        "app.kubernetes.io/part-of"  = "coder"
        "com.coder.resource"         = "true"
        "com.coder.workspace.id"     = data.coder_workspace.me.id
        "com.coder.workspace.name"   = data.coder_workspace.me.name
        "com.coder.user.id"          = data.coder_workspace_owner.me.id
        "com.coder.user.username"    = data.coder_workspace_owner.me.name
      }
    }
    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"     = "coder-workspace"
          "app.kubernetes.io/instance" = "coder-workspace-${data.coder_workspace.me.id}"
          "app.kubernetes.io/part-of"  = "coder"
          "com.coder.resource"         = "true"
          "com.coder.workspace.id"     = data.coder_workspace.me.id
          "com.coder.workspace.name"   = data.coder_workspace.me.name
          "com.coder.user.id"          = data.coder_workspace_owner.me.id
          "com.coder.user.username"    = data.coder_workspace_owner.me.name
        }
      }
      spec {
        automount_service_account_token = false
        hostname                        = local.workspace_name
        host_network                    = false
        dns_policy                      = "ClusterFirst"
        node_selector                   = { "kubernetes.io/arch" = "amd64" }
        security_context {
          run_as_user     = 0
          fs_group        = 1000
          run_as_non_root = false
        }

        container {
          name              = "dev"
          image             = data.coder_parameter.dev_image.value
          image_pull_policy = "Always"
          command = [
            "sh", "-c",
            "sh -c \"$1\" || exit $?\nsh -c \"$2\" || exit $?\nexec runuser -u coder -- env HOME=/home/coder USER=coder LOGNAME=coder sh -c \"$3\"",
            "coder-workspace",
            file("${path.module}/scripts/bootstrap-tools.sh"),
            file("${path.module}/scripts/setup-coder-user.sh"),
            coder_agent.main.init_script,
          ]
          working_dir = "/home/coder"
          security_context {
            run_as_user = 0
            privileged  = false
          }
          env_from {
            config_map_ref {
              name = "coder-workspace-proxy"
            }
          }
          env_from {
            # Read-only OSS credentials used by the Codex extension preload
            # script. The Secret must exist in coder-workspaces before a
            # workspace using this template version is started.
            secret_ref {
              name = "coder-oss-pull"
            }
          }
          env {
            name  = "HOME"
            value = "/home/coder"
          }
          env {
            name  = "NVIDIA_VISIBLE_DEVICES"
            value = "void"
          }
          env {
            name  = "CODER_AGENT_DEVCONTAINERS_ENABLE"
            value = "false"
          }
          env {
            name  = "CODER_AGENT_DEVCONTAINERS_PROJECT_DISCOVERY_ENABLE"
            value = "false"
          }
          env {
            name  = "CODER_AGENT_TOKEN"
            value = coder_agent.main.token
          }
          resources {
            requests = { memory = "128Gi" }
            limits   = { memory = "128Gi" }
          }
          volume_mount {
            name       = "dshm"
            mount_path = "/dev/shm"
          }
          volume_mount {
            mount_path = "/home/coder"
            name       = "home"
            read_only  = false
          }
        }

        volume {
          name = "dshm"
          empty_dir {
            medium     = "Memory"
            size_limit = "20Gi"
          }
        }
        volume {
          name = "home"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.home.metadata.0.name
            read_only  = false
          }
        }

        affinity {
          // This affinity attempts to spread out all workspace pods evenly across
          // nodes.
          pod_anti_affinity {
            dynamic "required_during_scheduling_ignored_during_execution" {
              for_each = local.machine_count > 1 ? [1] : []
              content {
                topology_key = "kubernetes.io/hostname"
                label_selector {
                  match_labels = { "com.coder.workspace.id" = data.coder_workspace.me.id }
                }
              }
            }
            preferred_during_scheduling_ignored_during_execution {
              weight = 1
              pod_affinity_term {
                topology_key = "kubernetes.io/hostname"
                label_selector {
                  match_expressions {
                    key      = "app.kubernetes.io/name"
                    operator = "In"
                    values   = ["coder-workspace"]
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

resource "coder_metadata" "parameter_update" {
  count       = data.coder_workspace.me.start_count
  resource_id = kubernetes_deployment_v1.main[count.index].id

  item {
    key   = "coder.parameter_update"
    value = "recreate"
  }
}
