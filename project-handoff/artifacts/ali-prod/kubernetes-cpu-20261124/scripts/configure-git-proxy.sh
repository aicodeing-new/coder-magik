#!/bin/sh
set -eu

# Values are injected by the cluster's coder-workspace-proxy ConfigMap.
# Git's http.proxy applies to HTTP and HTTPS; no_proxy remains inherited.
proxy=${https_proxy:-${HTTPS_PROXY:-${http_proxy:-${HTTP_PROXY:-}}}}
if [ -z "$proxy" ]; then
	echo "Git proxy configuration requires HTTPS_PROXY or HTTP_PROXY." >&2
	exit 1
fi
command -v git >/dev/null 2>&1 || {
	echo "The development image must contain git." >&2
	exit 1
}
command -v python3 >/dev/null 2>&1 || {
	echo "GitHub SSH proxy configuration requires python3 in the development image." >&2
	exit 1
}
command -v ssh >/dev/null 2>&1 || {
	echo "GitHub SSH access requires an OpenSSH client in the development image." >&2
	exit 1
}

# Git identity configuration may write ~/.gitconfig at the same time.
attempt=1
while ! git config --global --replace-all http.proxy "$proxy"; do
	if [ "$attempt" -ge 5 ]; then
		echo "Could not configure Git proxy after 5 attempts." >&2
		exit 1
	fi
	attempt=$((attempt + 1))
	sleep 1
done
echo "Git HTTP/HTTPS proxy configured from workspace environment."

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
helper_tmp=$(mktemp "$HOME/.ssh/coder-http-connect.XXXXXX")
trap 'rm -f "$helper_tmp"' EXIT
cat >"$helper_tmp" <<'CODER_SSH_PROXY_PYTHON_EOF'
__CODER_SSH_PROXY_PYTHON__
CODER_SSH_PROXY_PYTHON_EOF
chmod 600 "$helper_tmp"
mv "$helper_tmp" "$HOME/.ssh/coder-http-connect.py"

python3 - <<'CODER_SSH_CONFIG_PYTHON_EOF'
import os
import pwd
import re
from pathlib import Path

ssh_dir = Path(os.environ['HOME']) / '.ssh'
fragment = ssh_dir / 'coder-github-proxy.conf'
helper = ssh_dir / 'coder-http-connect.py'
fragment.write_text(
    'Host github.com ssh.github.com\n'
    '    HostName ssh.github.com\n'
    '    Port 443\n'
    '    User git\n'
    f'    ProxyCommand python3 "{helper.as_posix()}" %h %p\n', encoding='utf-8'
)
fragment.chmod(0o600)
include = f'Include "{fragment.as_posix()}"'
# OpenSSH resolves ~/.ssh from passwd, not the overridden HOME environment.
# Keep helper/config fragments on the PVC, and include them from both homes.
login_ssh_dir = Path(pwd.getpwuid(os.getuid()).pw_dir) / '.ssh'
for config_dir in {ssh_dir, login_ssh_dir}:
    config_dir.mkdir(parents=True, exist_ok=True)
    config_dir.chmod(0o700)
    config = config_dir / 'config'
    original = config.read_text(encoding='utf-8') if config.exists() else ''
    # Keep user settings, with our GitHub-specific include before broad Host rules.
    cleaned = re.sub(
        r'^# BEGIN CODER GITHUB PROXY\n.*?^# END CODER GITHUB PROXY\n',
        '', original, flags=re.MULTILINE | re.DOTALL
    )
    updated = '# BEGIN CODER GITHUB PROXY\n' + include + '\nHost *\n# END CODER GITHUB PROXY\n' + cleaned
    if original != updated:
        temporary = config_dir / 'config.coder-tmp'
        temporary.write_text(updated, encoding='utf-8')
        temporary.chmod(0o600)
        temporary.replace(config)
CODER_SSH_CONFIG_PYTHON_EOF
echo "GitHub SSH proxy configured through ssh.github.com:443."
