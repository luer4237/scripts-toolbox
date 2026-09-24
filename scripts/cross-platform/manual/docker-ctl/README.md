# Docker Container Controller

## 功能

管理一个固定配置的 Docker 容器，支持启动、停止、删除、日志、进入容器和查看状态。

默认配置针对 `secfa/docker-awvs`，更换其他容器时只需要修改脚本顶部的可配置项。

## 使用方式

```bash
./docker-ctl.sh          # 启动或创建容器
./docker-ctl.sh start    # 启动容器
./docker-ctl.sh stop     # 停止容器但保留容器
./docker-ctl.sh logs     # 查看日志
./docker-ctl.sh shell    # 进入容器
./docker-ctl.sh status   # 查看状态
./docker-ctl.sh rm       # 强制删除容器
./docker-ctl.sh -h       # 查看帮助
```

首次使用前建议复制脚本，再修改以下配置：

```bash
CONTAINER_NAME="awvs"
IMAGE="secfa/docker-awvs"
HOST_PORT="13443"
CONTAINER_PORT="3443"
EXTRA_ARGS="--cap-add LINUX_IMMUTABLE"
```

## 注意事项

- 需要 Bash 和 Docker CLI。
- `rm` 会强制删除容器，但不会删除显式挂载到宿主机的数据目录。
- 容器已经创建后，再修改镜像、端口或 `EXTRA_ARGS` 不会自动应用；需要先执行 `rm`，再重新 `start` 创建。
- 这是按需直接执行的管理脚本，建议放在对应 Docker 项目或管理目录中，不要放入 `~/.my_scripts` 自动加载目录。
