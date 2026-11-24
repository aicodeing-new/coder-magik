data "coder_parameter" "machine_count" {
  name         = "machine_count"
  display_name = "机器数量"
  description  = "在同一集群的不同节点上申请机器。创建后固定，每台有独立 HOME PVC。"
  type         = "number"
  default      = "2"
  mutable      = false
  order        = 5
  validation {
    min = 2
    max = 4
  }
}

locals {
  node_keys  = toset([for n in range(tonumber(data.coder_parameter.machine_count.value)) : "node-${n}"])
  dns_base   = "ws-${lower(data.coder_workspace.me.name)}-${substr(replace(data.coder_workspace.me.id, "-", ""), 0, 12)}"
  peer_hosts = [for node in sort(tolist(local.node_keys)) : "${local.dns_base}-${node}.coder-workspaces.svc"]
}
