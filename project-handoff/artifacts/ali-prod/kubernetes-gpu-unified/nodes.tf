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

  workspace_name = lower(data.coder_workspace.me.name)
  owner_name     = lower(data.coder_workspace_owner.me.name)

  batch_prefix = replace(local.workspace_name, "/-[1-4]$/", "")
  member_names = local.batch_id == "" ? [local.workspace_name] : [for n in range(local.requested_count) : "${local.batch_prefix}-${n + 1}"]

  # Service names on clusters using RFC 1035 validation must start with a letter.
  labels        = { for name in toset(concat([local.workspace_name], local.member_names)) : name => "${can(regex("^[0-9]", name)) ? "n--" : ""}${name}--${local.owner_name}" }
  service_names = { for name, label in local.labels : name => length(label) <= 63 ? label : "${substr(label, 0, 46)}-${substr(sha256(label), 0, 16)}" }
  main_name     = local.service_names[local.workspace_name]
  node_names    = [for n in range(local.machine_count) : n == 0 ? local.main_name : (length(local.main_name) <= 59 ? "${local.main_name}--n${n}" : "${substr(local.main_name, 0, 42)}-${substr(sha256(local.main_name), 0, 16)}--n${n}")]
  peer_hosts    = local.batch_id != "" ? [for name in local.member_names : "${local.service_names[name]}.coder-workspaces.svc"] : [for name in local.node_names : "${name}.coder-workspaces.svc"]
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
