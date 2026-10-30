#!/usr/bin/env bash

# 软件安装脚本
#
# 用法：
#   ./install-software.sh            交互式选择要安装的软件
#   ./install-software.sh zsh nvim   直接安装指定软件
#   ./install-software.sh zsh,nvim   同上，支持逗号分隔
#   ./install-software.sh --list     列出所有可用软件
#   ./install-software.sh -h         查看帮助
#
# 被 source 时仅提供函数和数据，不执行 main。

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

# ============ 软件定义 ============

# 默认安装列表（按显示顺序）
DEFAULT_SOFTWARE=(
    "zsh" "ohmyzsh" "zsh-autosuggestions" "zsh-completions" "zsh-syntax-highlighting"
    "rsync" "7z" "unar"
    "JetbrainsMonoNerdFont"
    "fzf" "starship" "eza" "fd" "bat" "rg" "zoxide" "yazi" "btop"
    "git" "lazygit"
    "uv" "fnm" "rustup" "nvim" "lazyvim" "mise"
)

# 可选安装列表
OPTIONAL_SOFTWARE=(
    "direnv" "nix"
)

# 软件描述
declare -A SW_DESC=(
    [zsh]="Zsh Shell"
    [ohmyzsh]="Oh My Zsh 框架"
    [zsh-autosuggestions]="zsh 命令自动建议插件"
    [zsh-completions]="zsh 额外补全规则"
    [zsh-syntax-highlighting]="zsh 语法高亮插件"
    [rsync]="增量文件同步工具"
    [7z]="7-Zip 压缩工具"
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
    [git]="版本控制"
    [lazygit]="Git TUI 客户端"
    [uv]="Python 包管理器（Rust 实现）"
    [fnm]="Node.js 版本管理器"
    [rustup]="Rust 工具链管理器"
    [nvim]="Neovim 编辑器"
    [lazyvim]="LazyVim Neovim 配置"
    [mise]="多语言版本管理器"
    [direnv]="目录级环境变量"
    [nix]="Nix 包管理器"
)

# ============ 安装函数 ============

# --- 包管理器可安装的软件 ---

install_pkg_tool() {
    local tool="$1"
    local name
    name=$(pkg_name "$tool")
    info "通过 $PKG_MANAGER 安装 $tool ($name) ..."
    pkg_install "$name"
}

# --- zsh ---

install_zsh() {
    if command -v zsh >/dev/null 2>&1; then
        info "zsh 已安装，跳过"
        return 0
    fi
    install_pkg_tool "zsh"
}

# --- ohmyzsh ---

