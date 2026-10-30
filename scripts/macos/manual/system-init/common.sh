#!/usr/bin/env bash

# macOS system-init 共享函数库
#
# 仅被其他脚本 source 使用，不应直接执行。
# 包含：颜色输出、平台检查、Homebrew 封装与交互式复选菜单。

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "此文件是函数库，请通过 source 引入，不要直接执行" >&2
    exit 1
fi

if [[ -n "${SYSTEM_INIT_COMMON_LOADED:-}" ]]; then
    return 0
fi
SYSTEM_INIT_COMMON_LOADED=1

# ============ 颜色与输出 ============

# 使用 $'...' 使变量值为真实的 ESC 控制字符，
# 这样 printf 的 %s 和 %b 都能正确显示颜色。
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
CYAN=$'\033[0;36m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
NC=$'\033[0m'

info()  { printf '%b[INFO]%b %s\n' "$GREEN" "$NC" "$*"; }
warn()  { printf '%b[WARN]%b %s\n' "$YELLOW" "$NC" "$*" >&2; }
error() { printf '%b[ERROR]%b %s\n' "$RED" "$NC" "$*" >&2; }
step()  { printf '\n%b== %b %s %b==%b\n' "$BLUE" "$BOLD" "$*" "$BLUE" "$NC"; }

# ============ 平台检查 ============

check_platform() {
    if [[ "$(uname -s)" != "Darwin" ]]; then
        error "此脚本仅支持 macOS，当前系统: $(uname -s)"
        exit 1
    fi
}

# 拒绝通过 sudo 启动：sudo 会把 $HOME 改为 /root，用户级配置
# （ohmyzsh、字体、~/.zshrc 等）会写进 root 家目录。
check_not_sudo() {
    if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" ]]; then
        error "检测到通过 sudo 启动：\$HOME 已被指向 /root，用户级配置会写到 root 家目录"
        error "请去掉 sudo，以普通用户运行"
        exit 1
    fi
}

# ============ Homebrew ============

# Homebrew 7+ 默认启用 ask 模式，逐个包询问是否继续；
# 批量安装时统一跳过确认（等同于 --no-ask）
export HOMEBREW_NO_ASK=1

BREW_BIN=""

detect_brew() {
    if command -v brew >/dev/null 2>&1; then
        BREW_BIN="$(command -v brew)"
    elif [[ -x /opt/homebrew/bin/brew ]]; then
        BREW_BIN="/opt/homebrew/bin/brew"
    elif [[ -x /usr/local/bin/brew ]]; then
        BREW_BIN="/usr/local/bin/brew"
    else
        BREW_BIN=""
    fi
}

# 让当前 Shell 使用 Homebrew 提供的命令和库
brew_shellenv() {
    detect_brew
    [[ -n "$BREW_BIN" ]] || return 1
    eval "$("$BREW_BIN" shellenv)"
}

install_brew() {
    info "通过官方脚本安装 Homebrew ..."
    NONINTERACTIVE=1 /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    brew_shellenv
}

# 确保 brew 可用；缺失时询问后执行官方安装脚本
ensure_brew() {
    detect_brew
    if [[ -n "$BREW_BIN" ]]; then
        brew_shellenv
        info "Homebrew: $("$BREW_BIN" --prefix)"
        return 0
    fi

    warn "未检测到 Homebrew"
    printf '是否安装 Homebrew？会执行官方安装脚本（需要网络，可能提示输入密码）[Y/n] '
    read -r answer
    if [[ "${answer,,}" == "n" ]]; then
        error "缺少 Homebrew，无法继续"
        return 1
    fi

    install_brew
    detect_brew
    if [[ -z "$BREW_BIN" ]]; then
        error "Homebrew 安装失败"
        return 1
    fi
    info "Homebrew 安装完成: $("$BREW_BIN" --prefix)"
}

init_environment() {
    check_platform
    check_not_sudo
    detect_brew
    if [[ -n "$BREW_BIN" ]]; then
        info "Homebrew: $("$BREW_BIN" --prefix)"
    else
        warn "未检测到 Homebrew（安装软件时会询问是否自动安装）"
    fi
}

