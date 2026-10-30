# macOS 系统初始化

## 功能

在新装或重装的 macOS 上批量安装常用软件并执行初始化配置。拆分为主入口加多个子脚本：主入口负责交互式选择和调度，每个子脚本负责一类任务，均可单独运行。所有项目均有默认值。

### 文件

| 文件 | 职责 |
| --- | --- |
| [`system-init.sh`](system-init.sh) | 主入口：交互式选择软件和任务，调用各子脚本执行 |
| [`common.sh`](common.sh) | 共享函数库（颜色输出、平台检查、Homebrew 封装、交互复选菜单），仅被 source |
| [`install-software.sh`](install-software.sh) | 软件安装（Homebrew 公式与 cask） |
| [`setup-system.sh`](setup-system.sh) | 系统设置：终端字体与透明度、系统语言 |
| [`setup-zshrc.sh`](setup-zshrc.sh) | zshrc 初始化：写入 macOS 版 `~/.zshrc` 并设置默认 Shell |
| [`setup-dev.sh`](setup-dev.sh) | 开发环境初始化：LazyVim、rustup、fnm |
| [`setup-ssh.sh`](setup-ssh.sh) | SSH 初始化：写入 `~/.ssh/config` 全局配置块（连接复用与 Keepalive） |

### 软件安装

默认安装列表（全部预选）：

- **Shell**: bash、zsh、ohmyzsh、zsh-autosuggestions、zsh-completions、zsh-syntax-highlighting
- **压缩**: rsync、7z（命令 `7zz`）、unar
- **字体**: JetbrainsMonoNerdFont
- **CLI 工具**: fzf、starship、eza、fd、bat、rg (ripgrep)、zoxide、yazi、btop
- **开发**: git、lazygit、uv、fnm、rustup、nvim (neovim)、lazyvim、mise

可选安装列表（默认不选）：

- direnv

### 初始化任务

- **zshrc**: 写入 macOS 版 `~/.zshrc` 并将 zsh 设为默认 Shell（`setup-zshrc.sh`）
- **终端**: 字体 JetBrainsMono Nerd Font，透明度 80%（`setup-system.sh`）
- **语言**: 系统语言设置为简体中文 zh-Hans（`setup-system.sh`）
- **SSH**: 写入 `~/.ssh/config` 全局配置块，开启连接复用与 Keepalive（`setup-ssh.sh`）
- **LazyVim**: 用 LazyVim starter 初始化 nvim 配置（`setup-dev.sh`）
- **rustup**: 安装最新 stable 工具链并设为默认（`setup-dev.sh`）
- **fnm**: 安装最新 Node.js 版本并设为默认（`setup-dev.sh`）

## 平台与依赖

