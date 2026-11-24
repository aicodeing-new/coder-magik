#!/bin/sh
set -eu

# Run before the Coder Agent, so all startup scripts see their dependencies.
packages=""
for pair in 'ssh:openssh-client' 'git:git' 'python3:python3' 'curl:curl' 'tar:tar' 'openssl:openssl' 'sha256sum:coreutils' 'base64:coreutils' 'bash:bash' 'sudo:sudo' 'visudo:sudo' 'runuser:util-linux' 'useradd:passwd' 'usermod:passwd' 'groupadd:passwd' 'getent:libc-bin' 'find:findutils'; do
	tool=${pair%%:*}
	package=${pair#*:}
	if ! command -v "$tool" >/dev/null 2>&1; then
		packages="$packages $package"
	fi
done
if [ ! -s /etc/ssl/certs/ca-certificates.crt ]; then
	packages="$packages ca-certificates"
fi
if [ -n "$packages" ]; then
	if ! command -v apt-get >/dev/null 2>&1; then
		echo "Missing workspace tools:$packages. Use a Debian/Ubuntu image with apt-get, or preinstall these tools." >&2
		exit 1
	fi
	if [ "$(id -u)" != 0 ]; then
		echo "Workspace tool bootstrap needs root for apt-get." >&2
		exit 1
	fi
	echo "Installing missing workspace tools:$packages"
	export DEBIAN_FRONTEND=noninteractive
	apt-get -o Acquire::Retries=3 -o DPkg::Lock::Timeout=300 update
	# Package names above are fixed tokens; intentional word splitting.
	# shellcheck disable=SC2086
	apt-get -o Acquire::Retries=3 -o DPkg::Lock::Timeout=300 install -y --no-install-recommends $packages
fi

echo "Workspace tools are ready."