install_ohmyzsh() {
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
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

    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
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

# --- rsync / 7z / unar ---

install_rsync() {
    if command -v rsync >/dev/null 2>&1; then
        info "rsync 已安装，跳过"
        return 0
    fi
    install_pkg_tool "rsync"
}

install_7z() {
    if command -v 7z >/dev/null 2>&1; then
        info "7z 已安装，跳过"
        return 0
    fi
    install_pkg_tool "7z"
}

install_unar() {
    if command -v unar >/dev/null 2>&1; then
        info "unar 已安装，跳过"
        return 0
    fi
    install_pkg_tool "unar"
}

# --- Nerd Font ---

install_JetbrainsMonoNerdFont() {
    local font_dir="$HOME/.local/share/fonts"
    local font_name="JetBrainsMonoNerdFont"
    local latest_tag asset_url tmp_dir

    if [[ -d "$font_dir/$font_name" ]]; then
        info "JetBrainsMonoNerdFont 已安装，跳过"
        return 0
    fi

    info "获取 JetBrainsMono Nerd Font 最新版本 ..."
    latest_tag=$(curl -fsSL "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest" | grep -oP '"tag_name":\s*"\K[^"]+' || echo "")

    if [[ -z "$latest_tag" ]]; then
        warn "无法获取最新版本号，使用默认 v3.3.0"
        latest_tag="v3.3.0"
    fi

    info "下载 JetBrainsMono Nerd Font $latest_tag ..."
    tmp_dir=$(mktemp -d)
    TMP_DIRS_TO_CLEAN+=("$tmp_dir")

    asset_url="https://github.com/ryanoasis/nerd-fonts/releases/download/${latest_tag}/JetBrainsMono.zip"

    if ! github_download "$asset_url" "$tmp_dir/JetBrainsMono.zip"; then
        error "下载 JetBrainsMono Nerd Font 失败"
        return 1
    fi

    mkdir -p "$font_dir/$font_name"
    if command -v unzip >/dev/null 2>&1; then
        unzip -o "$tmp_dir/JetBrainsMono.zip" -d "$font_dir/$font_name" >/dev/null
    else
        warn "未找到 unzip，尝试用 Python 解压"
        python3 -c "import zipfile; zipfile.ZipFile('$tmp_dir/JetBrainsMono.zip').extractall('$font_dir/$font_name')"
    fi

    info "刷新字体缓存 ..."
    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f "$font_dir" >/dev/null 2>&1 || true
    fi

    info "JetBrainsMonoNerdFont 安装完成"
}

# --- fzf ---

install_fzf() {
    if command -v fzf >/dev/null 2>&1; then
        info "fzf 已安装，跳过"
        return 0
    fi

    info "通过 git 安装 fzf ..."
    local fzf_dir="$HOME/.fzf"
    if [[ ! -d "$fzf_dir" ]]; then
        git clone --depth 1 https://github.com/junegunn/fzf.git "$fzf_dir"
    fi
    "$fzf_dir/install" --all --no-bash --no-zsh --no-fish >/dev/null 2>&1 || true

    if ! command -v fzf >/dev/null 2>&1; then
        warn "git 安装方式失败，回退到包管理器"
        install_pkg_tool "fzf"
    fi
}

# --- starship ---

install_starship() {
    ensure_local_bin
    if command -v starship >/dev/null 2>&1; then
        info "starship 已安装，跳过"
        return 0
    fi
    info "安装 starship ..."
    curl -fsSL https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$HOME/.local/bin"
}

# --- eza ---

install_eza() {
    ensure_local_bin
    if command -v eza >/dev/null 2>&1; then
        info "eza 已安装，跳过"
        return 0
    fi

    info "获取 eza 最新版本 ..."
    local latest_tag asset_url arch

    case "$(uname -m)" in
        x86_64)  arch="x86_64" ;;
        aarch64|arm64) arch="aarch64" ;;
        *) error "不支持的架构: $(uname -m)"; return 1 ;;
    esac

    latest_tag=$(curl -fsSL "https://api.github.com/repos/eza-community/eza/releases/latest" | grep -oP '"tag_name":\s*"\K[^"]+' || echo "")
    if [[ -z "$latest_tag" ]]; then
        latest_tag="latest"
    fi

    asset_url="https://github.com/eza-community/eza/releases/download/${latest_tag}/eza_${arch}-unknown-linux-gnu.tar.gz"

    local tmp_dir
    tmp_dir=$(mktemp -d)
    TMP_DIRS_TO_CLEAN+=("$tmp_dir")

    if ! github_download "$asset_url" "$tmp_dir/eza.tar.gz"; then
        error "下载 eza 失败，尝试 cargo 安装"
        if ensure_cargo; then
            cargo install eza
        else
            error "rustup 安装失败，无法通过 cargo 构建 eza"
        fi
        return 0
    fi

    tar -xzf "$tmp_dir/eza.tar.gz" -C "$tmp_dir"
    cp "$tmp_dir/eza" "$HOME/.local/bin/eza"
    chmod +x "$HOME/.local/bin/eza"
    info "eza 安装完成"
}

# --- fd / bat / rg / btop ---

install_fd() {
    if command -v fd >/dev/null 2>&1 || command -v fdfind >/dev/null 2>&1; then
        info "fd 已安装，跳过"
        return 0
    fi

    case "$PKG_MANAGER" in
        apt)
            # apt 的 fd-find 安装后名为 fdfind，需要创建别名
            install_pkg_tool "fd"
            ensure_local_bin
            ln -sf "$(command -v fdfind 2>/dev/null || echo /usr/bin/fdfind)" "$HOME/.local/bin/fd" 2>/dev/null || true
            ;;
        *)
            install_pkg_tool "fd"
            ;;
    esac
}

install_bat() {
    if command -v bat >/dev/null 2>&1 || command -v batcat >/dev/null 2>&1; then
        info "bat 已安装，跳过"
        return 0
    fi

    case "$PKG_MANAGER" in
        apt)
            install_pkg_tool "bat"
            ensure_local_bin
            ln -sf "$(command -v batcat 2>/dev/null || echo /usr/bin/batcat)" "$HOME/.local/bin/bat" 2>/dev/null || true
            ;;
        *)
            install_pkg_tool "bat"
            ;;
    esac
}

install_rg() {
    if command -v rg >/dev/null 2>&1; then
        info "rg 已安装，跳过"
        return 0
    fi
    install_pkg_tool "rg"
}

install_btop() {
    if command -v btop >/dev/null 2>&1; then
        info "btop 已安装，跳过"
        return 0
    fi
    install_pkg_tool "btop"
}

