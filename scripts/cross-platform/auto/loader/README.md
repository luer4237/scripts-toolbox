# Shell Script Loader

## 功能

递归加载 `~/.my_scripts` 下的自动加载 Shell 脚本，并跳过所有 `manual/` 目录和加载器自身。Zsh 加载器支持 `.sh` 和 `.zsh`，Bash 加载器只加载 `.sh`。

## 平台与依赖

- macOS 或 Linux
- Zsh 或 Bash

## 使用方式

Zsh 用户将 [`load-my-scripts.zsh`](load-my-scripts.zsh) 的内容复制到 `~/.zshrc`，Bash 用户将 [`load-my-scripts.bash`](load-my-scripts.bash) 的内容复制到 `~/.bashrc`。

也可以直接加载对应文件：

```zsh
source "/path/to/scripts/cross-platform/auto/loader/load-my-scripts.zsh"
```

```bash
source "/path/to/scripts/cross-platform/auto/loader/load-my-scripts.bash"
```

之后可以将 `cross-platform/auto/` 或整个 `scripts/` 目录放入 `~/.my_scripts/`；加载器会递归加载自动脚本，并跳过 `manual/` 目录。
