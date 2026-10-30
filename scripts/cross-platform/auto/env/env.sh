# 新增 path 路径：仅在目录存在且未重复时追加
if [ -d "$HOME/.my_scripts/bin" ]; then
    case ":$PATH:" in
        *":$HOME/.my_scripts/bin:"*) ;;
        *) PATH="$HOME/.my_scripts/bin:$PATH" ;;
    esac
fi

export PATH
