resource "coder_agent" "node-2" {
  count = local.machine_count > 2 ? 1 : 0
  os    = "linux"
  arch  = "amd64"

  display_apps {
    vscode = true
  }

  env = {
    HOME                                               = "/home/coder"
    CODER_AGENT_DEVCONTAINERS_ENABLE                   = "false"
    CODER_AGENT_DEVCONTAINERS_PROJECT_DISCOVERY_ENABLE = "false"
    WORKSPACE_SERVICE_HOST                             = local.peer_hosts[2]
    WORKSPACE_NODE_NAME                                = "node-2"
    WORKSPACE_PEERS                                    = join(" ", local.peer_hosts)
  }

}


resource "kubernetes_persistent_volume_claim_v1" "node-2" {
  count = local.machine_count > 2 ? 1 : 0
  metadata {
    name      = "coder-${data.coder_workspace.me.id}-node-2-home"
    namespace = "coder-workspaces"
    labels = {
      "app.kubernetes.io/name"     = "coder-pvc"
      "app.kubernetes.io/instance" = "coder-pvc-${data.coder_workspace.me.id}-node-2"
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

resource "kubernetes_deployment_v1" "node-2" {
  count = local.machine_count > 2 && data.coder_workspace.me.start_count > 0 ? 1 : 0
  depends_on = [
    kubernetes_persistent_volume_claim_v1.node-2
  ]
  wait_for_rollout = false
  metadata {
    name      = "coder-${data.coder_workspace.me.id}-node-2"
    namespace = "coder-workspaces"
    labels = {
      "app.kubernetes.io/name"     = "coder-workspace"
      "app.kubernetes.io/instance" = "coder-${data.coder_workspace.me.id}-node-2"
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
        "app.kubernetes.io/instance" = "coder-${data.coder_workspace.me.id}-node-2"
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
          "app.kubernetes.io/instance" = "coder-${data.coder_workspace.me.id}-node-2"
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
        hostname                        = "${local.workspace_name}-node-2"
        host_network                    = false
        dns_policy                      = "ClusterFirst"
        runtime_class_name              = local.gpu_count > 0 ? (local.metax ? "metax" : "nvidia") : null
        node_selector = merge(
          { "kubernetes.io/arch" = "amd64" },
          local.gpu_count > 0 ? { (local.metax ? "metax-tech.com/gpu.installed" : "nvidia.com/gpu.present") = "true" } : {}
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
          command = [
            "sh", "-c",
            "sh -c \"$1\" || exit $?\nsh -c \"$2\" || exit $?\nexec runuser -u coder -- env HOME=/home/coder USER=coder LOGNAME=coder sh -c \"$3\"",
            "coder-workspace",
            file("${path.module}/scripts/bootstrap-tools.sh"),
            file("${path.module}/scripts/setup-coder-user.sh"),
            coder_agent.node-2[0].init_script,
          ]
          working_dir = "/home/coder"
          security_context {
            run_as_user = 0
            privileged  = true
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
            value = coder_agent.node-2[0].token
          }
          resources {
            requests = local.gpu_resources
            limits   = local.gpu_resources
          }
          volume_mount {
            name       = "dshm"
            mount_path = "/dev/shm"
          }
          dynamic "volume_mount" {
            for_each = !local.metax && local.gpu_count > 0 ? [1] : []
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
          name = "dshm"
          empty_dir {
            medium     = "Memory"
            size_limit = "20Gi"
          }
        }
        dynamic "volume" {
          for_each = !local.metax && local.gpu_count > 0 ? [1] : []
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
            claim_name = kubernetes_persistent_volume_claim_v1.node-2[0].metadata[0].name
            read_only  = false
          }
        }

        affinity {
          pod_anti_affinity {
            required_during_scheduling_ignored_during_execution {
              topology_key = "kubernetes.io/hostname"
              label_selector {
                match_labels = { "com.coder.workspace.id" = data.coder_workspace.me.id }
              }
            }
          }
        }

      }
    }
  }
}

resource "kubernetes_service_v1" "node-2" {
  count = local.machine_count > 2 && data.coder_workspace.me.start_count > 0 ? 1 : 0
  metadata {
    name      = local.node_names[2]
    namespace = "coder-workspaces"
  }
  spec {
    cluster_ip = "None"
    selector = {
      "com.coder.workspace.id"     = data.coder_workspace.me.id
      "app.kubernetes.io/instance" = "coder-${data.coder_workspace.me.id}-node-2"
    }
  }
}

resource "coder_script" "install_codex_vscode-node-2" {
  count              = local.machine_count > 2 ? 1 : 0
  agent_id           = coder_agent.node-2[0].id
  display_name       = "Install Codex VS Code extension"
  icon               = "/icon/openai.svg"
  run_on_start       = true
  start_blocks_login = false
  script             = file("${path.module}/scripts/install-codex-vscode.sh")
}

resource "coder_script" "configure_git_proxy-node-2" {
  count              = local.machine_count > 2 ? 1 : 0
  agent_id           = coder_agent.node-2[0].id
  display_name       = "Configure Git proxy"
  icon               = "/icon/git.svg"
  run_on_start       = true
  start_blocks_login = true
  script = replace(
    file("${path.module}/scripts/configure-git-proxy.sh"),
    "__CODER_SSH_PROXY_PYTHON__",
    file("${path.module}/scripts/ssh-http-proxy.py")
  )
}

resource "coder_metadata" "node-2" {
  count       = local.machine_count > 2 && data.coder_workspace.me.start_count > 0 ? 1 : 0
  resource_id = kubernetes_deployment_v1.node-2[0].id
  item {
    key   = "coder.parameter_update"
    value = "recreate"
  }
}
