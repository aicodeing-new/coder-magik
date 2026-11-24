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
  machine_count = tonumber(data.coder_parameter.machine_count.value)

  workspace_name = lower(data.coder_workspace.me.name)
  owner_name     = lower(data.coder_workspace_owner.me.name)
  member_names   = [local.workspace_name]

  # Service names on clusters using RFC 1035 validation must start with a letter.
  labels        = { for name in toset(concat([local.workspace_name], local.member_names)) : name => "${can(regex("^[0-9]", name)) ? "n--" : ""}${name}--${local.owner_name}" }
  service_names = { for name, label in local.labels : name => length(label) <= 63 ? label : "${substr(label, 0, 46)}-${substr(sha256(label), 0, 16)}" }
  main_name     = local.service_names[local.workspace_name]
  node_names    = [for n in range(local.machine_count) : n == 0 ? local.main_name : (length(local.main_name) <= 59 ? "${local.main_name}--n${n}" : "${substr(local.main_name, 0, 42)}-${substr(sha256(local.main_name), 0, 16)}--n${n}")]
  peer_hosts    = [for name in local.node_names : "${name}.coder-workspaces.svc"]
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
