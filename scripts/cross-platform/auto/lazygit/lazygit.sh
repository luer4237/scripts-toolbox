#!/bin/bash
lg() {
    local tmp="${HOME}/.lazygit/newdir"
    local newdir

    export LAZYGIT_NEW_DIR_FILE="$tmp"

    lazygit "$@"

    if [ -f "$tmp" ]; then
        newdir="$(cat -- "$tmp")"

        if [ -n "$newdir" ] && [ "$newdir" != "$PWD" ]; then
            if ! builtin cd -- "$newdir"; then
                echo "Failed to cd to: $newdir" >&2
                rm -f -- "$tmp"
                return 1
            fi
        fi

        rm -f -- "$tmp"
    fi
}
