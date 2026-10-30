# Linux 系统初始化

## 功能

在新装或重装的 Linux 系统上批量安装常用软件并执行初始化配置。拆分为主入口加多个子脚本：主入口负责交互式选择和调度，每个子脚本负责一类任务，均可单独运行。所有项目均有默认值。

### 文件

| 文件 | 职责 |
| --- | --- |
| [`system-init.sh`](system-init.sh) | 主入口：交互式选择软件和任务，调用各子脚本执行 |
| [`common.sh`](common.sh) | 共享函数库（颜色输出、发行版检测、包管理器封装、sudo 检查、交互复选菜单），仅被 source |
| [`install-software.sh`](install-software.sh) | 软件安装 |
| [`setup-system.sh`](setup-system.sh) | 系统设置：终端外观、系统语言、家目录英文目录 |
| [`setup-zshrc.sh`](setup-zshrc.sh) | zshrc 初始化：写入 Linux 版 `~/.zshrc` 并设置默认 Shell |
| [`setup-dev.sh`](setup-dev.sh) | 开发环境初始化：LazyVim、rustup、fnm |
| [`setup-ssh.sh`](setup-ssh.sh) | SSH 初始化：写入 `~/.ssh/config` 全局配置块（连接复用与 Keepalive） |

### 软件安装

默认安装列表（全部预选）：

- **Shell**: zsh、ohmyzsh、zsh-autosuggestions、zsh-completions、zsh-syntax-highlighting
- **压缩**: rsync、7z (p7zip)、unar
- **字体**: JetbrainsMonoNerdFont
- **CLI 工具**: fzf、starship、eza、fd、bat、rg (ripgrep)、zoxide、yazi、btop
- **开发**: git、lazygit、uv、fnm、rustup、nvim (neovim)、lazyvim、mise

可选安装列表（默认不选）：

- direnv、nix

### 初始化任务

- **zshrc**: 写入 Linux 版 `~/.zshrc` 并将 zsh 设为默认 Shell（`setup-zshrc.sh`）
- **终端**: 透明度 80%，字体 JetBrainsMono Nerd Font（`setup-system.sh`）
- **语言**: 系统语言设置为中文 (zh_CN.UTF-8)（`setup-system.sh`）
- **目录**: 家目录下载等目录名设为英文（`setup-system.sh`）
- **输入法**: 中文输入法 fcitx5 + Rime 雾凇拼音（`setup-system.sh`）
- **SSH**: 写入 `~/.ssh/config` 全局配置块，开启连接复用与 Keepalive（`setup-ssh.sh`）
- **LazyVim**: 用 LazyVim starter 初始化 nvim 配置（`setup-dev.sh`）
- **rustup**: 安装最新 stable 工具链并设为默认（`setup-dev.sh`）
- **fnm**: 安装最新 Node.js 版本并设为默认（`setup-dev.sh`）

## 平台与依赖

