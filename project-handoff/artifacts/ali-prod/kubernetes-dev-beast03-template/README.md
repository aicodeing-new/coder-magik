# Kubernetes GPU 开发工作空间

这个模板在 Kubernetes 集群中创建可持久化的远程开发工作空间，适合 GPU 开发、模型调试和日常代码开发。支持选择 beast01 或 yunqiao 集群，配置 GPU 数量和开发镜像，并通过 VS Code Desktop 或 Cursor 连接。

工作空间提供持久化的用户目录、宿主机数据目录挂载、网络代理、Git 用户配置，以及 VS Code 的 Codex 扩展预装。

容器启动时会先检查所需工具，在启动 Coder Agent 之前用 APT 安装缺失的 OpenSSH 客户端、Git、Python 3、curl、tar、OpenSSL、coreutils、bash 和 CA 证书。默认镜像使用 root 运行；自动补齐依赖要求 Debian/Ubuntu 镜像、可用的软件源和代理网络。工具已存在时跳过对应安装。

## 创建工作空间

1. 选择集群。集群在创建后不可修改，需要使用另一个集群时请新建工作空间。
2. 选择 GPU 数量。默认申请 **8 张 GPU**，请按实际需要调整；选择 `0` 时不申请 GPU 资源。
3. 确认开发镜像。可以使用默认 vLLM 镜像，也可以填写自己的完整镜像地址。
4. 设置用户目录容量，并按需填写 Git 提交用户名和邮箱。
5. 启动后，通过工作空间页面中的 VS Code Desktop 或 Cursor 入口连接。

## 可配置参数

| 参数 | 默认值 | 说明 |
|---|---|---|
| GPU 集群（`cluster`） | `beast01` | 可选 `beast01`、`yunqiao`（H200）；创建后不可修改 |
| GPU 数量（`gpu_count`） | `8` | 可选 0 至 8；修改后需要重新构建工作空间 |
| 开发镜像（`dev_image`） | 下方的 vLLM 镜像 | 支持 tag 或 digest；修改后需要重新构建，HOME PVC 保留 |
| 用户目录容量（`home_disk_size`） | `100` GiB | 范围 1 至 99999 GiB；可增加，不可缩小 |
| Git 用户名（`username`） | 空 | 留空时使用 Coder 用户的完整姓名 |
| Git 邮箱（`user_email`） | 空 | 留空时使用 Coder 用户邮箱 |

默认开发镜像：

```text
harbor-yunqiao.magikcloud.cn/vllm-magik/vllm-release:2026-09-01-13-28-feature-hy4-preview-support-11067008eb-ihc-concat-02206bce0f
```

镜像的原始入口命令会被 Coder Agent 启动命令替换。使用默认镜像不会自动启动 vLLM 服务，需要在工作空间中自行运行。

## 开发工具

- **VS Code Desktop**：提供本地 VS Code 连接工作空间的入口。
- **Cursor**：提供 Cursor 连接工作空间的入口。
- **Git**：配置提交用户名、邮箱，以及 HTTP/HTTPS 仓库访问代理。
- **VS Code Codex 扩展**：启动时从私有 OSS 下载并预装扩展包，其中包含 Codex 扩展、音频扩展和简体中文语言包。

模板不安装 Codex CLI，也不要求填写 OpenAI API Key。Codex 扩展的登录和使用在 VS Code 中完成。

模板不挂载宿主机 Docker 或 containerd socket，也不安装 Docker 客户端。基础镜像自带的 Docker 客户端不由模板卸载。

扩展安装在后台执行，不阻塞登录。首次进入工作空间时若扩展尚未出现，请等待安装完成并重新连接 VS Code；安装失败时可检查工作空间中的安装脚本日志。

## 数据与存储

| 容器路径 | 存储来源 | 用途与行为 |
|---|---|---|
| `/home/coder` | `ceph-fs` StorageClass 创建的 PVC | HOME 和默认工作目录；在工作空间停止、重启后保留，支持扩容 |
| `/data-store` | 当前宿主机的 `/data-store` | 所有此模板创建的工作空间容器均以读写方式挂载，可访问该节点上的数据 |
| `/dev/shm` | 内存型临时卷，上限 20Gi | 提供共享内存；随 Pod 销毁，不用于持久化数据 |

建议将个人代码、配置和开发文件放在 `/home/coder`，将宿主机已有数据或共享数据放在 `/data-store`。

`/data-store` 使用 hostPath，内容取决于实际调度节点。若各节点没有共享同一套底层存储，工作空间重启并调度到其他节点后，看到的数据可能不同。它不属于 HOME PVC，也不由模板负责迁移或扩容。

## 网络与 Git 代理

工作空间使用宿主机网络，并从所在集群的 `coder-workspace-proxy` ConfigMap 注入 `HTTP_PROXY`、`HTTPS_PROXY`、`NO_PROXY` 及对应小写变量。

每次启动时，Git 代理脚本优先读取 HTTPS 代理，未配置时使用 HTTP 代理，并配置两种访问方式：

