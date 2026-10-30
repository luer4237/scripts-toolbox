#!/usr/bin/env bash

# SSH 初始化脚本（macOS）：写入 ~/.ssh/config 全局配置块（连接复用与 Keepalive）
#
# 用法：
#   ./setup-ssh.sh            安装或更新 ~/.ssh/config 中的全局配置块（默认）
#   ./setup-ssh.sh remove     移除脚本写入的配置块
#   ./setup-ssh.sh status     查看配置块安装状态
#   ./setup-ssh.sh -h         查看帮助
#
# 在 ~/.ssh/config 中写入由标记包围的 Host * 配置块，并创建
# ~/.ssh/controlmasters 目录存放连接复用套接字。
# 重复执行会原地更新配置块，不影响 config 中的其他内容。
#
# 被 source 时仅提供 init_ssh 函数，不执行 main。

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

# ============ 配置 ============

SSH_DIR="${SSH_INIT_SSH_DIR:-$HOME/.ssh}"
SSH_CONFIG="$SSH_DIR/config"
CONTROL_DIR="$SSH_DIR/controlmasters"

BLOCK_BEGIN="# >>> scripts-toolbox ssh-init >>>"
BLOCK_END="# <<< scripts-toolbox ssh-init <<<"

# ==================================

TMP_BLOCK=""
cleanup() {
    if [[ -n "$TMP_BLOCK" ]]; then
        rm -f "$TMP_BLOCK"
    fi
}

# 输出带标记的配置块，ControlPath 使用展开后的绝对路径。
# UseKeychain 为 macOS 专有选项，用于把私钥口令保存在钥匙串。
block_file() {
    cat <<EOF
$BLOCK_BEGIN
Host *
  AddKeysToAgent yes
  UseKeychain yes
  IdentitiesOnly yes
  ServerAliveInterval 60
  ServerAliveCountMax 3
  ControlMaster auto
  ControlPath $SSH_DIR/controlmasters/%r@%n
  ControlPersist 10m
$BLOCK_END
EOF
}

has_block() {
    [[ -f "$SSH_CONFIG" ]] && grep -qF "$BLOCK_BEGIN" "$SSH_CONFIG"
}

backup_config() {
    local ts
    ts="$(date +%Y%m%d%H%M%S)"
    cp -p "$SSH_CONFIG" "$SSH_CONFIG.bak.$ts"
    info "已备份原配置到 $SSH_CONFIG.bak.$ts"
}

ensure_dirs() {
    mkdir -p "$SSH_DIR" "$CONTROL_DIR"
    chmod 700 "$SSH_DIR" "$CONTROL_DIR"
}

# 1. 原文件中以 BEGIN 标记开头的内容替换为配置块文件全部内容；
# 2. 跳过原文件中直到 END 标记的部分（END 不再输出，标记由配置块自带）。
replace_block() {
    local tmp
    tmp="$(mktemp)"
    awk -v begin="$BLOCK_BEGIN" -v end="$BLOCK_END" -v block="$TMP_BLOCK" '
        $0 == begin {
            while ((getline line < block) > 0) print line
            close(block)
            skip = 1
            next
        }
        skip && $0 == end { skip = 0; next }
        skip { next }
        { print }
    ' "$SSH_CONFIG" > "$tmp"
    mv "$tmp" "$SSH_CONFIG"
}

# 删除 BEGIN 到 END 之间的整块内容（含标记本身）。
delete_block() {
    local tmp
    tmp="$(mktemp)"
    awk -v begin="$BLOCK_BEGIN" -v end="$BLOCK_END" '
        $0 == begin { skip = 1; next }
        skip && $0 == end { skip = 0; next }
        skip { next }
        { print }
    ' "$SSH_CONFIG" > "$tmp"
    mv "$tmp" "$SSH_CONFIG"
}

install_block() {
    ensure_dirs
    TMP_BLOCK="$(mktemp)"
    block_file > "$TMP_BLOCK"

    if [[ ! -f "$SSH_CONFIG" ]]; then
        block_file > "$SSH_CONFIG"
        chmod 600 "$SSH_CONFIG"
        info "已创建 $SSH_CONFIG 并写入配置块"
        return 0
    fi

    if has_block; then
        replace_block
        chmod 600 "$SSH_CONFIG"
        info "已更新 $SSH_CONFIG 中的配置块"
        return 0
    fi

    if [[ "${FORCE:-0}" != "1" ]]; then
        warn "$SSH_CONFIG 已存在且不包含本脚本标记，未做任何修改。"
        warn "确认与现有配置无冲突后，可执行 FORCE=1 $0 备份并追加配置块。"
        return 1
    fi

    backup_config
    block_file >> "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"
    info "已在 $SSH_CONFIG 末尾追加配置块"
}

remove_block() {
    if ! has_block; then
        warn "未在 $SSH_CONFIG 中发现配置块，无需移除"
        return 0
    fi

    backup_config
    delete_block
    chmod 600 "$SSH_CONFIG"
    info "已从 $SSH_CONFIG 移除配置块"
}

show_status() {
    if has_block; then
        info "配置块已安装于 $SSH_CONFIG"
    else
        warn "配置块未安装（$SSH_CONFIG）"
        return 1
    fi

    if [[ -d "$CONTROL_DIR" ]]; then
        info "连接复用目录存在：$CONTROL_DIR"
    else
        warn "连接复用目录不存在：$CONTROL_DIR（执行 install 会自动创建）"
    fi
}

# ============ 主脚本调度入口 ============

# 供 system-init.sh 调用：安装或更新 SSH 全局配置块
init_ssh() {
    install_block
}

# ============ 入口 ============

usage() {
    cat <<EOF
SSH 初始化脚本（macOS）

用法: $0 [命令]

命令：
  install     安装或更新全局配置块（默认）
  remove      移除脚本写入的配置块
  status      查看配置块安装状态
  -h, --help  查看帮助

写入的配置块：
$(block_file | sed 's/^/  /')

默认写入 ~/.ssh/config，可通过 SSH_INIT_SSH_DIR 指定其他 SSH 目录。
EOF
}

run_setup_ssh() {
    case "${1:-install}" in
        -h|--help) usage ;;
        install) install_block ;;
        remove) remove_block ;;
        status) show_status ;;
        *)
            usage >&2
            return 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    trap cleanup EXIT
    run_setup_ssh "$@"
fi