- 操作系统：Linux（Debian/Ubuntu、Fedora/RHEL、Arch、openSUSE）
- 包管理器：apt、dnf、pacman 或 zypper；Arch 上使用 [paru](https://github.com/Morganamilo/paru)（AUR 助手）统一安装，脚本会在检测到 pacman 且缺少 paru 时自动从 AUR 构建安装（含 `base-devel`、`git`、`curl` 构建依赖）
- 需要 sudo 权限；Arch 上构建 paru 时不能以 root 运行脚本
- 需要 `curl` 或 `wget`（GitHub 下载用）
- 部分 Python 解压操作需要 `python3`（作为 unzip 的回退）

## 使用方式

### 主入口（推荐）

```bash
# 赋予执行权限（仅首次）
chmod +x system-init.sh

# 进入交互式菜单：先选软件，再选初始化任务，确认后统一执行
./system-init.sh

# 列出所有可用项目
./system-init.sh --list

# 查看帮助
./system-init.sh -h
```

交互操作：输入编号切换选择（逗号分隔，如 `3,5,7`），`a` 全选/取消全选，直接回车确认。

### 单独运行子脚本

每个子脚本都遵循相同的调用约定：不带参数进入交互式菜单，带名称参数时直接执行（空格或逗号分隔），`--list` 列出项目，`-h` 查看帮助。

```bash
# 只安装指定软件
./install-software.sh zsh nvim
./install-software.sh zsh,nvim

# 只执行系统设置任务（terminal / locale / home_dirs）
./setup-system.sh terminal locale

# 只初始化 zshrc（单任务脚本，直接执行）
./setup-zshrc.sh

# 只初始化开发环境（lazyvim / rustup / fnm）
./setup-dev.sh rustup fnm

# SSH 配置：install（默认）/ remove / status
./setup-ssh.sh
./setup-ssh.sh status
./setup-ssh.sh remove
```

## 安装方式说明

| 软件 | 安装方式 |
| --- | --- |
| zsh、rsync、7z、unar、git、bat、rg、fd、btop、nvim、direnv | 包管理器（Arch 上统一经 paru，其余走原生包管理器） |
| ohmyzsh | 官方 install.sh（--unattended） |
| zsh 插件 | git clone 到 `~/.oh-my-zsh/custom/plugins/` |
| JetbrainsMonoNerdFont | GitHub Release zip 下载到 `~/.local/share/fonts/` |
| fzf | git clone + `~/.fzf/install`，回退包管理器 |
| starship | starship.rs 官方安装脚本 |
| eza | GitHub Release 二进制，回退 cargo |
| zoxide | 官方 install.sh |
| yazi | GitHub Release zip，回退 cargo |
| lazygit | GitHub Release tar.gz 二进制 |
| uv | astral.sh 官方安装脚本 |
| fnm | fnm.vercel.app 官方安装脚本 |
| rustup | sh.rustup.rs 官方安装脚本 |
| lazyvim | git clone LazyVim/starter 到 `~/.config/nvim/` |
| mise | mise.run 官方安装脚本 |
| nix | nixos.org 官方安装器（--daemon） |

在 apt 系统中，`fd` 和 `bat` 的二进制名分别为 `fdfind` 和 `batcat`，脚本会在 `~/.local/bin/` 下创建 `fd` 和 `bat` 符号链接。

## zshrc 模板说明

`setup-zshrc.sh` 参考个人配置模板生成 Linux 版 `~/.zshrc`，包含：

- oh-my-zsh（主题 `robbyrussell`），plugins 数组加载 git、zoxide、uv、rsync、sudo 及三个 zsh 插件
- fnm（`--use-on-cd`）、direnv hook、fzf（`fzf --zsh`）、starship、mise，均带 `command -v` 守卫
- 自动加载 `~/.my_scripts/**/*.{sh,zsh}`（递归加载，跳过 `manual/` 目录与加载器自身，逻辑与 [`load-my-scripts.zsh`](../../cross-platform/auto/loader/load-my-scripts.zsh) 保持一致）
- 将 `~/.local/bin` 加入 PATH

与 macOS 原始配置的差异：去掉 brew 路径 sourcing（Linux 上插件改由 omz plugins 数组加载）、`macos` 插件、JetBrains vmoptions 及本机专属 PATH 条目。

## 终端配置支持

终端透明度和字体设置支持以下终端：

- **GNOME Terminal**: 通过 gsettings/dconf 设置（新版可能不支持透明度）
- **Alacritty**: 写入 `~/.config/alacritty/alacritty.toml`
- **Kitty**: 写入 `~/.config/kitty/kitty.conf`

如果未检测到上述终端，脚本会打印字体和透明度参数供手动设置。

## 中文输入法说明

`input_method` 任务安装 fcitx5 输入法框架与 Rime 引擎（fcitx5-rime），并部署[雾凇拼音](https://github.com/iDvel/rime-ice)（rime-ice）配置方案：

1. 按发行版安装 `fcitx5`、`fcitx5-rime`（apt 另装 `librime-bin`；dnf/pacman 另装 `fcitx5-configtool`）；apt 系同时执行 `im-config -n fcitx5` 设为默认输入法框架。
2. 克隆 rime-ice 仓库到 `~/.local/share/fcitx5/rime/`（已存在则先备份整个目录）。
3. 写入输入法环境变量：`~/.config/environment.d/input-method.conf`（systemd 用户会话），并在 `~/.xprofile` 追加相同变量作为 X11 兜底。
4. 有 `rime_deployer` 时预构建词库，避免首次部署显示为默认的朙月拼音方案；检测到 fcitx5 正在运行时会提示重新部署。

重新登录后 fcitx5 自动启动，Rime 首次部署会构建词库（雾凇词库较大，稍等片刻）。默认输出为简体拼音；`Ctrl+\`` 或 F4 可切换方案。

## SSH 配置说明

`setup-ssh.sh` 把一段由标记包围的 `Host *` 配置块写入 `~/.ssh/config`，并创建 `~/.ssh/controlmasters` 目录存放连接复用套接字。配置块包含：

- `AddKeysToAgent yes`：首次使用的密钥自动加入 ssh-agent。
- `IdentitiesOnly yes`：只使用显式配置或默认路径的密钥，避免 `Too many authentication failures`。
- `ServerAliveInterval 60` / `ServerAliveCountMax 3`：保活探测，60 秒一次，连续 3 次无响应断开。
- `ControlMaster auto` / `ControlPath ~/.ssh/controlmasters/%r@%n` / `ControlPersist 10m`：到同一主机的后续连接复用已有通道。

重复执行 install 会原地更新配置块，config 中其他内容不受影响；`remove` 可整块移除，`status` 查看安装状态。macOS 上同样可直接运行本脚本。

## 注意事项

- **不要用 sudo 启动脚本**：sudo 会把 `$HOME` 指向 `/root`，用户级安装（ohmyzsh、uv、字体等）会装到 root 家目录下，脚本检测到 `SUDO_USER` 会直接退出；需要 root 的操作（包管理器、locale、chsh）已由脚本内部通过 sudo 执行。root-only 系统（直接以 root 登录，无 `SUDO_USER`）可以正常运行。
- Arch 上首次安装包前会自动构建 paru（需要网络和约 1-2 分钟），之后所有包（含官方仓库包）统一用 `paru -S --needed` 安装。
- 包安装和系统级配置（locale、xdg-user-dirs）会修改系统状态。
- `init_locale` 会修改系统语言为 `zh_CN.UTF-8`，需重新登录生效。
- `init_input_method` 会备份并替换 `~/.local/share/fcitx5/rime/` 整个目录（如已存在），并修改 `~/.xprofile` 与 `~/.config/environment.d/`；需重新登录生效。
- `init_zshrc` 会覆盖 `~/.zshrc`（先备份）并执行 `chsh` 将 zsh 设为默认 Shell。
- `init_ssh` 会修改 `~/.ssh/config` 并将文件权限设为 `600`、目录权限 `700`；config 已存在且不含脚本标记时默认不修改，确认无冲突后执行 `FORCE=1 ./setup-ssh.sh` 备份并追加。
- `init_home_dirs` 会重命名中文目录为英文并更新 `~/.config/user-dirs.dirs`，已有英文目录时保留。
- apt 系统中 neovim 版本低于 0.9 时会自动下载 AppImage。
- LazyVim 初始化会备份已有的 `~/.config/nvim/` 目录。
- nix 安装使用 `--daemon` 模式，会创建系统级 Nix 守护进程。
- 部分工具（fnm、rustup）安装后需要重新加载 Shell 才能在 PATH 中找到。
- 脚本执行完成后建议运行 `exec $SHELL` 或重新登录使所有设置生效。
- `common.sh` 是函数库，直接执行会提示退出；子脚本之间通过 `install-software.sh` 提供的安装函数协作（如 `setup-dev.sh` 复用 nvim/git/rustup/fnm 的安装函数）。
