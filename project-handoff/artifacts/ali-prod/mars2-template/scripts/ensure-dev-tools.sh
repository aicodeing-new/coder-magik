#!/bin/sh
set -eu

missing_packages=""
for tool in curl git tar openssl bash; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		missing_packages="$missing_packages $tool"
	fi
done
if ! command -v sha256sum >/dev/null 2>&1; then
	missing_packages="$missing_packages coreutils"
fi
if [ ! -s /etc/ssl/certs/ca-certificates.crt ]; then
	missing_packages="$missing_packages ca-certificates"
fi

if [ -n "$missing_packages" ]; then
	if [ "$(id -u)" != 0 ] || ! command -v apt-get >/dev/null 2>&1; then
		echo "Development image is missing:$missing_packages. Install these packages in the image before using this template." >&2
		exit 1
	fi
	echo "Installing workspace startup dependencies:$missing_packages"
	install_packages() {
		# Package names are fixed above; splitting this list is intentional.
		# shellcheck disable=SC2086
		DEBIAN_FRONTEND=noninteractive apt-get -o Acquire::Retries=2 -o Acquire::http::Timeout=20 -o Acquire::https::Timeout=20 install -y --no-install-recommends $missing_packages
	}
	if ! install_packages; then
		DEBIAN_FRONTEND=noninteractive apt-get -o Acquire::Retries=2 -o Acquire::http::Timeout=20 -o Acquire::https::Timeout=20 update
		install_packages
	fi
fi

for tool in curl git tar openssl bash sha256sum; do
	command -v "$tool" >/dev/null 2>&1 || exit 1
done
proxy_url="${https_proxy:-${HTTPS_PROXY:-${http_proxy:-${HTTP_PROXY:-}}}}"
if [ -n "$proxy_url" ]; then
	git config --global http.proxy "$proxy_url"
fi

echo "Workspace startup dependencies and Git proxy are ready."
