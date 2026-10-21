#!/usr/bin/env python3
"""Create database and remote-cluster Secrets without writing credentials to disk."""
import base64
import getpass
import json
import os
from pathlib import Path
import subprocess
import time
from urllib.parse import quote, urlencode

import yaml

ROOT = Path(__file__).resolve().parent
ALI = "/mnt/d/Downloads/ali-prod-kubeconfig-admin.yaml"
GPU_CLUSTERS = {
    "beast01": "/mnt/d/Downloads/beast01-apiserver.yaml",
    "yunqiao": "/mnt/d/Downloads/yunqiao-ops-admin.yaml",
    "mars2": "/mnt/d/Downloads/mars2-apiserver-admin.yaml",
}


def kubectl(config, *args, payload=None):
    result = subprocess.run(
        ["kubectl", "--kubeconfig", config, *args, "--request-timeout=15s"],
        input=payload, text=True, capture_output=True, check=True, timeout=25,
    )
    return result.stdout


def apply_secret(name, string_data):
    body = {
        "apiVersion": "v1", "kind": "Secret", "type": "Opaque",
        "metadata": {"name": name, "namespace": "coder"},
        "stringData": string_data,
    }
    kubectl(ALI, "apply", "--server-side", "--field-manager=coder-bootstrap",
            "-f", "-", payload=json.dumps(body))
    print(f"Configured Secret coder/{name}")


def main():
    password = os.environ.get("CODER_DB_PASSWORD") or getpass.getpass("RDS password: ")
    config = {
        "apiVersion": "v1", "kind": "Config",
        "clusters": [], "users": [], "contexts": [],
        "current-context": "beast01",
    }
    for cluster_name, gpu_config in GPU_CLUSTERS.items():
        kubectl(gpu_config, "apply", "--server-side", "-f",
                str(ROOT / f"{cluster_name}-rbac.yaml"))
        kubectl(gpu_config, "apply", "--server-side", "-f",
                str(ROOT / f"{cluster_name}-proxy.yaml"))
        token_data = None
        for _ in range(15):
            secret = json.loads(kubectl(gpu_config, "get", "secret", "coder-provisioner-token",
                                        "-n", "coder-workspaces", "-o", "json"))
            if secret.get("data", {}).get("token"):
                token_data = secret["data"]
                break
            time.sleep(1)
        if token_data is None:
            raise RuntimeError(f"ServiceAccount token was not populated: {cluster_name}")
        source = json.loads(kubectl(gpu_config, "config", "view", "--raw", "--flatten",
                                    "--minify", "-o", "json"))
        user_name = f"coder-{cluster_name}"
        config["clusters"].append({
            "name": cluster_name, "cluster": source["clusters"][0]["cluster"],
        })
        config["users"].append({"name": user_name, "user": {
            "token": base64.b64decode(token_data["token"]).decode(),
        }})
        config["contexts"].append({"name": cluster_name, "context": {
            "cluster": cluster_name, "user": user_name, "namespace": "coder-workspaces",
        }})
    apply_secret("coder-gpu-kubeconfig", {"config": yaml.safe_dump(config)})
    query = urlencode({"sslmode": "disable", "TimeZone": "Asia/Shanghai"})
    url = (f"postgresql://magik:{quote(password, safe='')}@"
           f"pgm-uf6ms6ff0v0ptdun.rwlb.rds.aliyuncs.com:5432/coder?{query}")
    apply_secret("coder-db-url", {"url": url})


if __name__ == "__main__":
    main()
