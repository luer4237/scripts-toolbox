#!/usr/bin/env bash

# 系统设置脚本：终端外观、系统语言、家目录英文目录
#
# 用法：
#   ./setup-system.sh                    交互式选择要执行的任务
#   ./setup-system.sh terminal locale    直接执行指定任务
#   ./setup-system.sh terminal,locale    同上，支持逗号分隔
#   ./setup-system.sh --list             列出所有任务
#   ./setup-system.sh -h                 查看帮助
#
# 被 source 时仅提供函数和数据，不执行 main。

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

# ============ 任务定义 ============

SYSTEM_TASKS=(
    "terminal" "locale" "home_dirs" "input_method"
)

declare -A SYSTEM_TASK_DESC=(
    [terminal]="终端透明度 80%，字体 JetBrainsMonoNerdFont"
    [locale]="系统语言设置为中文（zh_CN.UTF-8）"
    [home_dirs]="家目录下载等目录名设为英文"
    [input_method]="中文输入法（fcitx5 + Rime 雾凇拼音）"
)

# --- 终端透明度与字体 ---

init_terminal() {
    info "配置终端：透明度 80%，字体 JetBrainsMono Nerd Font"

    local current_term="${TERM_PROGRAM:-${XDG_CURRENT_DESKTOP:-}}"

    # 尝试 GNOME Terminal
    if command -v gsettings >/dev/null 2>&1; then
        # 检查是否有 GNOME Terminal 的 schema
        if gsettings list-schemas 2>/dev/null | grep -q "org.gnome.Terminal"; then
            info "检测到 GNOME Terminal，配置中 ..."
            local profile_list_schema="org.gnome.Terminal.ProfilesList"
            local profile_schema="org.gnome.Terminal.Legacy.Profile"

            # 获取默认 profile UUID
            local profile_uuid
            profile_uuid=$(gsettings get "$profile_list_schema" default 2>/dev/null | tr -d "'")

            if [[ -n "$profile_uuid" ]]; then
                local profile_path="/org/gnome/terminal/legacy/profiles:/:${profile_uuid}"

                # 设置字体
                gsettings set "$profile_schema:$profile_path" use-system-font false 2>/dev/null || true
                gsettings set "$profile_schema:$profile_path" font 'JetBrainsMono Nerd Font 12' 2>/dev/null || true

                # 设置透明度（新版 GNOME Terminal 可能不支持）
                if gsettings list-keys "$profile_schema:$profile_path" 2>/dev/null | grep -q "use-transparent-background"; then
                    gsettings set "$profile_schema:$profile_path" use-transparent-background true
                    gsettings set "$profile_schema:$profile_path" background-transparency-percent 20
                    info "GNOME Terminal 透明度和字体已设置"
                else
                    warn "当前 GNOME Terminal 版本不支持透明度设置，已设置字体"
                    warn "如需透明度，可使用 Terminator / Tilix / Alacritty / Kitty 等终端"
                fi
            else
                warn "无法获取 GNOME Terminal 默认 profile"
            fi
        else
            warn "未检测到 GNOME Terminal schema"
        fi
    fi

    # 尝试 Alacritty
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
    fi

    # 尝试 Kitty
    local kitty_config="$HOME/.config/kitty/kitty.conf"
    if [[ -d "$HOME/.config/kitty" ]] || [[ "$current_term" == "kitty" ]]; then
        info "检测到 Kitty，写入配置 ..."
        mkdir -p "$HOME/.config/kitty"
        cat > "$kitty_config" <<'EOF'
font_family JetBrainsMono Nerd Font
background_opacity 0.8
EOF
        info "Kitty 配置已写入 $kitty_config"
    fi

    # 如果没有检测到任何终端，给出提示
    if ! command -v gsettings >/dev/null 2>&1 && [[ ! -d "$HOME/.config/alacritty" ]] && [[ ! -d "$HOME/.config/kitty" ]]; then
        warn "无法自动检测终端类型，请手动设置透明度和字体"
        warn "字体名称: JetBrainsMono Nerd Font"
        warn "透明度: 80%（即 opacity 0.8 或 transparency 20%）"
    fi
}

# --- 系统语言 ---

