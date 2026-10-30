#!/usr/bin/env bash

# 系统设置脚本（macOS）：终端字体与透明度、系统语言
#
# 用法：
#   ./setup-system.sh                    交互式选择要执行的任务
#   ./setup-system.sh terminal locale    直接执行指定任务
#   ./setup-system.sh terminal,locale    同上，支持逗号分隔
#   ./setup-system.sh --list             列出所有任务
#   ./setup-system.sh -h                 查看帮助
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

# ============ 任务定义 ============

SYSTEM_TASKS=(
    "terminal" "locale"
)

declare -A SYSTEM_TASK_DESC=(
    [terminal]="终端字体 JetBrainsMono Nerd Font，透明度 80%"
    [locale]="系统语言设置为简体中文（zh-Hans）"
)

# --- 终端字体与透明度 ---

init_terminal() {
    info "配置终端：字体 JetBrainsMono Nerd Font，透明度 80%"

    local current_term="${TERM_PROGRAM:-}"
    local configured=0

    # iTerm2：写入 dynamic profile（重启后可在 Profiles 中选择）
    if [[ -d "/Applications/iTerm.app" || "$current_term" == "iTerm2" ]]; then
        local profile_dir="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
        mkdir -p "$profile_dir"
        cat > "$profile_dir/scripts-toolbox.json" <<'EOF'
{
  "Profiles": [
    {
      "Name": "scripts-toolbox",
      "Guid": "scripts-toolbox-dynamic",
      "Normal Font": "JetBrainsMonoNF-Regular 14",
      "Transparency": 0.2,
      "Blur": true,
      "Blur Radius": 20
    }
  ]
}
EOF
        info "iTerm2 dynamic profile 已写入: $profile_dir/scripts-toolbox.json"
        warn "重启 iTerm2 后在 Settings → Profiles 选择 scripts-toolbox；字体不生效时手动选择 JetBrainsMono Nerd Font"
        configured=1
    fi

    # Alacritty
    local alacritty_config="$HOME/.config/alacritty/alacritty.toml"
    if [[ -d "$HOME/.config/alacritty" ]] || [[ "$current_term" == "Alacritty" ]]; then
        info "检测到 Alacritty，写入配置 ..."
        mkdir -p "$HOME/.config/alacritty"
        cat > "$alacritty_config" <<'EOF'
[font.normal]
family = "JetBrainsMono Nerd Font"

[window]
opacity = 0.8
EOF
        info "Alacritty 配置已写入 $alacritty_config"
        configured=1
    fi

    # Kitty
    local kitty_config="$HOME/.config/kitty/kitty.conf"
    if [[ -d "$HOME/.config/kitty" ]] || [[ "$current_term" == "kitty" ]]; then
        info "检测到 Kitty，写入配置 ..."
        mkdir -p "$HOME/.config/kitty"
        cat > "$kitty_config" <<'EOF'
font_family JetBrainsMono Nerd Font
background_opacity 0.8
EOF
        info "Kitty 配置已写入 $kitty_config"
        configured=1
    fi

    # Terminal.app：配置文件为二进制 plist，无法安全脚本化，给出手动步骤
    if [[ "$current_term" == "Apple_Terminal" ]]; then
        warn "Terminal.app 需要手动设置："
        warn "  Settings → Profiles → Text → Font 选择 JetBrainsMono Nerd Font 12"
        warn "  Settings → Profiles → Window → Background 调整不透明度为 80%"
    fi

    # 没有检测到可自动配置的终端时，给出提示
    if (( configured == 0 )) && [[ "$current_term" != "Apple_Terminal" ]]; then
        warn "未能自动识别终端类型，请手动设置字体与透明度"
        warn "字体名称: JetBrainsMono Nerd Font"
        warn "透明度: 80%（即 opacity 0.8 或 transparency 20%）"
    fi
}

# --- 系统语言 ---

init_locale() {
    info "设置系统语言为简体中文（zh-Hans）"

    defaults write -g AppleLanguages -array "zh-Hans" "en"
    defaults write -g AppleLocale -string "zh_CN"

    info "系统语言已设置为简体中文"
    warn "重新登录（或重启）后生效；登录界面等系统级语言仍需在系统设置中修改"
}

# ============ 入口 ============

run_system_task() {
    local task="$1"
    step "系统设置: ${SYSTEM_TASK_DESC[$task]:-$task}"
    local func_name="init_${task}"
    if declare -f "$func_name" >/dev/null 2>&1; then
        "$func_name"
    else
        error "未知的系统设置任务: $task"
        return 1
    fi
}

list_system_tasks() {
    printf '\n%b系统设置任务：%b\n' "$BOLD" "$NC"
    local task
    for task in "${SYSTEM_TASKS[@]}"; do
        printf '  %s%s%s (%s)\n' "$CYAN" "$task" "$NC" "${SYSTEM_TASK_DESC[$task]:-}"
    done
    printf '\n'
}

usage() {
    cat <<EOF
系统设置脚本（macOS）

用法: $0 [任务 ...]

不带参数时进入交互式菜单；带任务名参数时直接执行（支持逗号或空格分隔）。

可用任务:
  terminal      终端字体 JetBrainsMono Nerd Font，透明度 80%
  locale        系统语言设置为简体中文（zh-Hans）

示例:
  $0                  交互式选择
  $0 terminal locale  直接执行指定任务
  $0 --list           列出所有任务
EOF
}

run_setup_system() {
    local tasks=()

    if (( $# > 0 )); then
        parse_item_args "$@"
        tasks=("${PARSED_ITEMS[@]}")
    else
        mapfile -t tasks < <(show_checkbox "选择系统设置任务（默认全部选中）" "default" SYSTEM_TASK_DESC "${SYSTEM_TASKS[@]}")
    fi

    if [[ ${#tasks[@]} -eq 0 ]]; then
        info "未选择任何任务"
        return 0
    fi

    init_environment

    local task
    for task in "${tasks[@]}"; do
        run_system_task "$task"
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        -h|--help)
            usage
            ;;
        --list)
            list_system_tasks
            ;;
        "")
            run_setup_system
            ;;
        *)
            run_setup_system "$@"
            ;;
    esac
fi
