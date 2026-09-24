# Recursively load shell scripts from ~/.my_scripts.
# Copy this block into ~/.zshrc, or source this file from ~/.zshrc.

if [[ -d "$HOME/.my_scripts" ]]; then
    for _my_script in "$HOME/.my_scripts"/**/*.{sh,zsh}(N); do
        case "$_my_script" in
            */manual/*) continue ;;
            */load-my-scripts.*) continue ;;
        esac
        [[ -f "$_my_script" ]] || continue
        source "$_my_script"
    done
    unset _my_script
fi
