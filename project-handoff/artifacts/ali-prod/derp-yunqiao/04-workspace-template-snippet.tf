# Insert inside kubernetes_deployment workspace: spec.template.spec.
# Scope the private DNS override to yunqiao; other clusters use public DNS.
dynamic "host_aliases" {
  for_each = data.coder_parameter.cluster.value == "yunqiao" ? [1] : []
  content {
    ip        = "10.251.106.156"
    hostnames = ["yunqiao-derp.magikcloud.cn"]
  }
}

# Additionally append yunqiao-derp.magikcloud.cn to BOTH NO_PROXY and no_proxy
# in yunqiao's coder-workspaces/coder-workspace-proxy ConfigMap, preserving
# every existing entry. Rebuild existing workspaces after publishing template.