# --- zoxide ---

install_zoxide() {
    if command -v zoxide >/dev/null 2>&1; then
        info "zoxide 已安装，跳过"
        return 0
    fi
    info "安装 zoxide ..."
    curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
}

# --- yazi ---

install_yazi() {
    ensure_local_bin
    if command -v yazi >/dev/null 2>&1; then
        info "yazi 已安装，跳过"
        return 0
    fi

    info "获取 yazi 最新版本 ..."
    local latest_tag arch asset_url tmp_dir

    case "$(uname -m)" in
        x86_64)  arch="x86_64" ;;
        aarch64|arm64) arch="aarch64" ;;
        *) error "不支持的架构: $(uname -m)"; return 1 ;;
    esac

    latest_tag=$(curl -fsSL "https://api.github.com/repos/sxyazi/yazi/releases/latest" | grep -oP '"tag_name":\s*"\K[^"]+' || echo "")
    if [[ -z "$latest_tag" ]]; then
        error "无法获取 yazi 最新版本"
        return 1
    fi

    asset_url="https://github.com/sxyazi/yazi/releases/latest/download/yazi-${arch}-unknown-linux-gnu.zip"
    tmp_dir=$(mktemp -d)
    TMP_DIRS_TO_CLEAN+=("$tmp_dir")

    if ! github_download "$asset_url" "$tmp_dir/yazi.zip"; then
        error "下载 yazi 失败，尝试 cargo 安装"
        if ensure_cargo; then
            cargo install --locked yazi-fm yazi-cli
        else
            error "rustup 安装失败，无法通过 cargo 构建 yazi"
        fi
        return 0
    fi

    if command -v unzip >/dev/null 2>&1; then
        unzip -o "$tmp_dir/yazi.zip" -d "$tmp_dir" >/dev/null
    else
        python3 -c "import zipfile; zipfile.ZipFile('$tmp_dir/yazi.zip').extractall('$tmp_dir')"
    fi

    # 查找 yazi 二进制文件
    local binary
    binary=$(find "$tmp_dir" -name "yazi" -type f | head -1)
    if [[ -n "$binary" ]]; then
        cp "$binary" "$HOME/.local/bin/yazi"
        chmod +x "$HOME/.local/bin/yazi"
    fi

    local ya_binary
    ya_binary=$(find "$tmp_dir" -name "ya" -type f | head -1)
    if [[ -n "$ya_binary" ]]; then
        cp "$ya_binary" "$HOME/.local/bin/ya"
        chmod +x "$HOME/.local/bin/ya"
    fi

    info "yazi 安装完成"
}

# --- git / lazygit ---

install_git() {
    if command -v git >/dev/null 2>&1; then
        info "git 已安装，跳过"
        return 0
    fi
    install_pkg_tool "git"
}

