#!/usr/bin/env bash

# system-init 共享函数库
#
# 仅被其他脚本 source 使用，不应直接执行。
# 包含：颜色输出、发行版检测、包管理器封装、sudo 检查、
#       下载与 PATH 工具、交互式复选菜单。

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

# ============ 发行版检测 ============

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        echo "${ID:-unknown}"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    elif [[ -f /etc/fedora-release ]]; then
        echo "fedora"
    elif [[ -f /etc/arch-release ]]; then
        echo "arch"
    else
        echo "unknown"
    fi
}

detect_pkg_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        echo "apt"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v pacman >/dev/null 2>&1; then
        echo "pacman"
    elif command -v zypper >/dev/null 2>&1; then
        echo "zypper"
    else
        echo "unknown"
    fi
}

DISTRO=""
PKG_MANAGER=""

# 拒绝通过 sudo 启动：sudo 会把 $HOME 改为 /root，用户级安装
# （ohmyzsh、uv、cargo 等）会写进 root 家目录。
# 仅 root 账户的系统（直接以 root 登录，无 SUDO_USER）允许运行。
check_not_sudo() {
    if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" ]]; then
        error "检测到通过 sudo 启动：\$HOME 已被指向 /root，用户级安装（ohmyzsh、uv、字体等）会装到 root 家目录下"
        error "请去掉 sudo，以普通用户运行：exit 后执行 $0"
        error "如系统只有 root 账户，可先创建普通用户并加入 sudo/wheel 组，或直接以 root 登录运行"
        exit 1
    fi
}

init_environment() {
    check_not_sudo
    DISTRO=$(detect_distro)
    PKG_MANAGER=$(detect_pkg_manager)

    if [[ "$PKG_MANAGER" == "unknown" ]]; then
        error "不支持的发行版：无法检测到 apt/dnf/pacman/zypper"
        error "脚本当前仅支持 Debian/Ubuntu、Fedora/RHEL、Arch、openSUSE"
        exit 1
    fi

    info "检测到发行版: $DISTRO"
    info "包管理器: $PKG_MANAGER"
}

# ============ 临时目录统一清理 ============

# 函数内把 mktemp 目录加入数组，脚本退出时统一删除。
# 不用 trap RETURN：触发时函数已返回，local 变量在 set -u 下不可见。
declare -a TMP_DIRS_TO_CLEAN=()
cleanup_tmp_dirs() {
    if (( ${#TMP_DIRS_TO_CLEAN[@]} > 0 )); then
        rm -rf "${TMP_DIRS_TO_CLEAN[@]}" 2>/dev/null || true
    fi
}
trap cleanup_tmp_dirs EXIT

# ============ 包管理器封装 ============

# Arch：确保 paru（AUR 助手）可用；缺失时从 AUR 构建。
# paru 同时覆盖官方仓库与 AUR，之后所有包统一经 paru 安装。
ensure_paru() {
    if command -v paru >/dev/null 2>&1; then
        return 0
    fi

    step "安装 paru（AUR 助手）"

    # 构建依赖（minimal 环境可能缺 base-devel/git/curl）
    sudo pacman -S --noconfirm --needed base-devel git curl

    local tmp
    tmp=$(mktemp -d)
    TMP_DIRS_TO_CLEAN+=("$tmp")
    git clone --depth=1 https://aur.archlinux.org/paru.git "$tmp/paru"
    (cd "$tmp/paru" && makepkg -si --noconfirm)

    if ! command -v paru >/dev/null 2>&1; then
        error "paru 构建失败，无法继续安装"
        exit 1
    fi
    info "paru 安装完成"
}

pkg_update() {
    case "$PKG_MANAGER" in
        apt)
            sudo apt-get update -qq
            ;;
        dnf)
            sudo dnf check-update || true
            ;;
        pacman)
            ensure_paru
            paru -Sy --noconfirm
            ;;
        zypper)
            sudo zypper refresh
            ;;
    esac
}

pkg_install() {
    case "$PKG_MANAGER" in
        apt)
            sudo apt-get install -y "$@"
            ;;
        dnf)
            sudo dnf install -y "$@"
            ;;
        pacman)
            ensure_paru
            paru -S --noconfirm --needed "$@"
            ;;
        zypper)
            sudo zypper install -y "$@"
            ;;
    esac
}

# 按发行版返回包名
pkg_name() {
    local tool="$1"
    case "$PKG_MANAGER:$tool" in
        apt:7z)      echo "p7zip-full" ;;
        apt:unar)    echo "unar" ;;
        apt:fd)      echo "fd-find" ;;
        apt:bat)     echo "bat" ;;
        apt:rg)      echo "ripgrep" ;;
        apt:nvim)    echo "neovim" ;;
        apt:git)     echo "git" ;;
        apt:zsh)     echo "zsh" ;;
        apt:rsync)   echo "rsync" ;;
        apt:direnv)  echo "direnv" ;;
        apt:fzf)     echo "fzf" ;;
        apt:btop)    echo "btop" ;;
        dnf:7z)      echo "p7zip" ;;
        dnf:unar)    echo "unar" ;;
        dnf:fd)      echo "fd-find" ;;
        dnf:bat)     echo "bat" ;;
        dnf:rg)      echo "ripgrep" ;;
        dnf:nvim)    echo "neovim" ;;
        dnf:git)     echo "git" ;;
        dnf:zsh)     echo "zsh" ;;
        dnf:rsync)   echo "rsync" ;;
        dnf:direnv)  echo "direnv" ;;
        dnf:fzf)     echo "fzf" ;;
        dnf:btop)    echo "btop" ;;
        pacman:7z)   echo "p7zip" ;;
        pacman:unar) echo "unar" ;;
        pacman:fd)   echo "fd" ;;
        pacman:bat)  echo "bat" ;;
        pacman:rg)   echo "ripgrep" ;;
        pacman:nvim) echo "neovim" ;;
        pacman:git)  echo "git" ;;
        pacman:zsh)  echo "zsh" ;;
        pacman:rsync) echo "rsync" ;;
        pacman:direnv) echo "direnv" ;;
        pacman:fzf)  echo "fzf" ;;
        pacman:btop) echo "btop" ;;
        zypper:7z)   echo "p7zip" ;;
        zypper:unar) echo "unar" ;;
        zypper:fd)   echo "fd" ;;
        zypper:bat)  echo "bat" ;;
        zypper:rg)   echo "ripgrep" ;;
        zypper:nvim) echo "neovim" ;;
        zypper:git)  echo "git" ;;
        zypper:zsh)  echo "zsh" ;;
        zypper:rsync) echo "rsync" ;;
        zypper:direnv) echo "direnv" ;;
        zypper:fzf)  echo "fzf" ;;
        zypper:btop) echo "btop" ;;
        *)
            # 默认回退：包名与工具名相同
            echo "$tool"
            ;;
    esac
}

# ============ sudo 检查 ============

check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        warn "部分操作需要 sudo 权限，请确保当前用户有 sudo 权限"
        info "正在测试 sudo ..."
        if ! sudo -v 2>/dev/null; then
            error "无法获取 sudo 权限，请检查用户是否在 sudo 组中"
            return 1
        fi
    fi
    info "sudo 权限正常"
}

# ============ 通用工具函数 ============

github_download() {
    local url="$1"
    local dest="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$dest"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$dest" "$url"
    else
        error "需要 curl 或 wget 来下载文件"
        return 1
    fi
}

ensure_local_bin() {
    mkdir -p "$HOME/.local/bin"
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) export PATH="$HOME/.local/bin:$PATH" ;;
    esac
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