init_locale() {
    info "设置系统语言为中文（zh_CN.UTF-8）"

    case "$PKG_MANAGER" in
        apt)
            # 确保中文 locale 已生成
            if ! locale -a 2>/dev/null | grep -qi "zh_CN.utf8\|zh_CN.UTF-8"; then
                info "生成 zh_CN.UTF-8 locale ..."
                if [[ -f /etc/locale.gen ]]; then
                    sudo sed -i 's/^# *zh_CN.UTF-8/zh_CN.UTF-8/' /etc/locale.gen
                    sudo locale-gen zh_CN.UTF-8
                else
                    sudo locale-gen zh_CN.UTF-8
                fi
            fi
            ;;
        pacman)
            if ! locale -a 2>/dev/null | grep -qi "zh_CN.utf8\|zh_CN.UTF-8"; then
                info "生成 zh_CN.UTF-8 locale ..."
                sudo sed -i 's/^#zh_CN.UTF-8/zh_CN.UTF-8/' /etc/locale.gen
                sudo locale-gen
            fi
            ;;
        dnf|zypper)
            if ! locale -a 2>/dev/null | grep -qi "zh_CN.utf8\|zh_CN.UTF-8"; then
                info "安装中文 locale 包 ..."
                case "$PKG_MANAGER" in
                    dnf)  sudo dnf install -y glibc-langpack-zh ;;
                    zypper) sudo zypper install -y glibc-locale ;;
                esac
            fi
            ;;
    esac

    # 设置系统 locale
    sudo localectl set-locale LANG=zh_CN.UTF-8 2>/dev/null || {
        warn "localectl 设置失败，尝试直接写入 /etc/default/locale"
        echo "LANG=zh_CN.UTF-8" | sudo tee /etc/default/locale >/dev/null
    }

    # 用户级 locale 也设置一下
    if [[ -f "$HOME/.config/locale.conf" ]]; then
        echo "LANG=zh_CN.UTF-8" > "$HOME/.config/locale.conf"
    fi

    info "系统语言已设置为 zh_CN.UTF-8"
    warn "请重新登录或执行 'source /etc/default/locale' 使设置生效"
}

# --- 家目录英文目录 ---

init_home_dirs() {
    info "设置家目录下下载等目录为英文名"

    # 检查 xdg-user-dirs-update 是否可用
    if ! command -v xdg-user-dirs-update >/dev/null 2>&1; then
        pkg_install xdg-user-dirs
    fi

    # 常见中文目录名 -> 英文名映射
    declare -a dir_from=("下载" "桌面" "文档" "图片" "音乐" "视频" "公共" "模板")
    declare -a dir_to=("Downloads" "Desktop" "Documents" "Pictures" "Music" "Videos" "Public" "Templates")

    # 重命名现有中文目录
    for i in "${!dir_from[@]}"; do
        local from="${dir_from[$i]}" to="${dir_to[$i]}"
        if [[ -d "$HOME/$from" && ! -d "$HOME/$to" ]]; then
            mv "$HOME/$from" "$HOME/$to"
            info "重命名: ~/$from -> ~/$to"
        elif [[ -d "$HOME/$from" && -d "$HOME/$to" ]]; then
            warn "~/$from 和 ~/$to 都存在，保留 ~/$to，手动迁移 ~/$from 的内容"
        fi
    done

    # 更新 user-dirs 配置为英文
    local user_dirs_conf="$HOME/.config/user-dirs.dirs"
    mkdir -p "$HOME/.config"

    cat > "$user_dirs_conf" <<'EOF'
# 英文目录名配置
XDG_DESKTOP_DIR="$HOME/Desktop"
XDG_DOWNLOAD_DIR="$HOME/Downloads"
XDG_TEMPLATES_DIR="$HOME/Templates"
XDG_PUBLICSHARE_DIR="$HOME/Public"
XDG_DOCUMENTS_DIR="$HOME/Documents"
XDG_MUSIC_DIR="$HOME/Music"
XDG_PICTURES_DIR="$HOME/Pictures"
XDG_VIDEOS_DIR="$HOME/Videos"
EOF

    # 禁用自动重命名（防止重启后恢复为中文）
    # 值需与系统 locale 一致，否则 xdg-user-dirs-update 会因语言变更而重新创建目录
    local user_dirs_locale="$HOME/.config/user-dirs.locale"
    echo "zh_CN.UTF-8" > "$user_dirs_locale" 2>/dev/null || true

    # 确保英文目录存在，防止应用因目录缺失而回退创建
    mkdir -p "$HOME/Desktop" "$HOME/Downloads" "$HOME/Templates" "$HOME/Public" \
             "$HOME/Documents" "$HOME/Music" "$HOME/Pictures" "$HOME/Videos"

    info "家目录已设置为英文名"
    info "配置文件: $user_dirs_conf"
}

# --- 中文输入法（fcitx5 + Rime 雾凇拼音） ---

