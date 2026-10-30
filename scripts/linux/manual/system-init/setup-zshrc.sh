#!/usr/bin/env bash

# zshrc 初始化脚本：写入 Linux 版 ~/.zshrc 并将 zsh 设为默认 Shell
#
# 用法：
#   ./setup-zshrc.sh    初始化 ~/.zshrc
#   ./setup-zshrc.sh -h 查看帮助
#
# 被 source 时仅提供函数，不执行 main。

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

# --- zshrc 初始化 ---

# 写入 Linux 版 ~/.zshrc（参考个人配置模板，去掉 macOS 专属内容）
init_zshrc() {
    local zshrc="$HOME/.zshrc"

    if [[ -f "$zshrc" ]]; then
        local backup="$zshrc.backup.$(date +%Y%m%d%H%M%S)"
        warn "已存在 ~/.zshrc，备份到 $backup"
        cp "$zshrc" "$backup"
    fi

    info "写入 ~/.zshrc ..."
    cat > "$zshrc" <<'EOF'
# ~/.zshrc — 由 system-init.sh 生成

# omz 配置加载
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git zoxide uv rsync sudo zsh-autosuggestions zsh-completions zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh

# fnm
command -v fnm >/dev/null 2>&1 && eval "$(fnm env --use-on-cd --shell zsh)"

# direnv（可选安装）
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"

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

# 确保 ~/.local/bin 在 PATH 中
export PATH="$HOME/.local/bin:$PATH"
EOF

    # zsh 插件通过 omz custom plugins 目录加载，无需额外 source；
    # 这里仅提示需要哪些插件
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
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

    # 设置 zsh 为默认 Shell
    if [[ "${SHELL:-}" != "$(command -v zsh)" ]]; then
        if ! command -v zsh >/dev/null 2>&1; then
            warn "未检测到 zsh，跳过设置默认 Shell"
            return 0
        fi
        info "设置 zsh 为默认 Shell ..."
        if ! grep -qx "$(command -v zsh)" /etc/shells; then
            echo "$(command -v zsh)" | sudo tee -a /etc/shells >/dev/null
        fi
        chsh -s "$(command -v zsh)" || warn "chsh 失败，请手动执行: chsh -s \$(which zsh)"
    else
        info "默认 Shell 已是 zsh"
    fi

    info "~/.zshrc 初始化完成"
}

# ============ 入口 ============

usage() {
    cat <<EOF
zshrc 初始化脚本

用法: $0

写入 Linux 版 ~/.zshrc（已有文件先备份），并将 zsh 设为默认 Shell。
依赖 ohmyzsh 和三个 zsh 插件（可通过 install-software.sh 安装）。
EOF
}

run_setup_zshrc() {
    check_not_sudo
    check_sudo
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
