# Alias

## 功能

用 [eza](https://github.com/eza-community/eza) 替代传统 `ls` / `tree`，提供图标、Git 状态和目录优先排序。

提供的别名：

- `ls` → `eza --icons --git --group-directories-first`
- `lt` → 两层树状显示
- `tree` → `eza --tree --icons`

## 平台与依赖

- Shell：Bash 或 Zsh
- 命令：`eza`

## 使用方式

脚本被 `~/.my_scripts` 加载时自动注册别名，无需手动执行：

```bash
ls
lt
tree
```

## 注意事项

- `ls` 被替换为 `eza`；未安装 `eza` 时该别名会导致命令不可用，需先 `brew install eza`（macOS）或通过发行版包管理器安装。
- 本脚本只定义别名，不修改 PATH，也不安装 eza。
