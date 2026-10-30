# Env

## 功能

把 `~/.my_scripts/bin` 加入 `PATH`，用于放置自定义可执行脚本。

## 平台与依赖

- Shell：Bash 或 Zsh
- 无外部命令依赖

## 使用方式

脚本被 `~/.my_scripts` 加载时自动生效，无需手动执行。放入该目录的可执行文件即可直接调用：

```bash
cp my-tool ~/.my_scripts/bin/
chmod +x ~/.my_scripts/bin/my-tool
```

## 注意事项

- 目录不存在时跳过，不会写入无效路径。
- 已存在该路径时不重复追加，重复加载（多次 `source`）也不会污染 `PATH`。
- 追加到 `PATH` 最前面，优先级高于系统命令。
