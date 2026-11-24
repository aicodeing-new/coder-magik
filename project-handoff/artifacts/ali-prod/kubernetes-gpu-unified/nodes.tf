data "coder_parameter" "machine_count" {
  name         = "machine_count"
  display_name = "机器数量"
  description  = "网页批量创建 1 至 4 个独立工作空间。选 2 并命名 aitest，将创建 aitest-1 和 aitest-2。每个空间单独启停，拥有独立 HOME PVC。"
  type         = "number"
  default      = "1"
  mutable      = false
  order        = 5
  validation {
    min = 1
    max = 4
  }
}


data "coder_parameter" "workspace_batch_id" {
  name         = "workspace_batch_id"
  display_name = "Workspace batch ID"
  description  = "Set by the workspace creation form for independently managed batch members."
  type         = "string"
  default      = ""
  mutable      = false
  styling      = jsonencode({ disabled = true })
  validation {
    regex = "^$|^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$"
    error = "Expected a batch UUID."
  }
}

locals {
  batch_id        = data.coder_parameter.workspace_batch_id.value
  requested_count = tonumber(data.coder_parameter.machine_count.value)
  machine_count   = local.batch_id == "" ? local.requested_count : 1
  owner_workspace = lower("${data.coder_workspace.me.name}--${data.coder_workspace_owner.me.name}")
  # Reserve space for the node prefix and keep long names collision-resistant.
  dns_key      = length(local.owner_workspace) <= 58 ? local.owner_workspace : "${substr(local.owner_workspace, 0, 41)}-${substr(sha256(local.owner_workspace), 0, 16)}"
  node_names   = [for n in range(local.machine_count) : "${n == 0 ? "ws" : "wn${n}"}-${local.dns_key}"]
  batch_prefix = replace(lower(data.coder_workspace.me.name), "/-[1-4]$/", "")
  batch_keys   = [for n in range(local.requested_count) : "${local.batch_prefix}-${n + 1}--${lower(data.coder_workspace_owner.me.name)}"]
  batch_hosts  = [for key in local.batch_keys : "ws-${length(key) <= 58 ? key : "${substr(key, 0, 41)}-${substr(sha256(key), 0, 16)}"}.coder-workspaces.svc"]
  peer_hosts   = local.batch_id != "" ? local.batch_hosts : [for name in local.node_names : "${name}.coder-workspaces.svc"]
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
