# Kubernetes GPU 工作空间

网页创建时选择 1 至 4 台机器。选择多台会创建独立工作空间，例如 aitest-1 和 aitest-2，可分别停止、启动和删除。每台调度到同一集群的不同节点，拥有独立 Agent 和 HOME PVC。机器数量和集群在创建后固定。停止后保留磁盘。

每台申请 0 至 8 张 GPU。beast01、beast03、yunqiao 使用 NVIDIA，mars2 使用 MetaX。单机使用宿主网络，多机使用 Pod 网络。原有 NVIDIA 单机仍挂载 /data-store。

同一集群中的其他空间可以用 Kubernetes DNS 访问运行中的节点。主机名为 ws-<空间名>--<用户名>.coder-workspaces.svc，批量创建的每个工作空间均使用自己的 ws 地址。旧版单工作空间内的附加节点保留 wn1、wn2、wn3 前缀。长名称自动缩短并附加哈希。运行 `echo "$WORKSPACE_SERVICE_HOST"` 查看本机地址，`printf '%s\n' $WORKSPACE_PEERS` 列出全部节点。应用需监听可达接口，自行处理鉴权。GPU 单机使用宿主机 IP，同节点服务需使用不同端口。

可自定义开发镜像；启动脚本会初始化 coder 用户和免密 sudo，继承集群代理。请把个人文件保存在 /home/coder。
