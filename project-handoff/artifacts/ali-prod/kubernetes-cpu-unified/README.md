# Kubernetes CPU 工作空间

创建时选择 1 至 4 台机器。每台调度到同一集群的不同节点，拥有独立 Agent 和 HOME PVC。机器数量和集群在创建后固定。停止后保留磁盘。

每台请求并限制 128 GiB，使用 Pod 网络、非特权容器和独立 HOME，无宿主机目录挂载。支持 beast01、yunqiao、beast03。

同一集群中的其他空间可以用 Kubernetes DNS 访问运行中的节点。主机名为 <空间名>--<用户名>.coder-workspaces.svc，附加节点在 Service 名末尾加 --n1、--n2、--n3。数字开头的名称加 n-- 以满足 Service 命名规则，超过 63 个字符时缩短并加哈希。运行 `echo "$WORKSPACE_SERVICE_HOST"` 查看本机地址，`printf '%s\n' $WORKSPACE_PEERS` 列出全部节点。应用需监听可达接口，自行处理鉴权。GPU 单机使用宿主机 IP，同节点服务需使用不同端口。

可自定义开发镜像；启动脚本会初始化 coder 用户和免密 sudo，继承集群代理。请把个人文件保存在 /home/coder。
