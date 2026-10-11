Yunqiao Coder DERP deployment through Envoy Gateway

This package prepares manifests only. Nothing has been applied to production.
Domain: yunqiao-derp.magikcloud.cn
Gateway: envoy-gateway-system/magik-gw, HTTPS listener https, TCP 443.
Gateway certificate currently covers *.magikcloud.cn; reuse it.
Internal Gateway Service IP: 10.251.106.156 (re-check if the Service is recreated).
DERP Pod: pinned to yunqiao-cpu-22, ordinary Pod networking, HTTP 8080.
State: independent 1Gi ceph-fs PVC. No GPU, host data mount, host network or extra RBAC.

Prerequisites
- Public DNS must point to the existing yunqiao Gateway public entrance, not ali-prod.
- Public TCP 443 must reach that Gateway. Do not insert an ali-prod tunnel or a CDN
  that cannot forward DERP/WebSocket upgrades.
- GPU Pods must reach 10.251.106.156:443 through the internal Kubernetes network.
- Build and push the supplied DERP image. It uses the exact Coder Tailscale fork
  dependency e42b84be7a30, pinned in go.mod/go.sum.
- Ensure coder-networking can pull the Harbor image; add an imagePullSecret if the
  Harbor project is private. Secrets from another namespace cannot be reused directly.
- DERP does not authenticate against Coder/Feishu accounts. verify-clients via a
  local tailscaled is incompatible with ordinary Coder agents. Use the existing
  company ingress/VPN source access policy if relay access must be restricted.

1. Build on a machine with Docker and upstream build dependency access
   cd to this extracted directory.
   docker build --platform linux/amd64 -t harbor.magikcloud.cn/library/derper:coder-e42b84b-amd64 .
   docker push harbor.magikcloud.cn/library/derper:coder-e42b84b-amd64
   For an offline builder, mirror golang:1.26.5-bookworm and
   gcr.io/distroless/static-debian12:nonroot into Harbor and change FROM lines.
   Only the resulting DERP image is needed on the target cluster.

2. Configure public DNS, then deploy the relay on yunqiao
   kubectl --kubeconfig=/mnt/d/Downloads/yunqiao-ops-admin.yaml apply -f 01-relay.yaml
   kubectl --kubeconfig=/mnt/d/Downloads/yunqiao-ops-admin.yaml -n coder-networking rollout status deployment/derp-yunqiao
   kubectl --kubeconfig=/mnt/d/Downloads/yunqiao-ops-admin.yaml -n coder-networking get httproute derp-yunqiao -o yaml
   kubectl --kubeconfig=/mnt/d/Downloads/yunqiao-ops-admin.yaml -n coder-networking get backendtrafficpolicy derp-yunqiao-upgrades -o yaml
   HTTPRoute Accepted and ResolvedRefs and policy Accepted must be True.

3. Test before changing Coder
   From a GPU workspace:
   curl --noproxy '*' --resolve yunqiao-derp.magikcloud.cn:443:10.251.106.156 https://yunqiao-derp.magikcloud.cn/derp/probe
   From an external client:
   curl https://yunqiao-derp.magikcloud.cn/derp/probe
   These must return HTTP 200. Then verify native DERP upgrade externally:
   curl --http1.1 --max-time 3 -i -H 'Connection: Upgrade' -H 'Upgrade: derp' https://yunqiao-derp.magikcloud.cn/derp
   Expect HTTP 101. A timeout after 101 is expected because curl does not speak DERP.
   A successful /probe alone does not prove that upgraded connections work.

4. Publish the workspace template changes
   Merge 04-workspace-template-snippet.tf into spec.template.spec of the existing
   workspace Kubernetes Deployment resource, not into the Terraform root.
   Append yunqiao-derp.magikcloud.cn to both NO_PROXY and no_proxy in yunqiao's
   coder-workspaces/coder-workspace-proxy ConfigMap. Preserve all existing entries.
   Publish the updated Coder template; update/rebuild the test workspace so its
   Pod gets the hostname override and new proxy settings. PVC data is retained.
   Alternatively use split DNS mapping this hostname to the internal Gateway IP.

5. Attach the relay to Coder on ali-prod, after Steps 2-4 pass
   kubectl --kubeconfig=/mnt/d/Downloads/ali-prod-kubeconfig-admin.yaml -n coder get deployment coder -o yaml > coder-before-derp.yaml
   Protect the backup locally; do not share it because Deployment env may be sensitive.
   kubectl --kubeconfig=/mnt/d/Downloads/ali-prod-kubeconfig-admin.yaml apply -f 02-coder-derp-map.yaml
   kubectl --kubeconfig=/mnt/d/Downloads/ali-prod-kubeconfig-admin.yaml -n coder patch deployment coder --type strategic --patch-file 03-coder-deployment-patch.yaml
   kubectl --kubeconfig=/mnt/d/Downloads/ali-prod-kubeconfig-admin.yaml -n coder rollout status deployment/coder
   This restarts the control-plane Pod; existing sessions may reconnect.
   Do not modify CODER_DERP_SERVER_RELAY_URL: it is for embedded relay replicas.

6. Validate the real connection
   On Windows use the configured Coder CLI and its existing login:
   coder ping --num 5 yzhang/yunqiao-amaranth-pelican-21
   coder netcheck
   Confirm Yunqiao Relay is in use and test latency, file transfer and reconnects.
   /probe, YAML validation and process health alone do not prove end-to-end routing.
   This remains a relayed connection; p2p=false is expected.

Transition and production routing
- The supplied patch keeps the existing ali-prod embedded relay during migration.
  Relay selection is automatic; retaining it does not guarantee all traffic avoids ali-prod.
- To guarantee relay traffic avoids ali-prod, first provision and verify suitable
  custom relays for ALL GPU clusters, clients and control-plane connections, then
  set CODER_DERP_SERVER_ENABLE=false. Do not disable it before those checks.
- Merely adding a public STUN service will not solve the GPU public UDP restriction.
  This relay deployment needs no public UDP/STUN port.
- Dashboard terminals and proxied web apps still use the control plane.
- Update gateway/controller configuration in its existing source of truth if it is
  managed by Helm/GitOps; avoid having manual changes overwritten.
- Keep the Gateway wildcard certificate renewed. No certificate is mounted in DERP.

Rollback attachment
   kubectl --kubeconfig=/mnt/d/Downloads/ali-prod-kubeconfig-admin.yaml -n coder set env deployment/coder CODER_DERP_SERVER_ENABLE=true CODER_DERP_CONFIG_PATH-
   Leave the harmless unused ConfigMap/volume until normal manifest cleanup.

Validation performed when preparing this package
- Compiled the pinned DERP dependency locally.
- Local HTTP /derp/probe returns 200; native DERP and WebSocket upgrades both return 101.
- YAML schema/client validation and Coder strategic patch server dry-run.
- No image was pushed and no production resources were deployed.

Existing Gateway issue observed
Gateway-level Programmed=False reports more than 16 assigned addresses (131);
the HTTPS listener itself reports Programmed=True. This pre-existing status issue
is not fixed by these manifests. Verify actual route and upgrade behavior before
attaching the relay; no shared Gateway configuration was changed.
