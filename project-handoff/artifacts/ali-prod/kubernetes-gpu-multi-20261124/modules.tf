module "cursor" {
  count       = data.coder_workspace.me.start_count
  source      = "registry.coder.com/coder/cursor/coder"
  version     = "1.4.1"
  agent_id    = coder_agent.node-0[0].id
  folder      = ""
  mcp         = ""
  open_recent = false
}

module "vscode-desktop" {
  count       = data.coder_workspace.me.start_count
  source      = "registry.coder.com/coder/vscode-desktop/coder"
  version     = "1.2.1"
  agent_id    = coder_agent.node-0[0].id
  folder      = ""
  open_recent = false
}

module "git-config" {
  count                 = data.coder_workspace.me.start_count
  source                = "registry.coder.com/coder/git-config/coder"
  version               = "1.0.33"
  agent_id              = coder_agent.node-0[0].id
  allow_email_change    = true
  allow_username_change = true
}
