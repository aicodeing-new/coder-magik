#!/bin/sh
set -eu

extension_dir="$HOME/.vscode-server/extensions"
installer_dir="$HOME/.cache/coder/vscode-extension-installer"
installer=""

for candidate in \
	"$HOME"/.vscode-server/cli/servers/Stable-*/server/bin/code-server \
	"$HOME"/.vscode-server/bin/*/bin/code-server \
	"$installer_dir/bin/code-server"; do
	if [ -x "$candidate" ]; then
		installer="$candidate"
		break
	fi
done

if [ -z "$installer" ]; then
	command -v tar >/dev/null 2>&1 || {
		echo "Codex extension installation requires tar." >&2
		exit 1
	}
	download_dir=$(mktemp -d)
	trap 'rm -rf "$download_dir"' EXIT
	download_url="https://update.code.visualstudio.com/latest/server-linux-x64/stable"
	if command -v curl >/dev/null 2>&1; then
		curl --fail --location --retry 2 --connect-timeout 15 --max-time 180 \
			"$download_url" -o "$download_dir/server.tar.gz"
	else
		wget --timeout=30 --tries=3 "$download_url" -O "$download_dir/server.tar.gz"
	fi
	mkdir "$download_dir/server"
	tar -xzf "$download_dir/server.tar.gz" -C "$download_dir/server" --strip-components=1
	mkdir -p "$(dirname "$installer_dir")"
	mv "$download_dir/server" "$installer_dir"
	installer="$installer_dir/bin/code-server"
fi

mkdir -p "$extension_dir"
if "$installer" --extensions-dir "$extension_dir" --list-extensions | grep -Fqx 'openai.chatgpt'; then
	echo "Codex VS Code extension is already installed."
	exit 0
fi

"$installer" --extensions-dir "$extension_dir" --install-extension openai.chatgpt
