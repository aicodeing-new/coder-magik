data "coder_parameter" "machine_count" {
  name         = "machine_count"
  display_name = "机器数量"
  description  = "在同一集群的不同节点上申请机器。创建后固定，每台有独立 HOME PVC。"
  type         = "number"
  default      = "1"
  mutable      = false
  order        = 5
  validation {
    min = 1
    max = 4
  }
}


locals {
  machine_count   = tonumber(data.coder_parameter.machine_count.value)
  owner_workspace = lower("${data.coder_workspace.me.name}--${data.coder_workspace_owner.me.name}")
  # Reserve space for the node prefix and keep long names collision-resistant.
  dns_key    = length(local.owner_workspace) <= 58 ? local.owner_workspace : "${substr(local.owner_workspace, 0, 41)}-${substr(sha256(local.owner_workspace), 0, 16)}"
  node_names = [for n in range(local.machine_count) : "${n == 0 ? "ws" : "wn${n}"}-${local.dns_key}"]
  peer_hosts = [for name in local.node_names : "${name}.coder-workspaces.svc"]
}

resource "kubernetes_service_v1" "main_dns" {
  count = data.coder_workspace.me.start_count
  metadata {
    name      = local.node_names[0]
    namespace = "coder-workspaces"
  }
  spec {
    cluster_ip = "None"
    selector   = { "app.kubernetes.io/instance" = "coder-workspace-${data.coder_workspace.me.id}" }
  }
}