- 操作系统：macOS（Apple Silicon 与 Intel 均可）
- Shell：bash >= 4。macOS 自带的 `/bin/bash` 为 3.2，直接执行脚本时会自动切换到 Homebrew bash（`/opt/homebrew/bin/bash` 或 `/usr/local/bin/bash`）；两者都没有时会提示 `brew install bash`
- 包管理器：[Homebrew](https://brew.sh/)。缺失时安装软件流程会询问是否执行官方安装脚本
- 需要网络；字体通过 Homebrew cask 安装，rustup 通过官方脚本安装
- 不需要用 sudo 启动脚本；只有写入 `/etc/shells` 与 `chsh` 时会请求管理员密码

## 使用方式

### 主入口（推荐）

```bash
# 赋予执行权限（仅首次）
chmod +x *.sh

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
./install-software.sh nvim eza
./install-software.sh nvim,eza

# 只执行系统设置任务（terminal / locale）
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
| zsh、bash、rsync、sevenzip、unar、fzf、starship、eza、fd、bat、ripgrep、zoxide、yazi、btop、git、lazygit、uv、fnm、neovim、mise、direnv | Homebrew 公式 |
| JetbrainsMonoNerdFont | Homebrew cask `font-jetbrains-mono-nerd-font` |
| ohmyzsh | 官方 install.sh（--unattended） |
| zsh 插件 | git clone 到 `~/.oh-my-zsh/custom/plugins/` |
| rustup | 官方安装脚本（`--no-modify-path`），工具链放在 `~/.cargo` |
| lazyvim | git clone LazyVim/starter 到 `~/.config/nvim/` |

macOS 自带 `/usr/bin/rsync`（2.6.9）与系统 git、zsh，安装以上项目时会用 Homebrew 版本覆盖 PATH 中的同名命令。

未包含在列表中的项目：`nix`（需官方安装器创建 `/nix` 卷，建议手动安装）。

## zshrc 模板说明

`setup-zshrc.sh` 生成的 `~/.zshrc` 包含：

- Homebrew shellenv（自动识别 `/opt/homebrew` 与 `/usr/local`）
- oh-my-zsh（主题 `robbyrussell`），plugins 加载 git、zoxide、uv、rsync、sudo、macos 及三个 zsh 插件
- fnm（`--use-on-cd`）、direnv hook、fzf（`fzf --zsh`）、starship、mise，均带 `command -v` 守卫
- `~/.cargo/env`（rustup 安装的 Rust 工具链）
- 自动加载 `~/.my_scripts/**/*.{sh,zsh}`（递归加载，跳过 `manual/` 目录与加载器自身，逻辑与 [`load-my-scripts.zsh`](../../cross-platform/auto/loader/load-my-scripts.zsh) 保持一致）

## 终端配置支持

终端字体与透明度支持以下终端：

- **iTerm2**: 写入 `~/Library/Application Support/iTerm2/DynamicProfiles/scripts-toolbox.json` dynamic profile，重启后在 Profiles 中选择
- **Alacritty**: 写入 `~/.config/alacritty/alacritty.toml`
- **Kitty**: 写入 `~/.config/kitty/kitty.conf`
- **Terminal.app**: 配置文件为二进制 plist，脚本只打印手动设置步骤

iTerm2 dynamic profile 使用字体 PostScript 名 `JetBrainsMonoNF-Regular 14`；如果字体未生效，在 Profiles 中手动选择 JetBrainsMono Nerd Font。

## 注意事项

- **不要用 sudo 启动脚本**：sudo 会把 `$HOME` 指向 `/root`，用户级配置会写到 root 家目录，脚本检测到 `SUDO_USER` 会直接退出。
- `init_zshrc` 会覆盖 `~/.zshrc`（先备份）；若使用 Homebrew zsh，会先尝试把它加入 `/etc/shells`（需要管理员密码）再执行 `chsh`。
- `init_locale` 通过 `defaults write -g` 修改当前用户的 `AppleLanguages` 与 `AppleLocale`，需重新登录生效；登录界面等系统级语言需在系统设置中修改。
- `init_ssh` 会修改 `~/.ssh/config` 并将文件权限设为 `600`、目录权限 `700`；config 已存在且不含脚本标记时默认不修改，确认无冲突后执行 `FORCE=1 ./setup-ssh.sh` 备份并追加。配置块包含 macOS 专有的 `UseKeychain yes`。
- `init_terminal` 会新建或覆盖 iTerm2 dynamic profile 与 Alacritty/Kitty 配置文件（如存在）。
- 安装软件前会执行 `brew update`（失败时仅告警并继续使用本地索引）；Homebrew 自动安装时会请求管理员密码并安装到 `/opt/homebrew`（Apple Silicon）或 `/usr/local`（Intel）。
- 脚本会设置 `HOMEBREW_NO_ASK=1`，跳过 Homebrew 7+ 对每个包的安装确认。
- 安装字体后会清除 `com.apple.quarantine` 属性并重启 `fontd`；被隔离的字体不会被 macOS 自动注册，Font Book 与终端都看不到。
- LazyVim 初始化会备份已有的 `~/.config/nvim/` 目录，并在无头模式下同步插件。
- rustup 与 fnm 安装完成后需要重新加载 Shell 才能在新终端中找到 `cargo` / `node`。
- 脚本执行完成后建议运行 `exec $SHELL` 或重新登录使所有设置生效。
- `common.sh` 是函数库，直接执行会提示退出；子脚本之间通过 `install-software.sh` 提供的安装函数协作（如 `setup-dev.sh` 复用 nvim/git/rustup/fnm 的安装函数）。
