#!/usr/bin/env bash

_docker_proxy_usage() {
    cat <<'EOF'
用法：
  docker-proxy                    同时设置 Docker client 和 daemon 代理
  docker-proxy --client           只设置 Docker client 代理
  docker-proxy --daemon           只设置 Docker daemon 代理
  docker-proxy --show             查看当前代理配置
  docker-proxy --clear            清除 client 和 daemon 代理
  docker-proxy --daemon --clear   清除 daemon 代理

可读取的环境变量：
  HTTP_PROXY/http_proxy
  HTTPS_PROXY/https_proxy
  ALL_PROXY/all_proxy
  NO_PROXY/no_proxy
EOF
}

_docker_proxy_env() {
    local lower_name="$1"
    local upper_name="$2"
    local value
    value=$(printenv "$lower_name" 2>/dev/null || true)
    if [ -z "$value" ]; then
        value=$(printenv "$upper_name" 2>/dev/null || true)
    fi
    printf '%s' "$value"
}

_docker_proxy_client() {
    local action="$1"
    command -v python3 >/dev/null 2>&1 || {
        echo "错误：需要 python3 读写 Docker client 配置。" >&2
        return 1
    }

    local docker_config_file="${DOCKER_CONFIG:-$HOME/.docker}/config.json"
    DOCKER_PROXY_ACTION="$action" \
    DOCKER_PROXY_CONFIG_FILE="$docker_config_file" \
    python3 - <<'PY'
import json
import os
import pathlib
import tempfile

action = os.environ["DOCKER_PROXY_ACTION"]
config_file = pathlib.Path(os.environ["DOCKER_PROXY_CONFIG_FILE"])

def env_value(lower_name, upper_name):
    return os.environ.get(lower_name) or os.environ.get(upper_name) or ""

if config_file.exists():
    try:
        config = json.loads(config_file.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"错误：无法解析 {config_file}: {exc}")
    if not isinstance(config, dict):
        raise SystemExit(f"错误：{config_file} 的根节点不是 JSON 对象。")
else:
    config = {}

proxies = config.get("proxies")
if proxies is not None and not isinstance(proxies, dict):
    raise SystemExit(f"错误：{config_file} 中的 proxies 不是 JSON 对象。")

if action == "show":
    print(json.dumps((proxies or {}).get("default", {}), ensure_ascii=False, indent=2))
    raise SystemExit(0)

if action == "clear":
    if isinstance(proxies, dict):
        proxies.pop("default", None)
        if not proxies:
            config.pop("proxies", None)
    message = "Docker client 代理配置已清除"
else:
    values = {
        "httpProxy": env_value("http_proxy", "HTTP_PROXY"),
        "httpsProxy": env_value("https_proxy", "HTTPS_PROXY"),
        "allProxy": env_value("all_proxy", "ALL_PROXY"),
        "noProxy": env_value("no_proxy", "NO_PROXY"),
    }
    proxy = {key: value for key, value in values.items() if value}
    if not proxy:
        raise SystemExit("错误：当前 Shell 没有检测到代理变量。")
    config.setdefault("proxies", {})["default"] = proxy
    message = "Docker client 代理配置已更新"

config_file.parent.mkdir(parents=True, exist_ok=True)
with tempfile.NamedTemporaryFile(
    mode="w", encoding="utf-8", dir=config_file.parent,
    prefix="config.json.", suffix=".tmp", delete=False
) as handle:
    json.dump(config, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
    temporary_file = pathlib.Path(handle.name)

temporary_file.replace(config_file)
print(f"{message}: {config_file}")
PY
}

_docker_proxy_escape_systemd() {
    local value="$1"
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    printf '%s' "$value"
}

_docker_proxy_daemon() {
    local action="$1"
    if [[ "$(uname -s 2>/dev/null)" != "Linux" ]]; then
        echo "Docker daemon 代理目前只支持 Linux systemd；macOS/Windows Docker Desktop 请在 Desktop 设置中配置。" >&2
        return 2
    fi

    command -v systemctl >/dev/null 2>&1 || {
        echo "错误：未找到 systemctl，无法配置 Docker daemon。" >&2
        return 1
    }

    local dropin_dir="/etc/systemd/system/docker.service.d"
    local dropin_file="$dropin_dir/http-proxy.conf"

    if [[ "$action" == "show" ]]; then
        sudo systemctl show --property=Environment docker
        return $?
    fi

    if [[ "$action" == "clear" ]]; then
        sudo rm -f "$dropin_file" || return 1
        sudo systemctl daemon-reload || return 1
        sudo systemctl restart docker
        echo "Docker daemon 代理配置已清除"
        return $?
    fi

    local http_proxy https_proxy all_proxy no_proxy
    http_proxy=$(_docker_proxy_env http_proxy HTTP_PROXY)
    https_proxy=$(_docker_proxy_env https_proxy HTTPS_PROXY)
    all_proxy=$(_docker_proxy_env all_proxy ALL_PROXY)
    no_proxy=$(_docker_proxy_env no_proxy NO_PROXY)

    [[ -n "$http_proxy$https_proxy$all_proxy" ]] || {
        echo "错误：当前 Shell 没有检测到 Docker daemon 可用的代理变量。" >&2
        return 1
    }

    local escaped_http escaped_https escaped_all escaped_no_proxy
    escaped_http=$(_docker_proxy_escape_systemd "$http_proxy")
    escaped_https=$(_docker_proxy_escape_systemd "$https_proxy")
    escaped_all=$(_docker_proxy_escape_systemd "$all_proxy")
    escaped_no_proxy=$(_docker_proxy_escape_systemd "$no_proxy")

    local config='[Service]'$'\n'
    [[ -n "$http_proxy" ]] && config+="Environment=\"HTTP_PROXY=$escaped_http\""$'\n'
    [[ -n "$https_proxy" ]] && config+="Environment=\"HTTPS_PROXY=$escaped_https\""$'\n'
    [[ -n "$all_proxy" ]] && config+="Environment=\"ALL_PROXY=$escaped_all\""$'\n'
    [[ -n "$no_proxy" ]] && config+="Environment=\"NO_PROXY=$escaped_no_proxy\""$'\n'

    printf '%s' "$config" | sudo mkdir -p "$dropin_dir" && \
        printf '%s' "$config" | sudo tee "$dropin_file" >/dev/null || return 1

    sudo systemctl daemon-reload || return 1
    sudo systemctl restart docker || return 1
    echo "Docker daemon 代理配置已更新: $dropin_file"
}

docker_proxy() {
    local target="both"
    local action="apply"
    local argument

    while [[ $# -gt 0 ]]; do
        argument="$1"
        case "$argument" in
            --client) target="client" ;;
            --daemon) target="daemon" ;;
            --show) action="show" ;;
            --clear) action="clear" ;;
            --apply) action="apply" ;;
            -h|--help)
                _docker_proxy_usage
                return 0
                ;;
            *)
                _docker_proxy_usage >&2
                return 2
                ;;
        esac
        shift
    done

    local result=0
    if [[ "$target" == "both" || "$target" == "client" ]]; then
        _docker_proxy_client "$action" || result=$?
    fi
    if [[ "$target" == "both" || "$target" == "daemon" ]]; then
        _docker_proxy_daemon "$action" || result=$?
    fi
    return "$result"
}

# 被统一加载时只注册命令，不自动修改 Docker 配置。
docker-proxy() {
    docker_proxy "$@"
}
