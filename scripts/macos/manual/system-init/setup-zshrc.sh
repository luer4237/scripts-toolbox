#!/usr/bin/env bash

# zshrc 初始化脚本（macOS）：写入 macOS 版 ~/.zshrc 并将 zsh 设为默认 Shell
#
# 用法：
#   ./setup-zshrc.sh    初始化 ~/.zshrc
#   ./setup-zshrc.sh -h 查看帮助
#
# 被 source 时仅提供函数，不执行 main。

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

# --- zshrc 初始化 ---

# 写入 macOS 版 ~/.zshrc（保留 Homebrew 与 omz macos 插件，去掉 Linux 专属内容）
init_zshrc() {
    local zshrc="$HOME/.zshrc"

    if [[ -f "$zshrc" ]]; then
        local backup="$zshrc.backup.$(date +%Y%m%d%H%M%S)"
        warn "已存在 ~/.zshrc，备份到 $backup"
        cp "$zshrc" "$backup"
    fi

    info "写入 ~/.zshrc ..."
    cat > "$zshrc" <<'EOF'
# ~/.zshrc — 由 macOS system-init.sh 生成

# Homebrew 环境（Apple Silicon 在 /opt/homebrew，Intel 在 /usr/local）
if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

# omz 配置加载（ohmyzsh 未装好时不中断 Shell 启动）
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git zoxide uv rsync sudo macos zsh-autosuggestions zsh-completions zsh-syntax-highlighting)
if [[ -f "$ZSH/oh-my-zsh.sh" ]]; then
    source "$ZSH/oh-my-zsh.sh"
else
    echo "提示: 未找到 $ZSH/oh-my-zsh.sh，请运行 install-software.sh ohmyzsh" >&2
fi

# fnm
command -v fnm >/dev/null 2>&1 && eval "$(fnm env --use-on-cd --shell zsh)"

# direnv（可选安装）
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"

# Rust 工具链（rustup 官方脚本安装）
if [[ -f "$HOME/.cargo/env" ]]; then
    source "$HOME/.cargo/env"
fi

# 自动加载 ~/.my_scripts 下的脚本（递归，跳过 manual/ 目录与加载器自身）
# 与 scripts-toolbox/scripts/cross-platform/auto/loader/load-my-scripts.zsh 保持一致
if [[ -d "$HOME/.my_scripts" ]]; then
    for _my_script in "$HOME/.my_scripts"/**/*.{sh,zsh}(N); do
        case "$_my_script" in
            */manual/*) continue ;;
            */load-my-scripts.*) continue ;;
        esac
        [[ -f "$_my_script" ]] || continue
        source "$_my_script"
    done
    unset _my_script
fi

# fzf
command -v fzf >/dev/null 2>&1 && source <(fzf --zsh)

# starship
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"

# mise
command -v mise >/dev/null 2>&1 && eval "$(mise activate zsh)"
EOF

    # zsh 插件通过 omz custom plugins 目录加载，无需额外 source；
    # 这里仅提示需要哪些插件
    if [[ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]]; then
        local plugin dest
        for plugin in zsh-autosuggestions zsh-completions zsh-syntax-highlighting; do
            dest="$HOME/.oh-my-zsh/custom/plugins/$plugin"
            if [[ ! -d "$dest" ]]; then
                warn "缺少 zsh 插件 $plugin，请通过 install-software.sh 安装后重跑"
            fi
        done
    else
        warn "未检测到 ohmyzsh，请先通过 install-software.sh 安装 ohmyzsh"
    fi

    info "~/.zshrc 初始化完成"

    # 设置 zsh 为默认 Shell：优先使用 Homebrew zsh
    detect_brew
    local zsh_bin=""
    if [[ -n "$BREW_BIN" ]] && brew_has "zsh"; then
        zsh_bin="$("$BREW_BIN" --prefix)/bin/zsh"
    elif [[ -x /bin/zsh ]]; then
        zsh_bin="/bin/zsh"
    fi

    if [[ -z "$zsh_bin" ]]; then
        warn "未检测到 zsh，跳过设置默认 Shell"
        return 0
    fi

    if [[ "${SHELL:-}" == "$zsh_bin" ]]; then
        info "默认 Shell 已是 $zsh_bin"
        return 0
    fi

    info "设置默认 Shell 为 $zsh_bin ..."
    if ! grep -qxF "$zsh_bin" /etc/shells; then
        if ! printf '%s\n' "$zsh_bin" | sudo tee -a /etc/shells >/dev/null; then
            warn "写入 /etc/shells 失败，请手动执行: sudo sh -c 'echo $zsh_bin >> /etc/shells'"
            return 0
        fi
    fi

    chsh -s "$zsh_bin" || warn "chsh 失败，请手动执行: chsh -s $zsh_bin"
}

# ============ 入口 ============

usage() {
    cat <<EOF
zshrc 初始化脚本（macOS）

用法: $0

写入 macOS 版 ~/.zshrc（已有文件先备份），并将 zsh 设为默认 Shell。
依赖 ohmyzsh 和三个 zsh 插件（可通过 install-software.sh 安装）。
EOF
}

run_setup_zshrc() {
    init_environment
    init_zshrc
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        -h|--help)
            usage
            ;;
        "")
            run_setup_zshrc
            ;;
        *)
            error "未知参数: $1"
            usage
            exit 1
            ;;
    esac
fi
