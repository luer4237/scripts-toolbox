y() {
    local tmp cwd

    # 创建临时文件
    tmp="$(mktemp -t "yazi-cwd.XXXXXX")" || {
        echo "Failed to create temp file" >&2
        return 1
    }

    # 确保函数退出时一定清理临时文件（即使 Ctrl+C）
    trap 'rm -f -- "$tmp"' EXIT INT TERM

    # 启动 yazi
    yazi "$@" --cwd-file="$tmp"

    # 检查文件是否存在
    if [ -f "$tmp" ]; then
        cwd="$(cat -- "$tmp")"

        if [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
            if ! builtin cd -- "$cwd"; then
                echo "Failed to cd to: $cwd" >&2
                return 1
            fi
        fi
    fi

    # 手动清理（正常路径）
    rm -f -- "$tmp"

    # 清除 trap（避免影响后续 shell）
    trap - EXIT INT TERM
}
