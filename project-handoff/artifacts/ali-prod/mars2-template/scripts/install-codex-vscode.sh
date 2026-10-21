#!/bin/sh
set -eu

extension_dir="$HOME/.vscode-server/extensions"
cache_dir="$HOME/.cache/coder"
marker="$cache_dir/codex-vscode-extensions.version"
stage_dir="$cache_dir/vscode-extensions.staging"

# Bundle contents: openai.chatgpt + openai.codex-audio +
# ms-ceintl.vscode-language-pack-zh-hans, packaged with a valid extensions.json.
codex_ext_version="26.1007.21434"
oss_bucket="magik-velero-backup"
oss_object="vscode-exp/codex-vscode-extensions-${codex_ext_version}.tar.gz"
tar_sha256="6a4ec63b5fe4a1a627126f3de4656a5c3bc7c0a13af05ccd2c29e74a419f2f4a"

# Credentials come from the coder-oss-pull Secret via env_from. The key must
# stay read-only on this bucket; workspace users can read the environment.
: "${OSS_ACCESS_KEY_ID:?OSS_ACCESS_KEY_ID not set}"
: "${OSS_ACCESS_KEY_SECRET:?OSS_ACCESS_KEY_SECRET not set}"
: "${OSS_ENDPOINT:?OSS_ENDPOINT not set}"

if [ -f "$marker" ]; then
	if [ "$(cat "$marker" 2>/dev/null)" = "$codex_ext_version" ]; then
		echo "Codex VS Code extensions already installed."
		exit 0
	fi
	# A marker with a different version is an upgrade: fall through and reinstall.
elif ls "$extension_dir"/openai.chatgpt-*/package.json >/dev/null 2>&1; then
	# Workspaces created by earlier template versions installed the extensions
	# from the marketplace; trust the directories and only record the marker.
	echo "Codex VS Code extension already present; recording marker."
	mkdir -p "$cache_dir"
	printf '%s' "$codex_ext_version" >"$marker"
	exit 0
fi

command -v curl >/dev/null 2>&1 || {
	echo "Codex extension installation requires curl; check workspace startup dependencies." >&2
	exit 1
}

command -v tar >/dev/null 2>&1 || {
	echo "Codex extension installation requires tar." >&2
	exit 1
}
command -v openssl >/dev/null 2>&1 || {
	echo "Codex extension installation requires openssl." >&2
	exit 1
}

# OSS V1 header signature for GET /<bucket>/<object>. LC_ALL=C keeps the
# weekday and month names English as required by the HTTP date format.
date_hdr=$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S GMT')
signature=$(printf 'GET\n\n\n%s\n/%s/%s' "$date_hdr" "$oss_bucket" "$oss_object" |
	openssl dgst -sha1 -hmac "$OSS_ACCESS_KEY_SECRET" -binary | base64)

rm -rf "$stage_dir"
mkdir -p "$stage_dir" "$extension_dir"
download_dir=$(mktemp -d)
trap 'rm -rf "$download_dir" "$stage_dir"' EXIT

curl --fail --location --retry 2 --connect-timeout 15 --max-time 1800 \
	-H "Date: $date_hdr" \
	-H "Authorization: OSS ${OSS_ACCESS_KEY_ID}:${signature}" \
	"https://${oss_bucket}.${OSS_ENDPOINT}/${oss_object}" \
	-o "$download_dir/extensions.tar.gz"

echo "$tar_sha256  $download_dir/extensions.tar.gz" | sha256sum -c -

tar -xzf "$download_dir/extensions.tar.gz" -C "$stage_dir"

rm -rf "$extension_dir"/openai.chatgpt-* "$extension_dir"/openai.codex-audio-* \
	"$extension_dir"/ms-ceintl.vscode-language-pack-zh-hans-*
mv "$stage_dir"/openai.chatgpt-* "$extension_dir"/
mv "$stage_dir"/openai.codex-audio-* "$extension_dir"/
for language_pack in "$stage_dir"/ms-ceintl.vscode-language-pack-zh-hans-*; do
	if [ -d "$language_pack" ]; then
		mv "$language_pack" "$extension_dir"/
	fi
done
if [ ! -f "$extension_dir/extensions.json" ]; then
	cp "$stage_dir/extensions.json" "$extension_dir/extensions.json"
fi

printf '%s' "$codex_ext_version" >"$marker"
echo "Codex VS Code extensions installed."
