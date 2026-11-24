module "cursor" {
  count       = data.coder_workspace.me.start_count
  source      = "registry.coder.com/coder/cursor/coder"
  version     = "1.4.1"
  agent_id    = coder_agent.main.id
  folder      = ""
  mcp         = ""
  open_recent = false
}

module "vscode-desktop" {
  count       = data.coder_workspace.me.start_count
  source      = "registry.coder.com/coder/vscode-desktop/coder"
  version     = "1.2.1"
  agent_id    = coder_agent.main.id
  folder      = ""
  open_recent = false
}

module "git-config" {
  count                 = data.coder_workspace.me.start_count
  source                = "registry.coder.com/coder/git-config/coder"
  version               = "1.0.33"
  agent_id              = coder_agent.main.id
  allow_email_change    = true
  allow_username_change = true
}

resource "coder_script" "install_codex_vscode" {
  agent_id           = coder_agent.main.id
  display_name       = "Install Codex VS Code extension"
  icon               = "/icon/openai.svg"
  run_on_start       = true
  start_blocks_login = false
  script             = file("${path.module}/scripts/install-codex-vscode.sh")
}

resource "coder_script" "configure_git_proxy" {
  agent_id           = coder_agent.main.id
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
