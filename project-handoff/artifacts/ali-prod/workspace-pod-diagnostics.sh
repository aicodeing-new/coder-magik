#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 || ! $2 =~ ^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$ ]]; then
	printf 'Usage: %s KUBECONFIG WORKSPACE_UUID\n' "$0" >&2
	exit 2
fi

cluster=(kubectl --kubeconfig "$1" --namespace coder-workspaces --request-timeout=10s)
selector="com.coder.workspace.id=$2"
"${cluster[@]}" get deployment,pod,pvc -l "$selector" -o wide
names=$("${cluster[@]}" get deployment,replicaset,pod,pvc -l "$selector" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
while IFS= read -r name; do
	[[ -n $name ]] || continue
	events=$("${cluster[@]}" get events --field-selector "involvedObject.name=$name,type=Warning" --sort-by=.lastTimestamp --no-headers)
	if [[ -n $events ]]; then
		printf '\n%s\n%s\n' "$name" "$events"
	fi
done <<<"$names"
