# Kubernetes CPU 开发工作空间

可选择 beast01、yunqiao 或 beast03。集群在创建后固定，HOME PVC 保留在所选集群。

- 内存请求与上限均为 128 GiB。Pod 由 Kubernetes 调度器根据已申请资源和节点可分配容量安排。容量不足时会等待调度。
- 使用 Pod 网络和集群 DNS，容器不启用 privileged，不挂载宿主机目录或运行时 socket，也不申请 GPU。
- 默认用 Ubuntu 22.04。可填写其他兼容的开发镜像。镜像须能由所选集群的节点拉取，容器内的代理不参与拉取。
- 启动后使用 coder 用户，支持免密 sudo。HOME 为 /home/coder，文件和编辑器配置保存在独立 PVC。
- 从所在集群的 coder-workspace-proxy 注入代理，支持 sudo 和 Git 代理继承。可通过 VS Code Desktop 或 Cursor 连接。

该模板用于普通 CPU 开发。在工作空间中运行嵌套 K3s 需要另外验证运行时和权限。
