# Lazygit

## 功能

提供 `lg` 函数：启动 [lazygit](https://github.com/jesseduffield/lazygit)，退出后如果切换过目录，则自动同步当前 Shell 的工作目录。

## 平台与依赖

- Shell：Bash 或 Zsh
- 命令：`lazygit`

## 使用方式

脚本被 `~/.my_scripts` 加载时自动注册函数：

```bash
lg          # 启动 lazygit
lg path/to/repo
```

## 注意事项

- 通过 `LAZYGIT_NEW_DIR_FILE` 读取 lazygit 退出时的目标目录，仅当目录变化时才执行 `cd`。
- `cd` 失败时输出错误并清理临时文件，不会中断 Shell。
- 本脚本只注册函数，不安装 lazygit。
