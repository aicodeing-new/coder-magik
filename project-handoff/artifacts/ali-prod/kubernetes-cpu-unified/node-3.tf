resource "coder_agent" "node-3" {
  count = local.machine_count > 3 ? 1 : 0
  os    = "linux"
  arch  = "amd64"

  display_apps {
    vscode = true
  }

  env = {
    HOME                                               = "/home/coder"
    CODER_AGENT_DEVCONTAINERS_ENABLE                   = "false"
    CODER_AGENT_DEVCONTAINERS_PROJECT_DISCOVERY_ENABLE = "false"
    WORKSPACE_SERVICE_HOST                             = local.peer_hosts[3]
    WORKSPACE_NODE_NAME                                = "node-3"
    WORKSPACE_PEERS                                    = join(" ", local.peer_hosts)
  }

}

resource "kubernetes_persistent_volume_claim_v1" "node-3" {
  count = local.machine_count > 3 ? 1 : 0
  metadata {
    name      = "coder-${data.coder_workspace.me.id}-node-3-home"
    namespace = "coder-workspaces"
    labels = {
      "app.kubernetes.io/name"     = "coder-pvc"
      "app.kubernetes.io/instance" = "coder-pvc-${data.coder_workspace.me.id}-node-3"
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

resource "kubernetes_deployment_v1" "node-3" {
  count = local.machine_count > 3 && data.coder_workspace.me.start_count > 0 ? 1 : 0
  depends_on = [
    kubernetes_persistent_volume_claim_v1.node-3
  ]
  wait_for_rollout = false
  metadata {
    name      = "coder-${data.coder_workspace.me.id}-node-3"
    namespace = "coder-workspaces"
    labels = {
      "app.kubernetes.io/name"     = "coder-workspace"
      "app.kubernetes.io/instance" = "coder-${data.coder_workspace.me.id}-node-3"
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
        "app.kubernetes.io/instance" = "coder-${data.coder_workspace.me.id}-node-3"
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
          "app.kubernetes.io/instance" = "coder-${data.coder_workspace.me.id}-node-3"
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
        hostname                        = "${local.workspace_name}-node-3"
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
            coder_agent.node-3[0].init_script,
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
            value = coder_agent.node-3[0].token
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
            claim_name = kubernetes_persistent_volume_claim_v1.node-3[0].metadata[0].name
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

resource "kubernetes_service_v1" "node-3" {
  count = local.machine_count > 3 && data.coder_workspace.me.start_count > 0 ? 1 : 0
  metadata {
    name      = local.node_names[3]
    namespace = "coder-workspaces"
  }
  spec {
    cluster_ip = "None"
    selector = {
      "com.coder.workspace.id"     = data.coder_workspace.me.id
      "app.kubernetes.io/instance" = "coder-${data.coder_workspace.me.id}-node-3"
    }
  }
}

resource "coder_script" "install_codex_vscode-node-3" {
  count              = local.machine_count > 3 ? 1 : 0
  agent_id           = coder_agent.node-3[0].id
  display_name       = "Install Codex VS Code extension"
  icon               = "/icon/openai.svg"
  run_on_start       = true
  start_blocks_login = false
  script             = file("${path.module}/scripts/install-codex-vscode.sh")
}

resource "coder_script" "configure_git_proxy-node-3" {
  count              = local.machine_count > 3 ? 1 : 0
  agent_id           = coder_agent.node-3[0].id
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

resource "coder_metadata" "node-3" {
  count       = local.machine_count > 3 && data.coder_workspace.me.start_count > 0 ? 1 : 0
  resource_id = kubernetes_deployment_v1.node-3[0].id
  item {
    key   = "coder.parameter_update"
    value = "recreate"
  }
}
