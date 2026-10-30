#!/usr/bin/env bash

# 开发环境初始化脚本：LazyVim、rustup 工具链、fnm Node.js
#
# 用法：
#   ./setup-dev.sh                交互式选择要执行的任务
#   ./setup-dev.sh rustup fnm     直接执行指定任务
#   ./setup-dev.sh rustup,fnm     同上，支持逗号分隔
#   ./setup-dev.sh --list         列出所有任务
#   ./setup-dev.sh -h             查看帮助
#
# 被 source 时仅提供函数和数据，不执行 main。

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

# 依赖 install-software.sh 中的 install_nvim/install_git/install_rustup/install_fnm 函数
# shellcheck source=install-software.sh
source "$SCRIPT_DIR/install-software.sh"

# ============ 任务定义 ============

DEV_TASKS=(
    "lazyvim" "rustup" "fnm"
)

declare -A DEV_TASK_DESC=(
    [lazyvim]="LazyVim 初始化 nvim 配置"
    [rustup]="rustup 安装最新 stable 工具链"
    [fnm]="fnm 安装最新 Node.js 版本"
)

# --- LazyVim 初始化 ---

init_lazyvim() {
    if ! command -v nvim >/dev/null 2>&1; then
        warn "未检测到 nvim，跳过 LazyVim 初始化"
        warn "请先安装 nvim，然后重新运行此任务"
        return 1
    fi
    install_lazyvim
}

# --- rustup 初始化 ---

init_rustup() {
    if ! command -v rustup >/dev/null 2>&1; then
        warn "未检测到 rustup，将先安装 rustup"
        install_rustup
    fi

    # 加载 cargo 环境
    source "$HOME/.cargo/env" 2>/dev/null || true

    info "安装 rust 最新 stable 工具链 ..."
    rustup install stable
    rustup default stable
    info "rustup 已初始化，默认工具链: stable"
    rustup show
}

# --- fnm 初始化 ---

init_fnm() {
    if ! command -v fnm >/dev/null 2>&1; then
        warn "未检测到 fnm，将先安装 fnm"
        install_fnm
    fi

    # 确保 fnm 在 PATH 中
    local fnm_bin="$HOME/.local/share/fnm/fnm"
    if [[ -f "$fnm_bin" ]]; then
        export PATH="$HOME/.local/share/fnm:$PATH"
        eval "$($fnm_bin env --shell bash)" 2>/dev/null || true
    fi

    info "安装最新 Node.js 版本 ..."
    fnm install --latest 2>/dev/null || {
        # 如果 fnm 命令不在 PATH 中，尝试直接用完整路径
        if [[ -f "$fnm_bin" ]]; then
            "$fnm_bin" install --latest
        else
            error "fnm 命令不可用"
            return 1
        fi
    }

    # 设置默认版本
    local latest_ver
    latest_ver=$(fnm list 2>/dev/null | tail -1 | awk '{print $NF}' | tr -d 'v' || "")
    if [[ -n "$latest_ver" ]]; then
        fnm default "$latest_ver" 2>/dev/null || true
        info "fnm 默认 Node.js 版本: v$latest_ver"
    fi

    fnm list
}

# ============ 入口 ============

run_dev_task() {
    local task="$1"
    step "开发环境: ${DEV_TASK_DESC[$task]:-$task}"
    local func_name="init_${task}"
    if declare -f "$func_name" >/dev/null 2>&1; then
        "$func_name"
    else
        error "未知的开发环境任务: $task"
        return 1
    fi
}

list_dev_tasks() {
    printf '\n%b开发环境任务：%b\n' "$BOLD" "$NC"
    local task
    for task in "${DEV_TASKS[@]}"; do
        printf '  %s%s%s (%s)\n' "$CYAN" "$task" "$NC" "${DEV_TASK_DESC[$task]:-}"
    done
    printf '\n'
}

usage() {
    cat <<EOF
开发环境初始化脚本

用法: $0 [任务 ...]

不带参数时进入交互式菜单；带任务名参数时直接执行（支持逗号或空格分隔）。

可用任务:
  lazyvim    LazyVim 初始化 nvim 配置
  rustup     rustup 安装最新 stable 工具链
  fnm        fnm 安装最新 Node.js 版本

示例:
  $0               交互式选择
  $0 rustup fnm    直接执行指定任务
  $0 --list        列出所有任务
EOF
}

run_setup_dev() {
    check_not_sudo
    local tasks=()

    if (( $# > 0 )); then
        parse_item_args "$@"
        tasks=("${PARSED_ITEMS[@]}")
    else
        mapfile -t tasks < <(show_checkbox "选择开发环境任务（默认全部选中）" "default" DEV_TASK_DESC "${DEV_TASKS[@]}")
    fi

    if [[ ${#tasks[@]} -eq 0 ]]; then
        info "未选择任何任务"
        return 0
    fi

    local task
    for task in "${tasks[@]}"; do
        run_dev_task "$task"
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        -h|--help)
            usage
            ;;
        --list)
            list_dev_tasks
            ;;
        "")
            run_setup_dev
            ;;
        *)
            run_setup_dev "$@"
            ;;
    esac
fi
