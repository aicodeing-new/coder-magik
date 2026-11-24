terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "2.19.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"
    }
  }
}

provider "coder" {
}

provider "kubernetes" {
  config_path    = "/mnt/secrets/kube/config"
  config_context = data.coder_parameter.cluster.value
}

data "coder_parameter" "cluster" {
  name         = "cluster"
  display_name = "GPU 集群"
  order        = 1
  description  = "创建后不可更改，PVC 保留在所选集群。"
  type         = "string"
  default      = "beast03"
  mutable      = false
  option {
    name  = "beast01"
    value = "beast01"
  }
  option {
    name  = "yunqiao (H200)"
    value = "yunqiao"
  }
  option {
    name  = "beast03 (NVIDIA B30Z)"
    value = "beast03"
  }
}

data "coder_parameter" "gpu_count" {
  name         = "gpu_count"
  display_name = "GPU 数量"
  description  = "K8s 申请的 GPU 数量；0 不申请 GPU。修改后需重新构建工作空间。宿主机访问权限不提供 GPU 隔离。"
  type         = "number"
  default      = "1"
  mutable      = true
  order        = 2
  option {
    name  = "0 块（不申请 GPU）"
    value = "0"
  }
  option {
    name  = "1 块"
    value = "1"
  }
  option {
    name  = "2 块"
    value = "2"
  }
  option {
    name  = "3 块"
    value = "3"
  }
  option {
    name  = "4 块"
    value = "4"
  }
  option {
    name  = "5 块"
    value = "5"
  }
  option {
    name  = "6 块"
    value = "6"
  }
  option {
    name  = "7 块"
    value = "7"
  }
  option {
    name  = "8 块"
    value = "8"
  }
  validation {
    min = 0
    max = 8
  }
}

locals {
  gpu_count     = tonumber(data.coder_parameter.gpu_count.value)
  gpu_resources = local.gpu_count > 0 ? { "nvidia.com/gpu" = tostring(local.gpu_count) } : {}
}

variable "dev_image" {
  type        = string
  default     = "harbor-yunqiao.magikcloud.cn/vllm-magik/vllm-release:2026-09-01-13-28-feature-hy4-preview-support-11067008eb-ihc-concat-02206bce0f"
  description = "Development image with sh, bash and curl. Persist files under /home/coder."
}

data "coder_parameter" "dev_image" {
  name         = "dev_image"
  display_name = "开发镜像"
  description  = "填写完整镜像地址（tag 或 digest）。镜像需包含 sh、bash、curl 或 wget；原 ENTRYPOINT 会被替换。私有仓库需预先配置集群拉取权限。修改后需重建工作空间，原 PVC 保留。"
  type         = "string"
  default      = var.dev_image
  mutable      = true
  order        = 3
  icon         = "/icon/docker.svg"
  validation {
    # POSIX class [:space:] is not supported by the browser-side JS regex
    # validation on the create form; \S is equivalent in Go and JavaScript.
    regex = "^\\S+$"
    error = "请填写非空镜像地址，不要包含空格，例如 harbor.magikcloud.cn/library/gpu-dev:v1。"
  }
}

data "coder_parameter" "home_disk_size" {
  name         = "home_disk_size"
  display_name = "Home disk size"
  order        = 4
  description  = "The size of the home disk in GB"
  default      = "100"
  type         = "number"
  icon         = "/emojis/1f4be.png"
  mutable      = true
  validation {
    min = 1
    max = 99999
    # Shrinking is forbidden because Kubernetes cannot shrink a PVC; a smaller
    # value would make every later build fail on the update-rollback attempt.
    monotonic = "increasing"
  }
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}