- **GitHub SSH 仓库**：仅对 `github.com` 和 `ssh.github.com` 配置 SSH `ProxyCommand`，通过现有代理建立 HTTP CONNECT 隧道，连接 GitHub 的 `ssh.github.com:443`。流量仍然是 SSH 协议，无需将仓库改为 HTTPS。
- **HTTP/HTTPS 仓库**：写入 Git 全局 `http.proxy`；`NO_PROXY` / `no_proxy` 用于排除需要直连的地址。

GitHub 仓库可继续使用常见的 SSH 地址：

```bash
git clone git@github.com:组织名/仓库名.git
```

SSH 代理脚本和配置片段保存在 HOME PVC 的 `/home/coder/.ssh` 中。启动时同时在环境变量 HOME 目录和系统用户的 home 目录写入 Include，确保 root 用户的 OpenSSH 从 `/root/.ssh/config` 也能加载配置。配置保留其他 SSH 设置，不生成、上传或替换用户私钥。需要自行配置有仓库权限的 SSH 密钥，或使用 Coder 管理的 Git SSH 密钥 / 已配置的 SSH Agent。

可在终端检查 Git 代理：

```bash
git config --global --get http.proxy
```

可检查 SSH 配置及认证连通性：

```bash
ssh -G github.com | grep -E '^(hostname|port|proxycommand) '
ssh -T git@github.com
```

GitHub 成功认证时会提示已认证但不提供 Shell，并可能返回非零退出码。首次连接应核对 GitHub 公布的主机指纹；模板保留 SSH 的默认主机密钥校验。其他 SSH 主机不自动走此代理，显式在命令或 URL 中指定端口也会覆盖配置端口。

代理需要允许 CONNECT 到 `ssh.github.com:443`。GitHub 的 SSH 443 入口及配置方法见 [GitHub 官方文档](https://docs.github.com/en/authentication/troubleshooting-ssh/using-ssh-over-the-https-port)。

## GPU 与运行环境

GPU 数量大于 0 时，模板申请对应数量的 `nvidia.com/gpu` 资源，使用 `nvidia` RuntimeClass，并选择具有 GPU 标签的 amd64 节点。数量为 0 时不申请 GPU，并设置 `NVIDIA_VISIBLE_DEVICES=void`。

模板不显式设置 CPU 和内存请求或限制；最终资源约束仍可能受集群和命名空间策略影响。默认关闭 Coder Agent 的 Dev Containers 功能及项目自动发现。

默认终端、SSH、VS Code 和 Cursor 会话使用 `coder` 用户，其系统账户目录与 `HOME` 均为 `/home/coder`。容器入口先以 root 准备依赖、账户和权限，然后切换到 `coder` 启动 Agent。`coder` 配置了 `NOPASSWD: ALL`，可通过 `sudo` 或 `sudo -i` 获取 root 权限；保留 privileged 和宿主机网络用于 GPU 开发。模板不提供主机安全隔离，也不能强制禁止用户自行安装 Docker。GPU 资源申请数量不构成强隔离边界。

已有 HOME 中归 root 所有的文件会在启动时迁移给 `coder`，不跟随符号链接或修改独立挂载。首次迁移大量文件可能延长启动时间。镜像中已有 `coder` 时保留 UID，否则创建普通账户并使用 GID 1000。

普通用户的 `ssh-keygen` 默认写入 `/home/coder/.ssh`，随 PVC 持久化。`sudo -i` 切换到 root 后，其 `/root` 仍是非持久化目录；不要在那里保存需要保留的密钥或代码。

## 管理员运行要求

- Coder provisioner 可读取 `/mnt/secrets/kube/config`，其中包含 `beast01` 和 `yunqiao` context，并有权限管理目标集群资源。
- 目标集群存在 `coder-workspaces` 命名空间和支持扩容的 `ceph-fs` StorageClass。
- GPU 节点配置好 NVIDIA 驱动、设备插件、`nvidia` RuntimeClass 和 `nvidia.com/gpu.present=true` 标签。
- 可调度节点存在 `/data-store` 目录；GPU 工作空间还要求 `/var/run/nvidia-topologyd` 目录。
- `coder-workspaces` 中存在 `coder-workspace-proxy` ConfigMap，以及包含 `OSS_ACCESS_KEY_ID`、`OSS_ACCESS_KEY_SECRET`、`OSS_ENDPOINT` 的 `coder-oss-pull` Secret。OSS 凭据应仅具备扩展包所需的读取权限。
- 开发镜像至少包含 `sh`，以 root 运行；缺失工具可通过 APT 自动安装。非 Debian/Ubuntu 镜像需自行预装 `bash`、`git`、OpenSSH 客户端、`python3`、`curl`、`tar`、`openssl`、`base64`、`sha256sum` 、`sudo`、`visudo`、`runuser`、`useradd`、`usermod`、`groupadd`、`getent`、`find` 和 CA 证书。SSH 代理使用 Python 标准库，无需安装额外 Python 包。私有镜像仓库的拉取权限需预先配置。
- 首次依赖安装需要能够访问配置的软件源。容器系统目录在 Pod 重建后会恢复镜像状态，因此缺失的 APT 工具可能需要重新安装。APT 安装失败时容器不会继续启动 Agent，可查看 Kubernetes 容器日志排查。

`ceph-fs` 是存储类名称，实际后端由各集群决定：当前 beast01 使用 NFS，yunqiao 使用 CephFS。
