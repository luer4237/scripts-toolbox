#!/usr/bin/env bash

# 软件安装脚本（macOS，基于 Homebrew）
#
# 用法：
#   ./install-software.sh            交互式选择要安装的软件
#   ./install-software.sh nvim eza   直接安装指定软件
#   ./install-software.sh nvim,eza   同上，支持逗号分隔
#   ./install-software.sh --list     列出所有可用软件
#   ./install-software.sh -h         查看帮助
#
# 被 source 时仅提供函数和数据，不执行 main。

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

# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

# ============ 软件定义 ============

# 默认安装列表（按显示顺序）
DEFAULT_SOFTWARE=(
    "bash" "zsh" "ohmyzsh" "zsh-autosuggestions" "zsh-completions" "zsh-syntax-highlighting"
    "rsync" "7z" "unar"
    "JetbrainsMonoNerdFont"
    "fzf" "starship" "eza" "fd" "bat" "rg" "zoxide" "yazi" "btop"
    "git" "lazygit"
    "uv" "fnm" "rustup" "nvim" "lazyvim" "mise"
)

# 可选安装列表（默认不选）
OPTIONAL_SOFTWARE=(
    "direnv"
)

# 软件描述
declare -A SW_DESC=(
    [bash]="Bash Shell（脚本依赖 >= 4，Homebrew 新版）"
    [zsh]="Zsh Shell（Homebrew 新版）"
    [ohmyzsh]="Oh My Zsh 框架"
    [zsh-autosuggestions]="zsh 命令自动建议插件"
    [zsh-completions]="zsh 额外补全规则"
    [zsh-syntax-highlighting]="zsh 语法高亮插件"
    [rsync]="增量文件同步工具（Homebrew 新版）"
    [7z]="7-Zip 压缩工具（命令为 7zz）"
    [unar]="通用解压工具"
    [JetbrainsMonoNerdFont]="JetBrains Mono Nerd Font 字体"
    [fzf]="模糊查找工具"
    [starship]="跨 Shell 提示符"
    [eza]="ls 现代替代（原 exa）"
    [fd]="find 现代替代"
    [bat]="cat 现代替代（语法高亮）"
    [rg]="ripgrep，grep 现代替代"
    [zoxide]="cd 智能跳转"
    [yazi]="终端文件管理器"
    [btop]="系统资源监控"
    [git]="版本控制（Homebrew 新版）"
    [lazygit]="Git TUI 客户端"
    [uv]="Python 包管理器（Rust 实现）"
    [fnm]="Node.js 版本管理器"
    [rustup]="Rust 工具链管理器"
    [nvim]="Neovim 编辑器"
    [lazyvim]="LazyVim Neovim 配置"
    [mise]="多语言版本管理器"
    [direnv]="目录级环境变量"
)

# ============ 安装函数 ============

# Homebrew 公式名与脚本内工具名不一致时在这里映射
pkg_name() {
    case "$1" in
        rg)   echo "ripgrep" ;;
        nvim) echo "neovim" ;;
        7z)   echo "sevenzip" ;;
        *)    echo "$1" ;;
    esac
}

# 通过 Homebrew 安装一个公式（已安装则跳过）
install_brew_tool() {
    local tool="$1"
    local formula
    formula=$(pkg_name "$tool")

    if brew_has "$formula"; then
        info "$tool 已安装，跳过"
        return 0
    fi

    info "通过 Homebrew 安装 $tool ($formula) ..."
    brew_install "$formula"
}

# --- bash ---

install_bash() {
    install_brew_tool "bash"
}

# --- zsh ---

install_zsh() {
    install_brew_tool "zsh"
}

# --- ohmyzsh ---

install_ohmyzsh() {
    # 仅靠目录判断不可靠：custom/plugins 可能是先克隆的插件留下的空壳
    if [[ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]]; then
        info "ohmyzsh 已安装，跳过"
        return 0
    fi
    if ! command -v zsh >/dev/null 2>&1; then
        warn "未检测到 zsh，将先安装 zsh"
        install_zsh
    fi
    info "安装 Oh My Zsh ..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || {
        warn "在线安装失败，尝试备用方式"
        if command -v wget >/dev/null 2>&1; then
            sh -c "$(wget -qO- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        fi
    }
}

