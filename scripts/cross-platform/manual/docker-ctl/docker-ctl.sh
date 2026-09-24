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

set -euo pipefail

# ============ 可配置项 ============

CONTAINER_NAME="awvs"
IMAGE="secfa/docker-awvs"
HOST_PORT="13443"
CONTAINER_PORT="3443"

# 多个参数使用空格分隔。参数中包含空格时，请改为单独调整 docker run 命令。
EXTRA_ARGS="--cap-add LINUX_IMMUTABLE"

# ==================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { printf '%b[INFO]%b %s\n' "$GREEN" "$NC" "$*"; }
warn()  { printf '%b[WARN]%b %s\n' "$YELLOW" "$NC" "$*" >&2; }
error() { printf '%b[ERROR]%b %s\n' "$RED" "$NC" "$*" >&2; }

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
    printf '用法: %s {start|stop|rm|logs|shell|status}\n' "$0"
}

main() {
    case "${1:-start}" in
        start)  start ;;
        stop)   stop ;;
        rm)     rm_container ;;
        logs)   logs ;;
        shell)  shell ;;
        status) status ;;
        *)
            usage >&2
            return 1
            ;;
    esac
}

main "$@"
