# Yazi

## 功能

提供 `y` 函数：启动 [yazi](https://github.com/sxyazi/yazi) 文件管理器，退出后自动把当前 Shell 切换到 yazi 中最后停留的目录。

## 平台与依赖

- Shell：Bash 或 Zsh
- 命令：`yazi`

## 使用方式

脚本被 `~/.my_scripts` 加载时自动注册函数：

```bash
y           # 打开当前目录
y /path     # 打开指定目录
```

## 注意事项

- 使用 `mktemp` 创建临时文件并通过 `--cwd-file` 获取退出目录，仅当目录变化时才执行 `cd`。
- 通过 `trap` 保证 `Ctrl+C` 等中断情况下临时文件也会被清理。
- 本脚本只注册函数，不安装 yazi。