# ============ 包管理器封装 ============

# 索引更新失败不应中断后续安装（网络抖动时仍可继续使用本地索引）
brew_update() {
    "$BREW_BIN" update || warn "brew update 失败，继续使用本地索引"
}

brew_install() {
    "$BREW_BIN" install "$@"
}

brew_install_cask() {
    "$BREW_BIN" install --cask "$@"
}

# 判断公式是否已安装
brew_has() {
    "$BREW_BIN" list --formula "$1" >/dev/null 2>&1
}

# 判断 cask 是否已安装
brew_has_cask() {
    "$BREW_BIN" list --cask "$1" >/dev/null 2>&1
}

# ============ 交互式复选菜单 ============

# 显示复选列表，返回选中的项目（每行一个）。
# 用法: mapfile -t selected < <(show_checkbox "标题" "default" DESC_MAP item1 item2 ...)
# 参数:
#   $1       标题
#   $2       "default" = 默认全选, "optional" = 默认全不选
#   $3       描述映射的关联数组名（nameref），条目无描述时显示为空
#   $4...    待选条目
# 菜单显示输出到 stderr，选中结果输出到 stdout。
show_checkbox() {
    local title="$1"
    local mode="$2"
    local -n desc_map="$3"
    shift 3

    local items=("$@")
    local count=${#items[@]}
    local selected=()

    # 初始化选中状态
    local i
    for ((i = 0; i < count; i++)); do
        if [[ "$mode" == "default" ]]; then
            selected[i]=1
        else
            selected[i]=0
        fi
    done

    while true; do
        # 菜单显示输出到 stderr
        {
            printf '\n%b%s%b\n' "$BOLD" "$title" "$NC" >&2
            local sep
            sep=$(printf '──%.0s' {1..30})
            printf '%b%s%b\n' "$DIM" "$sep" "$NC" >&2
            printf '  %b输入编号切换选择（逗号分隔），a 全选/取消，回车确认%b\n' "$DIM" "$NC" >&2
            printf '%b%s%b\n' "$DIM" "$sep" "$NC" >&2

            for ((i = 0; i < count; i++)); do
                local item="${items[i]}"
                local desc="${desc_map[$item]:-}"
                local marker
                if [[ "${selected[i]}" == "1" ]]; then
                    marker="${GREEN}[x]${NC}"
                else
                    marker="${DIM}[ ]${NC}"
                fi
                printf '  %b%2d%b  %s  %s %s\n' \
                    "$CYAN" "$((i + 1))" "$NC" \
                    "$marker" \
                    "$item" "${desc:+(${desc})}" >&2
            done

            printf '\n' >&2
            printf '  选择: ' >&2
        }

        read -r choice || break

        if [[ -z "$choice" ]]; then
            break
        elif [[ "$choice" == "a" || "$choice" == "A" ]]; then
            # 全选或取消全选
            local any_selected=0
            for ((i = 0; i < count; i++)); do
                if [[ "${selected[i]}" == "1" ]]; then
                    any_selected=1
                    break
                fi
            done
            for ((i = 0; i < count; i++)); do
                selected[i]=$((1 - any_selected))
            done
        else
            # 解析逗号分隔的编号
            IFS=', ' read -ra nums <<< "$choice"
            for num in "${nums[@]}"; do
                if [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= count )); then
                    local idx=$((num - 1))
                    selected[idx]=$((1 - selected[idx]))
                fi
            done
        fi
    done

    # 输出选中的项目到 stdout
    local result=()
    for ((i = 0; i < count; i++)); do
        if [[ "${selected[i]}" == "1" ]]; then
            result+=("${items[i]}")
        fi
    done

    printf '%s\n' "${result[@]}"
}

# ============ 参数模式公共逻辑 ============

# 把 "$@" 解析为条目数组，支持空格和逗号分隔。
# 结果通过全局数组 PARSED_ITEMS 返回。
parse_item_args() {
    PARSED_ITEMS=()
    local input="${*}"
    input="${input//,/ }"
    # shellcheck disable=SC2206
    PARSED_ITEMS=($input)
}