# --- zsh 插件 ---

install_zsh_plugin() {
    local plugin_name="$1"
    local repo_url="$2"
    local dest="$HOME/.oh-my-zsh/custom/plugins/$plugin_name"

    if [[ -d "$dest" ]]; then
        info "$plugin_name 已安装，跳过"
        return 0
    fi

    if [[ ! -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]]; then
        warn "未检测到 ohmyzsh，将先安装 ohmyzsh"
        install_ohmyzsh
    fi

    info "安装 zsh 插件 $plugin_name ..."
    git clone --depth=1 "$repo_url" "$dest"
}

# 函数名统一用下划线：install_tool 通过 install_${tool//-/_} 查找

install_zsh_autosuggestions() {
    install_zsh_plugin "zsh-autosuggestions" \
        "https://github.com/zsh-users/zsh-autosuggestions"
}

install_zsh_completions() {
    install_zsh_plugin "zsh-completions" \
        "https://github.com/zsh-users/zsh-completions"
}

install_zsh_syntax_highlighting() {
    install_zsh_plugin "zsh-syntax-highlighting" \
        "https://github.com/zsh-users/zsh-syntax-highlighting"
}

# --- 压缩工具 ---

install_rsync() {
    install_brew_tool "rsync"
}

# --- 7z ---

install_7z() {
    if command -v 7zz >/dev/null 2>&1; then
        info "7z (7zz) 已安装，跳过"
        return 0
    fi
    install_brew_tool "7z"
}

install_unar() {
    install_brew_tool "unar"
}

# --- Nerd Font ---

install_JetbrainsMonoNerdFont() {
    local cask="font-jetbrains-mono-nerd-font"

    if ! brew_has_cask "$cask"; then
        info "通过 Homebrew 安装 JetBrainsMono Nerd Font ..."
        brew_install_cask "$cask"
    else
        info "JetBrainsMonoNerdFont 已安装，跳过安装"
    fi

    unquarantine_nerd_font

    info "JetBrainsMonoNerdFont 安装完成"
}

# Homebrew cask 下载的字体可能带 com.apple.quarantine 属性，
# 被隔离的字体不会被 macOS 自动注册（Font Book 与终端都看不到）。
# 清除属性后重启 fontd 触发重新注册；仅对被隔离的文件计数。
unquarantine_nerd_font() {
    local font removed=0
    shopt -s nullglob
    for font in "$HOME"/Library/Fonts/JetBrainsMonoNerdFont*.ttf; do
        if xattr -d com.apple.quarantine "$font" 2>/dev/null; then
            removed=$((removed + 1))
        fi
    done
    shopt -u nullglob

    if (( removed > 0 )); then
        info "已清除 $removed 个字体的 quarantine 属性，重启 fontd 刷新注册"
        killall fontd 2>/dev/null || true
        sleep 1
    fi
}

# --- CLI 工具 ---

install_fzf()        { install_brew_tool "fzf"; }
install_starship()   { install_brew_tool "starship"; }
install_eza()        { install_brew_tool "eza"; }
install_fd()         { install_brew_tool "fd"; }
install_bat()        { install_brew_tool "bat"; }
install_rg()         { install_brew_tool "rg"; }
install_zoxide()     { install_brew_tool "zoxide"; }
install_yazi()       { install_brew_tool "yazi"; }
install_btop()       { install_brew_tool "btop"; }
install_git()        { install_brew_tool "git"; }
install_lazygit()    { install_brew_tool "lazygit"; }
install_nvim()       { install_brew_tool "nvim"; }
install_mise()       { install_brew_tool "mise"; }
install_direnv()     { install_brew_tool "direnv"; }
install_uv()         { install_brew_tool "uv"; }
install_fnm()        { install_brew_tool "fnm"; }

# --- rustup ---
# Homebrew 的 rustup 公式只提供 rustup 二进制，不安装工具链，
# 因此这里使用官方安装脚本，得到 rustup + 默认 stable 工具链。

