# Docker Proxy

## 功能

读取当前终端的代理环境变量，同时配置 Docker CLI 和 Docker daemon 的代理。

支持以下环境变量：

- `HTTP_PROXY` / `http_proxy`
- `HTTPS_PROXY` / `https_proxy`
- `ALL_PROXY` / `all_proxy`
- `NO_PROXY` / `no_proxy`

## 平台与依赖

- macOS 或 Linux
- Bash
- Python 3

## 使用方式

脚本被 `~/.my_scripts` 加载时只会注册 `docker-proxy` 命令，不会自动修改 Docker 配置。

先在当前终端加载代理，例如：

```bash
source ../proxy/proxy.sh
```

然后执行：

```bash
docker-proxy
```

默认会同时：

- 更新 `${DOCKER_CONFIG:-$HOME/.docker}/config.json`，供新容器和构建使用。
- 在 Linux systemd 上写入 Docker daemon drop-in 并重启 Docker，供 `docker pull`、`docker push` 使用。

只配置其中一项：

```bash
docker-proxy --client
docker-proxy --daemon
```

默认写入：

```text
${DOCKER_CONFIG:-$HOME/.docker}/config.json
```

查看当前 Docker 代理配置：

```bash
docker-proxy --show
```

清除 Docker 代理配置：

```bash
docker-proxy --clear
```

查看 daemon 配置：

```bash
docker-proxy --daemon --show
```

也可以通过 `DOCKER_CONFIG` 指定 Docker 配置目录：

```bash
DOCKER_CONFIG="$HOME/.config/docker" docker-proxy
```

## 注意事项

- Linux daemon 模式会通过 `sudo` 写入 `/etc/systemd/system/docker.service.d/http-proxy.conf`，并执行 `systemctl daemon-reload` 和 Docker 重启。
- macOS/Windows Docker Desktop 不使用上述 Linux systemd 配置，daemon 代理需要在 Docker Desktop 的代理设置中配置。
- 脚本会保留 `config.json` 中其他配置，只更新 `proxies.default`。
- 当前终端没有代理变量时，脚本不会写入空代理配置。
