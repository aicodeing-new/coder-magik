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
  display_name = "GPU 集群"
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
    name  = "yunqiao (H200)"
    value = "yunqiao"
  }
}

data "coder_parameter" "gpu_count" {
  name         = "gpu_count"
  display_name = "GPU 数量"
  description  = "K8s 申请的 GPU 数量；0 不申请 GPU。修改后需重新构建工作空间。宿主机访问权限不提供 GPU 隔离。"
  type         = "number"
  default      = "8"
  mutable      = true
  order        = 2
  option {
    name  = "0 块（不申请 GPU）"
    value = "0"
  }
  option {
    name  = "1 块"
    value = "1"
  }
  option {
    name  = "2 块"
    value = "2"
  }
  option {
    name  = "3 块"
    value = "3"
  }
  option {
    name  = "4 块"
    value = "4"
  }
  option {
    name  = "5 块"
    value = "5"
  }
  option {
    name  = "6 块"
    value = "6"
  }
  option {
    name  = "7 块"
    value = "7"
  }
  option {
    name  = "8 块"
    value = "8"
  }
  validation {
    min = 0
    max = 8
  }
}

locals {
  gpu_count     = tonumber(data.coder_parameter.gpu_count.value)
  gpu_resources = local.gpu_count > 0 ? { "nvidia.com/gpu" = tostring(local.gpu_count) } : {}
}

variable "dev_image" {
  type        = string
  default     = "swr.cn-north-4.myhuaweicloud.com/pixiu-public/admins/example-base:ubuntu"
  description = "Development image with sh, bash and curl. Persist files under /home/coder."
}

data "coder_parameter" "dev_image" {
  name         = "dev_image"
  display_name = "开发镜像"
  description  = "填写完整镜像地址（tag 或 digest）。镜像需包含 sh、bash、curl 或 wget；原 ENTRYPOINT 会被替换。私有仓库需预先配置集群拉取权限。修改后需重建工作空间，原 PVC 保留。"
  type         = "string"
  default      = var.dev_image
  mutable      = true
  order        = 3
  icon         = "/icon/docker.svg"
  validation {
    regex = "^[^[:space:]]+$"
    error = "请填写非空镜像地址，不要包含空格，例如 harbor.magikcloud.cn/library/gpu-dev:v1。"
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
  mutable      = false
  validation {
    min = 1
    max = 99999
  }
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

resource "coder_agent" "main" {
  os   = "linux"
  arch = "amd64"
  env = {
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
        host_network                    = true
        dns_policy                      = "ClusterFirstWithHostNet"
        runtime_class_name              = local.gpu_count > 0 ? "nvidia" : null
        node_selector = merge(
          { "kubernetes.io/arch" = "amd64" },
          local.gpu_count > 0 ? { "nvidia.com/gpu.present" = "true" } : {}
        )
        security_context {
          run_as_user     = 0
          fs_group        = 1000
          run_as_non_root = false
        }

        container {
          name              = "dev"
          image             = data.coder_parameter.dev_image.value
          image_pull_policy = "Always"
          command           = ["sh", "-c", coder_agent.main.init_script]
          working_dir       = "/home/coder"
          security_context {
            run_as_user = 0
            privileged  = true
          }
          env_from {
            config_map_ref {
              name = "coder-workspace-proxy"
            }
          }
          env {
            name  = "HOME"
            value = "/home/coder"
          }
          dynamic "env" {
            for_each = local.gpu_count == 0 ? [1] : []
            content {
              name  = "NVIDIA_VISIBLE_DEVICES"
              value = "void"
            }
          }
          env {
            name  = "NVIDIA_DRIVER_CAPABILITIES"
            value = "compute,utility"
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
            requests = local.gpu_resources
            limits   = local.gpu_resources
          }
          volume_mount {
            name       = "host-docker"
            mount_path = "/var/run/docker.sock"
          }
          volume_mount {
            name       = "host-containerd"
            mount_path = "/run/containerd/containerd.sock"
          }
          volume_mount {
            name       = "dshm"
            mount_path = "/dev/shm"
          }
          dynamic "volume_mount" {
            for_each = local.gpu_count > 0 ? [1] : []
            content {
              name       = "nvidia-topologyd"
              mount_path = "/var/run/nvidia-topologyd"
              read_only  = true
            }
          }
          volume_mount {
            mount_path = "/home/coder"
            name       = "home"
            read_only  = false
          }
        }

        volume {
          name = "host-docker"
          host_path {
            path = "/run/docker.sock"
            type = "Socket"
          }
        }
        volume {
          name = "host-containerd"
          host_path {
            path = "/run/containerd/containerd.sock"
            type = "Socket"
          }
        }
        volume {
          name = "dshm"
          empty_dir {
            medium     = "Memory"
            size_limit = "20Gi"
          }
        }
        dynamic "volume" {
          for_each = local.gpu_count > 0 ? [1] : []
          content {
            name = "nvidia-topologyd"
            host_path {
              path = "/var/run/nvidia-topologyd"
              type = "Directory"
            }
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
