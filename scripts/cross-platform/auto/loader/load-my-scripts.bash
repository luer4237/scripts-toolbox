# Recursively load portable .sh scripts from ~/.my_scripts.
# Copy this block into ~/.bashrc, or source this file from ~/.bashrc.

if [ -d "$HOME/.my_scripts" ]; then
    while IFS= read -r -d '' _my_script; do
        # Bash only loads .sh files. Zsh-specific files should use .zsh.
        case "$_my_script" in
            *.sh) . "$_my_script" ;;
        esac
    done < <(find "$HOME/.my_scripts" -type d -name manual -prune -o -type f -name '*.sh' ! -name 'load-my-scripts.*' -print0 2>/dev/null)
    unset _my_script
fi