install_rustup() {
    if command -v rustup >/dev/null 2>&1; then
        info "rustup 已安装，跳过"
        return 0
    fi
    info "安装 rustup（官方脚本，包含 stable 工具链）..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
    source "$HOME/.cargo/env" 2>/dev/null || true
    info "rustup 安装完成，PATH 由 ~/.zshrc 中的 ~/.cargo/env 提供"
}

# --- lazyvim ---

install_lazyvim() {
    local nvim_config="$HOME/.config/nvim"

    if [[ -d "$nvim_config" ]]; then
        # 检查是否已经是 lazyvim
        if [[ -f "$nvim_config/lazy-lock.json" ]] || grep -q "lazy.nvim" "$nvim_config/init.lua" 2>/dev/null; then
            info "LazyVim 已安装，跳过"
            return 0
        fi
        warn "检测到已有 neovim 配置，备份到 $nvim_config.backup.$(date +%s)"
        mv "$nvim_config" "$nvim_config.backup.$(date +%s)"
    fi

    if ! command -v nvim >/dev/null 2>&1; then
        warn "未检测到 nvim，将先安装 nvim"
        install_nvim
    fi

    if ! command -v git >/dev/null 2>&1; then
        warn "未检测到 git，将先安装 git"
        install_git
    fi

    info "克隆 LazyVim starter ..."
    git clone https://github.com/LazyVim/starter "$nvim_config"
    rm -rf "$nvim_config/.git"

    info "初始化 LazyVim 插件 ..."
    nvim --headless "+Lazy! sync" +qa 2>/dev/null || {
        warn "自动同步插件失败，请在首次打开 nvim 时等待插件自动安装"
    }

    info "LazyVim 安装完成"
}

# ============ 安装调度 ============

install_tool() {
    local tool="$1"
    step "安装 $tool (${SW_DESC[$tool]:-})"

    # 检查是否有对应的安装函数
    local func_name="install_${tool//-/_}"
    if declare -f "$func_name" >/dev/null 2>&1; then
        "$func_name"
    else
        # 默认尝试 Homebrew 安装
        install_brew_tool "$tool"
    fi
}

# ============ 入口 ============

list_software() {
    printf '\n%b默认安装列表：%b\n' "$BOLD" "$NC"
    local sw
    for sw in "${DEFAULT_SOFTWARE[@]}"; do
        printf '  %s%s%s (%s)\n' "$GREEN" "$sw" "$NC" "${SW_DESC[$sw]:-}"
    done

    printf '\n%b可选安装列表：%b\n' "$BOLD" "$NC"
    for sw in "${OPTIONAL_SOFTWARE[@]}"; do
        printf '  %s%s%s (%s)\n' "$YELLOW" "$sw" "$NC" "${SW_DESC[$sw]:-}"
    done
    printf '\n'
}

usage() {
    cat <<EOF
软件安装脚本（macOS / Homebrew）

用法: $0 [软件名 ...]

不带参数时进入交互式菜单；带软件名参数时直接安装（支持逗号或空格分隔）。

示例:
  $0                 交互式选择
  $0 nvim eza        直接安装 nvim 和 eza
  $0 nvim,eza        同上
  $0 --list          列出所有可用软件
EOF
}

run_install_software() {
    local tools=()

    if (( $# > 0 )); then
        parse_item_args "$@"
        tools=("${PARSED_ITEMS[@]}")
    else
        # 交互式选择
        local all_software=("${DEFAULT_SOFTWARE[@]}" "${OPTIONAL_SOFTWARE[@]}")
        mapfile -t tools < <(show_checkbox "选择要安装的软件（默认全部选中）" "default" SW_DESC "${all_software[@]}")
    fi

    if [[ ${#tools[@]} -eq 0 ]]; then
        info "未选择任何软件"
        return 0
    fi

    init_environment
    ensure_brew

    step "更新 Homebrew 包索引"
    brew_update

    step "开始安装软件 (${#tools[@]} 个)"
    local sw
    for sw in "${tools[@]}"; do
        install_tool "$sw"
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        -h|--help)
            usage
            ;;
        --list)
            list_software
            ;;
        "")
            run_install_software
            ;;
        *)
            run_install_software "$@"
            ;;
    esac
fi
