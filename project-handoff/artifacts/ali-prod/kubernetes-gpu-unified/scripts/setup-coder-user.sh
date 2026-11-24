#!/bin/sh
set -eu

if [ "$(id -u)" != 0 ]; then
	echo "Workspace account setup must run as root." >&2
	exit 1
fi

if id coder >/dev/null 2>&1; then
	if [ "$(id -u coder)" = 0 ]; then
		echo "The coder account must have a non-root UID." >&2
		exit 1
	fi
	usermod --home /home/coder --shell /bin/bash coder
else
	if ! getent group 1000 >/dev/null 2>&1; then
		groupadd --gid 1000 coder
	fi
	# Use the PVC's existing group without renumbering image accounts.
	useradd --no-create-home --home-dir /home/coder --shell /bin/bash --gid 1000 coder
fi

for group in sudo video render; do
	if getent group "$group" >/dev/null 2>&1; then
		usermod --append --groups "$group" coder
	fi
done

mkdir -p /etc/sudoers.d
printf '%s\n' \
	'Defaults:coder env_keep += "http_proxy https_proxy no_proxy HTTP_PROXY HTTPS_PROXY NO_PROXY"' \
	'coder ALL=(ALL:ALL) NOPASSWD: ALL' >/etc/sudoers.d/coder-workspace
chmod 0440 /etc/sudoers.d/coder-workspace
visudo -cf /etc/sudoers.d/coder-workspace
# Explicit inclusion also supports images whose sudoers omits sudoers.d.
if ! grep -Eq '^[#@]includedir[[:space:]]+/etc/sudoers.d/?([[:space:]]|$)' /etc/sudoers; then
	printf '\n%s\n' '@include /etc/sudoers.d/coder-workspace' >>/etc/sudoers
fi

coder_uid=$(id -u coder)
coder_gid=$(id -g coder)
mkdir -p /home/coder
chown "$coder_uid:$coder_gid" /home/coder
# Migrate files written by earlier root agents, without following symlinks
# or touching separate mounts. Existing non-root ownership is preserved.
find /home/coder -xdev -uid 0 -exec chown -h "$coder_uid:$coder_gid" {} +

# Variables below must expand in the target user shell.
# shellcheck disable=SC2016
runuser -u coder -- env HOME=/home/coder USER=coder LOGNAME=coder sh -c '
  test "$(id -u)" != 0
  test "$HOME" = /home/coder
  test "$(getent passwd coder | cut -d: -f6)" = /home/coder
  test -w "$HOME"
  test "$(sudo -n -u root id -u)" = 0
  for name in http_proxy https_proxy no_proxy HTTP_PROXY HTTPS_PROXY NO_PROXY; do
    if value=$(printenv "$name"); then
      test "$(sudo -n printenv "$name")" = "$value"
    fi
  done
'
if [ -n "${CODER_WORKSPACE_PROMPT_NAME:-}" ]; then
	# Host-network Pods retain the node hostname. Change only Bash's prompt.
	cat >/etc/profile.d/coder-workspace-prompt.sh <<'PROMPT'
if [ -n "${BASH_VERSION:-}" ] && [ -n "${PS1:-}" ] && [ -n "${CODER_WORKSPACE_PROMPT_NAME:-}" ]; then
    case $PS1 in
        *'\h'*|*'\H'*) PS1=${PS1//\\h/$CODER_WORKSPACE_PROMPT_NAME}; PS1=${PS1//\\H/$CODER_WORKSPACE_PROMPT_NAME} ;;
    esac
fi
PROMPT
	# Expand HOME in the coder account's shell.
	# shellcheck disable=SC2016
	runuser -u coder -- env HOME=/home/coder sh -c '
		line="[ ! -r /etc/profile.d/coder-workspace-prompt.sh ] || . /etc/profile.d/coder-workspace-prompt.sh"
		grep -Fqx "$line" "$HOME/.bashrc" 2>/dev/null || printf "\n%s\n" "$line" >> "$HOME/.bashrc"
	'
fi
echo "Workspace account ready: coder, HOME=/home/coder, passwordless sudo verified."