init_input_method() {
    info "安装中文输入法：fcitx5 + Rime（雾凇拼音）"

    # 1. 安装 fcitx5 框架与 Rime 插件
    case "$PKG_MANAGER" in
        apt)
            # librime-bin 提供 rime_deployer，用于预构建词库
            pkg_install fcitx5 fcitx5-rime librime-bin
            # Debian 系设置用户默认输入法框架（写 ~/.xinputrc）
            if command -v im-config >/dev/null 2>&1; then
                im-config -n fcitx5
            fi
            ;;
        dnf|zypper)
            pkg_install fcitx5 fcitx5-rime fcitx5-configtool
            ;;
        pacman)
            pkg_install fcitx5 fcitx5-rime fcitx5-configtool
            ;;
    esac

    # 2. 安装雾凇拼音（rime-ice）配置到 Rime 用户目录
    local rime_dir="$HOME/.local/share/fcitx5/rime"
    if [[ -d "$rime_dir" ]]; then
        local backup="$rime_dir.backup.$(date +%Y%m%d%H%M%S)"
        warn "已存在 Rime 用户目录，备份到 $backup"
        mv "$rime_dir" "$backup"
    fi
    mkdir -p "$rime_dir"

    info "下载雾凇拼音（rime-ice）..."
    local tmp_dir
    tmp_dir=$(mktemp -d)
    TMP_DIRS_TO_CLEAN+=("$tmp_dir")

    # 先尝试 GitHub tarball（比 git clone 快），失败回退到 ghproxy 镜像
    local tarball_url="https://codeload.github.com/iDvel/rime-ice/tar.gz/refs/heads/main"
    local mirror_url="https://mirror.ghproxy.com/$tarball_url"

    if ! curl -fsSL -m 120 -o "$tmp_dir/rime-ice.tar.gz" "$tarball_url" && \
       ! curl -fsSL -m 120 -o "$tmp_dir/rime-ice.tar.gz" "$mirror_url"; then
        error "下载 rime-ice 失败（GitHub 与镜像均不可达）"
        return 1
    fi

    tar -xzf "$tmp_dir/rime-ice.tar.gz" -C "$tmp_dir"
    # 目录名是 rime-ice-main（GitHub tarball 规则）
    cp -r "$tmp_dir/rime-ice-main/." "$rime_dir/"
    info "雾凇拼音配置已安装到 $rime_dir"

    # 3. 输入法环境变量（GTK/Qt 应用走 fcitx）
    local env_dir="$HOME/.config/environment.d"
    mkdir -p "$env_dir"
    cat > "$env_dir/input-method.conf" <<'EOF'
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
EOF

    # X11 会话兜底（部分显示管理器不读 environment.d）
    local xprofile="$HOME/.xprofile"
    if ! grep -q "XMODIFIERS=@im=fcitx" "$xprofile" 2>/dev/null; then
        cat >> "$xprofile" <<'EOF'

# fcitx5 输入法环境变量
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
EOF
    fi

    info "输入法安装完成"

    # 4. 预构建词库：确保部署基于雾凇配置（否则 Rime 会用默认的朙月拼音方案），
    #    同时免去首次启动时等待词库编译
    if command -v rime_deployer >/dev/null 2>&1; then
        info "预构建 Rime 词库（雾凇词库较大，可能需要一两分钟）..."
        rime_deployer --build "$rime_dir" /usr/share/rime-data >/dev/null 2>&1 || \
            warn "预构建失败，首次启动时 Rime 会自动部署"
    fi

    # 5. fcitx5 正在运行时，旧的部署缓存会让配置不生效（显示为默认的朙月拼音）
    if pgrep -x fcitx5 >/dev/null 2>&1; then
        warn "fcitx5 正在运行，雾凇拼音需重新部署后生效："
        warn "  rm -rf $rime_dir/build && pkill fcitx5 && fcitx5 -d"
        warn "  或在托盘 Rime 图标右键选择“部署”"
    else
        info "请注销并重新登录，fcitx5 会自动启动并加载雾凇拼音"
    fi
    info "图形配置工具: fcitx5-configurator（或 fcitx5-configtool）"
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
系统设置脚本

用法: $0 [任务 ...]

不带参数时进入交互式菜单；带任务名参数时直接执行（支持逗号或空格分隔）。

可用任务:
  terminal      终端透明度 80%，字体 JetBrainsMonoNerdFont
  locale        系统语言设置为中文（zh_CN.UTF-8）
  home_dirs     家目录下载等目录名设为英文
  input_method  中文输入法（fcitx5 + Rime 雾凇拼音）

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
    check_sudo

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
