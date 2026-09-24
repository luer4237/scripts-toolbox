# Docker Container Controller

## 功能

管理一个固定配置的 Docker 容器，支持启动、停止、删除、日志、进入容器和查看状态。

容器名、镜像、端口和额外参数从脚本同目录下的 `docker-ctl.conf` 读取。配置文件不存在或缺少必需项时，脚本会提示错误并退出。

## 文件

- [`docker-ctl.sh`](docker-ctl.sh)：Docker 容器管理脚本。
- [`docker-ctl.conf.example`](docker-ctl.conf.example)：配置文件示例。

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

首次使用前，必须在脚本所在目录创建配置文件：

```bash
cp docker-ctl.conf.example docker-ctl.conf
```

也可以通过 `DOCKER_CTL_CONFIG` 指定配置文件路径：

```bash
DOCKER_CTL_CONFIG="/path/to/docker-ctl.conf" ./docker-ctl.sh start
```

配置文件使用 Bash 变量语法：

```bash
# 容器名称
CONTAINER_NAME="填写容器名称"
# Docker 镜像
IMAGE="填写 Docker 镜像"
# 宿主机端口
HOST_PORT="填写宿主机端口"
# 容器端口
CONTAINER_PORT="填写容器端口"
# 可选，传给 docker run 的额外参数；多个参数使用空格分隔。
# 示例：
# EXTRA_ARGS="--cap-add LINUX_IMMUTABLE"
# EXTRA_ARGS="--restart unless-stopped"
EXTRA_ARGS=""
```

复制样板后，请将前四项替换为实际配置；`EXTRA_ARGS` 没有额外参数时可以保持为空。

## 配置参数

| 参数 | 是否必需 | 说明 |
| --- | --- | --- |
| `CONTAINER_NAME` | 是 | Docker 容器名称。脚本通过此名称查找、启动、停止、删除和查看容器。名称需要在当前 Docker 环境中保持唯一。 |
| `IMAGE` | 是 | 创建容器时使用的 Docker 镜像，例如 `secfa/docker-awvs`。容器已经创建后，修改该值不会自动替换现有容器。 |
| `HOST_PORT` | 是 | 宿主机监听的端口。访问服务时使用该端口，例如 `https://宿主机IP:13443`。 |
| `CONTAINER_PORT` | 是 | 容器内部服务监听的端口。脚本会将它映射到 `HOST_PORT`，形成 `HOST_PORT:CONTAINER_PORT`。 |
| `EXTRA_ARGS` | 否 | 传给 `docker run` 的额外参数，例如 `--cap-add LINUX_IMMUTABLE`。多个参数使用空格分隔；不需要额外参数时可以省略。 |

配置文件路径也可以通过环境变量覆盖：

| 环境变量 | 说明 |
| --- | --- |
| `DOCKER_CTL_CONFIG` | 指定要读取的配置文件路径；未设置时读取脚本同目录下的 `docker-ctl.conf`。 |

## 注意事项

- 需要 Bash 和 Docker CLI。
- 配置文件会按 Bash 脚本读取，请只使用可信配置文件；不要将不可信内容写入配置文件。
- `rm` 会强制删除容器，但不会删除显式挂载到宿主机的数据目录。
- `EXTRA_ARGS` 是可选配置项；容器已经创建后，再修改配置文件中的镜像、端口或 `EXTRA_ARGS` 不会自动应用，需要先执行 `rm`，再重新 `start` 创建。
- 这是按需直接执行的管理脚本，建议放在对应 Docker 项目或管理目录中，不要放入 `~/.my_scripts` 自动加载目录。
