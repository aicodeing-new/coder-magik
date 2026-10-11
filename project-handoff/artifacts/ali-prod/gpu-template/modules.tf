module "vscode-desktop" {
  count       = data.coder_workspace.me.start_count
  source      = "registry.coder.com/coder/vscode-desktop/coder"
  version     = "1.2.1"
  agent_id    = coder_agent.main.id
  folder      = ""
  open_recent = false
}


variable "openai_api_key" {
  description = "OpenAI API key for Codex CLI."
  type        = string
  sensitive   = true
  default     = ""
}
module "codex" {
  count                  = data.coder_workspace.me.start_count
  source                 = "registry.coder.com/coder-labs/codex/coder"
  version                = "5.3.0"
  agent_id               = coder_agent.main.id
  base_config_toml       = ""
  codex_version          = "latest"
  enable_ai_gateway      = false
  icon                   = "/icon/openai.svg"
  install_codex          = true
  mcp                    = ""
  model_reasoning_effort = ""
  openai_api_key         = var.openai_api_key
  post_install_script    = null
  pre_install_script     = null
  workdir                = null
}

resource "coder_script" "install_codex_vscode" {
  agent_id           = coder_agent.main.id
  display_name       = "Install Codex VS Code extension"
  icon               = "/icon/openai.svg"
  run_on_start       = true
  start_blocks_login = false
  script             = file("${path.module}/scripts/install-codex-vscode.sh")
}
