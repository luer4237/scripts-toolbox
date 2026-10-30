#!/usr/bin/env bash

# macOS 系统初始化主脚本
#
# 交互式选择要安装的软件和初始化任务，然后调用同目录的各子脚本完成执行：
#   - install-software.sh  软件安装（Homebrew）
#   - setup-system.sh      系统设置（终端字体与透明度、系统语言）
#   - setup-zshrc.sh       zshrc 初始化
#   - setup-ssh.sh         SSH 全局配置
#   - setup-dev.sh         开发环境初始化（LazyVim、rustup、fnm）
#
# 每个子脚本都可以单独运行，用法见各脚本帮助。
#
# 用法：
#   ./system-init.sh           进入交互式菜单
#   ./system-init.sh --list    列出所有可用项目
#   ./system-init.sh -h        查看帮助

# macOS 自带 bash 3.2，脚本依赖 bash 4+ 语法；直接执行时切换到 Homebrew bash
if (( BASH_VERSINFO[0] < 4 )) && [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    for _bash4 in /opt/homebrew/bin/bash /usr/local/bin/bash; do
        if [[ -x "$_bash4" ]]; then
            exec "$_bash4" "${0}" "$@"
        fi
    done
    echo "此脚本需要 bash >= 4，请先执行: brew install bash" >&2
    exit 1
fi

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# source 各子脚本获得函数和数据（子脚本带执行 guard，被 source 时不会执行 main）

# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
# shellcheck source=install-software.sh
source "$SCRIPT_DIR/install-software.sh"
# shellcheck source=setup-system.sh
source "$SCRIPT_DIR/setup-system.sh"
# shellcheck source=setup-zshrc.sh
source "$SCRIPT_DIR/setup-zshrc.sh"
# shellcheck source=setup-dev.sh
source "$SCRIPT_DIR/setup-dev.sh"
# shellcheck source=setup-ssh.sh
source "$SCRIPT_DIR/setup-ssh.sh"

# ============ 任务定义 ============

# 主菜单任务列表（按显示顺序），执行时分发到对应子脚本的函数
INIT_TASKS=(
    "zshrc" "terminal" "locale" "ssh" "lazyvim" "rustup" "fnm"
)

declare -A INIT_DESC=(
    [zshrc]="初始化 ~/.zshrc 并设置 zsh 为默认 Shell"
    [terminal]="终端字体 JetBrainsMono Nerd Font，透明度 80%"
    [locale]="系统语言设置为简体中文（zh-Hans）"
    [ssh]="SSH 全局配置（连接复用与 Keepalive）"
    [lazyvim]="LazyVim 初始化 nvim 配置"
    [rustup]="rustup 安装最新 stable 工具链"
    [fnm]="fnm 安装最新 Node.js 版本"
)

# 任务 -> 所在脚本（用于展示分发关系）
declare -A INIT_SCRIPT=(
    [zshrc]="setup-zshrc.sh"
    [terminal]="setup-system.sh"
    [locale]="setup-system.sh"
    [ssh]="setup-ssh.sh"
    [lazyvim]="setup-dev.sh"
    [rustup]="setup-dev.sh"
    [fnm]="setup-dev.sh"
)

run_init_task() {
    local task="$1"
    step "初始化 ${INIT_DESC[$task]:-$task}"
    local func_name="init_${task}"
    if declare -f "$func_name" >/dev/null 2>&1; then
        "$func_name"
    else
        error "未知的初始化任务: $task"
        return 1
    fi
}

# ============ 主流程 ============

list_all() {
    list_software
    printf '\n%b初始化任务：%b\n' "$BOLD" "$NC"
    local task
    for task in "${INIT_TASKS[@]}"; do
        printf '  %s%s%s (%s) [%s]\n' "$CYAN" "$task" "$NC" "${INIT_DESC[$task]:-}" "${INIT_SCRIPT[$task]:-}"
    done
    printf '\n'
}

usage() {
    cat <<EOF
macOS 系统初始化脚本（主入口）

用法: $0 [选项]

选项：
  --list     列出所有可用的软件和初始化任务
  -h, --help 查看帮助

不传参数时进入交互式菜单，选择软件和任务后调用各子脚本执行。

子脚本（均可单独运行，见各自 -h）：
  install-software.sh  软件安装（Homebrew）
  setup-system.sh      系统设置（终端字体与透明度、系统语言）
  setup-zshrc.sh       zshrc 初始化
  setup-dev.sh         开发环境初始化（lazyvim、rustup、fnm）
  setup-ssh.sh         SSH 配置（install / remove / status）

依赖:
  macOS（Apple Silicon 或 Intel）、bash >= 4、Homebrew
  macOS 自带 bash 3.2，直接执行时脚本会自动切换到 Homebrew bash

软件安装完成后，建议重新加载 Shell:
  source ~/.zshrc   # 或
  exec \$SHELL
EOF
}

main() {
    case "${1:-}" in
        -h|--help)
            usage
            exit 0
            ;;
        --list)
            list_all
            exit 0
            ;;
        "")
            ;;
        *)
            error "未知参数: $1"
            usage
            exit 1
            ;;
    esac

    # 打印欢迎信息
    printf '\n'
    printf '%b╔══════════════════════════════════════════╗%b\n' "$BLUE" "$NC"
    printf '%b║       macOS 系统初始化脚本               ║%b\n' "$BLUE" "$NC"
    printf '%b╚══════════════════════════════════════════╝%b\n' "$BLUE" "$NC"
    printf '\n'

    # 初始化环境检测
    init_environment

    # 选择软件
    local all_software=("${DEFAULT_SOFTWARE[@]}" "${OPTIONAL_SOFTWARE[@]}")
    step "选择要安装的软件"
    mapfile -t selected_software < <(show_checkbox "软件安装（默认全部选中）" "default" SW_DESC "${all_software[@]}")

    # 选择初始化任务
    step "选择初始化任务"
    mapfile -t selected_init < <(show_checkbox "初始化任务（默认全部选中）" "default" INIT_DESC "${INIT_TASKS[@]}")

    # 确认
    printf '\n%b=== 确认 ===%b\n' "$BOLD" "$NC"
    printf '\n已选软件 (%d):\n' "${#selected_software[@]}"
    local sw
    for sw in "${selected_software[@]}"; do
        printf '  [x] %s\n' "$sw"
    done
    printf '\n已选初始化任务 (%d):\n' "${#selected_init[@]}"
    local task
    for task in "${selected_init[@]}"; do
        printf '  [x] %s (%s)\n' "$task" "${INIT_DESC[$task]:-}"
    done

    printf '\n%b确认执行？[Y/n]%b ' "$YELLOW"
    read -r confirm
    if [[ "${confirm,,}" == "n" ]]; then
        info "已取消"
        exit 0
    fi

    # 执行安装（Homebrew 由 install-software.sh 的 brew_* 封装完成）
    if [[ ${#selected_software[@]} -gt 0 ]]; then
        ensure_brew
        step "开始安装软件 (${#selected_software[@]} 个)"
        brew_update
        for sw in "${selected_software[@]}"; do
            install_tool "$sw"
        done
    fi

    # 执行初始化任务（各 setup-*.sh 的函数）
    if [[ ${#selected_init[@]} -gt 0 ]]; then
        step "开始执行初始化任务 (${#selected_init[@]} 个)"
        for task in "${selected_init[@]}"; do
            run_init_task "$task"
        done
    fi

    # 完成
    printf '\n'
    printf '%b╔══════════════════════════════════════════╗%b\n' "$GREEN" "$NC"
    printf '%b║           初始化完成！                    ║%b\n' "$GREEN" "$NC"
    printf '%b╚══════════════════════════════════════════╝%b\n' "$GREEN" "$NC"
    printf '\n'

    info "建议执行以下操作使设置生效："
    printf '  1. 重新加载 Shell: %bexec $SHELL%b 或 %bsource ~/.zshrc%b\n' "$CYAN" "$NC" "$CYAN" "$NC"
    printf '  2. 重新登录使系统语言设置生效\n'
    printf '  3. 如更改了默认 Shell，需重新登录终端\n'
    printf '\n'
}

main "$@"