install_lazygit() {
    ensure_local_bin
    if command -v lazygit >/dev/null 2>&1; then
        info "lazygit 已安装，跳过"
        return 0
    fi

    info "获取 lazygit 最新版本 ..."
    local latest_tag arch asset_url tmp_dir

    case "$(uname -m)" in
        x86_64)  arch="x86_64" ;;
        aarch64|arm64) arch="arm64" ;;
        *) error "不支持的架构: $(uname -m)"; return 1 ;;
    esac

    latest_tag=$(curl -fsSL "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -oP '"tag_name":\s*"\K[^"]+' || echo "")
    if [[ -z "$latest_tag" ]]; then
        error "无法获取 lazygit 最新版本"
        return 1
    fi

    # 去掉 v 前缀
    local version="${latest_tag#v}"
    asset_url="https://github.com/jesseduffield/lazygit/releases/download/${latest_tag}/lazygit_${version}_linux_${arch}.tar.gz"

    tmp_dir=$(mktemp -d)
    TMP_DIRS_TO_CLEAN+=("$tmp_dir")

    if ! github_download "$asset_url" "$tmp_dir/lazygit.tar.gz"; then
        error "下载 lazygit 失败"
        return 1
    fi

    tar -xzf "$tmp_dir/lazygit.tar.gz" -C "$tmp_dir"
    cp "$tmp_dir/lazygit" "$HOME/.local/bin/lazygit"
    chmod +x "$HOME/.local/bin/lazygit"
    info "lazygit 安装完成"
}

# --- uv ---

install_uv() {
    ensure_local_bin
    if command -v uv >/dev/null 2>&1; then
        info "uv 已安装，跳过"
        return 0
    fi
    info "安装 uv ..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    # uv 安装到 ~/.local/bin，确保 PATH 包含
    ensure_local_bin
}

# --- fnm ---

install_fnm() {
    ensure_local_bin
    if command -v fnm >/dev/null 2>&1; then
        info "fnm 已安装，跳过"
        return 0
    fi
    info "安装 fnm ..."
    # fnm 的安装脚本默认安装到 ~/.local/share/fnm
    curl -fsSL https://fnm.vercel.app/install | bash
    # fnm 二进制在 ~/.local/share/fnm/fnm
    local fnm_bin="$HOME/.local/share/fnm/fnm"
    if [[ -f "$fnm_bin" ]] && [[ ! -f "$HOME/.local/bin/fnm" ]]; then
        ln -sf "$fnm_bin" "$HOME/.local/bin/fnm"
    fi
    info "fnm 安装完成，请在安装结束后重新加载 Shell 或手动 source"
}

# --- rustup ---

install_rustup() {
    if command -v rustup >/dev/null 2>&1; then
        info "rustup 已安装，跳过"
        return 0
    fi
    info "安装 rustup ..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    # 添加 cargo bin 到 PATH
    source "$HOME/.cargo/env" 2>/dev/null || true
    info "rustup 安装完成"
}

# 确保 cargo 可用；缺失时现场安装 rustup（不依赖安装列表中的 rustup 顺序）
ensure_cargo() {
    if command -v cargo >/dev/null 2>&1; then
        return 0
    fi
    warn "cargo 不可用，先安装 rustup ..."
    install_rustup
    source "$HOME/.cargo/env" 2>/dev/null || true
    command -v cargo >/dev/null 2>&1
}

# --- nvim / lazyvim ---

install_nvim() {
    if command -v nvim >/dev/null 2>&1; then
        info "nvim 已安装，跳过"
        return 0
    fi

    # 优先使用包管理器的 neovim
    case "$PKG_MANAGER" in
        apt)
            # Ubuntu/Debian 仓库中的 neovim 版本可能较旧
            info "检测到 apt，尝试安装 neovim ..."
            install_pkg_tool "nvim"
            # 检查版本，LazyVim 需要 neovim >= 0.9.0
            local nvim_version nvim_major nvim_minor
            nvim_version=$(nvim --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+' || echo "0.0.0")
            nvim_major=$(echo "$nvim_version" | cut -d. -f1)
            nvim_minor=$(echo "$nvim_version" | cut -d. -f2)
            if (( nvim_major == 0 && nvim_minor < 9 )); then
                warn "仓库中的 neovim 版本较旧 ($nvim_version)，尝试安装 AppImage 版本"
                install_nvim_appimage
            fi
            ;;
        *)
            install_pkg_tool "nvim"
            ;;
    esac
}

install_nvim_appimage() {
    ensure_local_bin
    local nvim_appimage="$HOME/.local/bin/nvim"
    info "下载 Neovim AppImage ..."
    if github_download "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.appimage" "$nvim_appimage"; then
        chmod u+x "$nvim_appimage"
        info "Neovim AppImage 安装完成"
    else
        error "下载 Neovim AppImage 失败"
        return 1
    fi
}

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

# --- mise ---

install_mise() {
    ensure_local_bin
    if command -v mise >/dev/null 2>&1; then
        info "mise 已安装，跳过"
        return 0
    fi
    info "安装 mise ..."
    curl -fsSL https://mise.run | sh
    info "mise 安装完成"
}

# --- direnv ---

install_direnv() {
    if command -v direnv >/dev/null 2>&1; then
        info "direnv 已安装，跳过"
        return 0
    fi
    install_pkg_tool "direnv"
}

# --- nix ---

install_nix() {
    if command -v nix >/dev/null 2>&1 || [[ -d /nix ]]; then
        info "nix 已安装，跳过"
        return 0
    fi
    info "安装 Nix（官方安装器）..."
    curl -fsSL https://nixos.org/nix/install | sh -s -- --daemon
    info "Nix 安装完成，请重新加载 Shell 或手动 source /nix/var/nix/profiles/etc/profile.d/nix-daemon.sh"
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
        # 默认尝试包管理器安装
        install_pkg_tool "$tool"
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
软件安装脚本

用法: $0 [软件名 ...]

不带参数时进入交互式菜单；带软件名参数时直接安装（支持逗号或空格分隔）。

示例:
  $0                 交互式选择
  $0 zsh nvim        直接安装 zsh 和 nvim
  $0 zsh,nvim        同上
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
    check_sudo
    step "更新包索引"
    pkg_update

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
