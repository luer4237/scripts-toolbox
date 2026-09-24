#!/usr/bin/env bash

# 通用单容器管理脚本
#
# 用法：
#   ./docker-ctl.sh          启动容器（不存在则创建）
#   ./docker-ctl.sh stop     停止容器（保留容器和数据）
#   ./docker-ctl.sh start    启动已存在的容器
#   ./docker-ctl.sh rm       强制删除容器
#   ./docker-ctl.sh logs     查看日志
#   ./docker-ctl.sh shell    进入容器
#   ./docker-ctl.sh status   查看状态
#   ./docker-ctl.sh -h       查看帮助
#
# 默认读取脚本同目录下的 docker-ctl.conf。
# 可通过 DOCKER_CTL_CONFIG 指定其他配置文件。

set -euo pipefail

# ============ 配置 ============

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${DOCKER_CTL_CONFIG:-$SCRIPT_DIR/docker-ctl.conf}"

if [[ -f "$CONFIG_FILE" ]]; then
    # 配置文件使用 Bash 变量语法，只读取用户明确指定的可信文件。
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
fi

# EXTRA_ARGS 为可选配置项，未设置时按空参数处理。
EXTRA_ARGS="${EXTRA_ARGS:-}"

# ==================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { printf '%b[INFO]%b %s\n' "$GREEN" "$NC" "$*"; }
warn()  { printf '%b[WARN]%b %s\n' "$YELLOW" "$NC" "$*" >&2; }
error() { printf '%b[ERROR]%b %s\n' "$RED" "$NC" "$*" >&2; }

require_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        error "未找到配置文件：$CONFIG_FILE"
        error "请先复制 $SCRIPT_DIR/docker-ctl.conf.example 为 docker-ctl.conf，或通过 DOCKER_CTL_CONFIG 指定配置文件。"
        return 1
    fi

    local missing=()
    [[ -n "${CONTAINER_NAME+x}" && -n "${CONTAINER_NAME}" ]] || missing+=(CONTAINER_NAME)
    [[ -n "${IMAGE+x}" && -n "${IMAGE}" ]] || missing+=(IMAGE)
    [[ -n "${HOST_PORT+x}" && -n "${HOST_PORT}" ]] || missing+=(HOST_PORT)
    [[ -n "${CONTAINER_PORT+x}" && -n "${CONTAINER_PORT}" ]] || missing+=(CONTAINER_PORT)

    if (( ${#missing[@]} > 0 )); then
        error "配置文件缺少必需项：${missing[*]}"
        return 1
    fi
}

check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        error "未找到 docker 命令，请先安装 Docker"
        return 1
    fi

    if ! docker info >/dev/null 2>&1; then
        error "无法连接 Docker 守护进程，请确认 Docker 已启动，且当前用户有权限访问 Docker"
        return 1
    fi
}

container_exists() {
    docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1
}

container_running() {
    [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null)" = "true" ]
}

start() {
    check_docker || return 1

    if container_exists; then
        if container_running; then
            info "容器 $CONTAINER_NAME 已在运行"
        else
            info "启动已存在的容器 $CONTAINER_NAME ..."
            docker start "$CONTAINER_NAME" >/dev/null
        fi
    else
        info "创建并启动容器 $CONTAINER_NAME ..."
        # EXTRA_ARGS 故意不加引号，以便按空格拆分多个 Docker 参数。
        # shellcheck disable=SC2086
        docker run -d \
            --name "$CONTAINER_NAME" \
            -p "$HOST_PORT:$CONTAINER_PORT" \
            $EXTRA_ARGS \
            "$IMAGE"
    fi

    sleep 2
    info "当前状态："
    docker ps -a --filter "name=^/${CONTAINER_NAME}$"
    printf '\n'
    info "访问地址: https://<宿主机IP>:$HOST_PORT（协议以实际服务为准）"
}

stop() {
    check_docker || return 1

    if container_exists; then
        if container_running; then
            docker stop "$CONTAINER_NAME" >/dev/null
            info "已停止（容器保留，可再次 start）"
        else
            warn "容器 $CONTAINER_NAME 已经停止"
        fi
    else
        warn "容器 $CONTAINER_NAME 不存在"
    fi
}

rm_container() {
    check_docker || return 1

    if container_exists; then
        docker rm -f "$CONTAINER_NAME" >/dev/null
        info "已删除容器（下次 start 将重新创建）"
    else
        warn "容器 $CONTAINER_NAME 不存在"
    fi
}

logs() {
    check_docker || return 1

    if ! container_exists; then
        error "容器 $CONTAINER_NAME 不存在"
        return 1
    fi
    docker logs "$CONTAINER_NAME"
}

shell() {
    check_docker || return 1

    if ! container_exists; then
        error "容器 $CONTAINER_NAME 不存在"
        return 1
    fi
    if ! container_running; then
        error "容器 $CONTAINER_NAME 未运行，请先执行 start"
        return 1
    fi

    if docker exec -it "$CONTAINER_NAME" /bin/bash 2>/dev/null; then
        return 0
    fi

    warn "/bin/bash 不可用，尝试使用 /bin/sh"
    docker exec -it "$CONTAINER_NAME" /bin/sh
}

status() {
    check_docker || return 1
    docker ps -a --filter "name=^/${CONTAINER_NAME}$"
}

usage() {
    cat <<EOF
用法: $0 [命令]

命令：
  start     启动或创建容器（默认）
  stop      停止容器但保留容器
  rm        强制删除容器
  logs      查看容器日志
  shell     进入容器
  status    查看容器状态
  -h, --help
            查看帮助

配置文件：
  ${CONFIG_FILE}
EOF
}

main() {
    case "${1:-start}" in
        -h|--help) usage ;;
        start)
            require_config || return 1
            start
            ;;
        stop)
            require_config || return 1
            stop
            ;;
        rm)
            require_config || return 1
            rm_container
            ;;
        logs)
            require_config || return 1
            logs
            ;;
        shell)
            require_config || return 1
            shell
            ;;
        status)
            require_config || return 1
            status
            ;;
        *)
            usage >&2
            return 1
            ;;
    esac
}

main "$@"
