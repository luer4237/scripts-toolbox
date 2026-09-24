#!/usr/bin/env bash

# Cross-platform Proxy Manager
#
# proxy
#   根据当前操作系统和桌面环境的系统代理状态自动同步到当前 shell
#
# proxy <host> [port] [noproxy]
#   手动设置代理
#
# proxy_on [host] [port] [noproxy]
#   设置代理
#
# proxy_off
#   清除代理
#
# proxy_status
#   查看当前 shell 代理


# ==========================================
# Default Config
# ==========================================

PROXY_HOST="127.0.0.1"
PROXY_PORT="7890"
PROXY_NOPROXY="localhost,127.0.0.1,::1,.local,.lan"


# ==========================================
# Detect Platform and Desktop
# ==========================================
#
# 支持检测以下平台和桌面环境：
#
#   macOS、GNOME、KDE Plasma、Xfce
#
# ==========================================

_platform_name() {
    case "$(uname -s 2>/dev/null)" in
        Darwin) echo "macOS" ;;
        Linux) echo "Linux" ;;
        *) echo "Unknown" ;;
    esac
}


_desktop_name() {
    if [[ "$(_platform_name)" == "macOS" ]]; then
        echo "macOS"
        return
    fi

    local desktop="${XDG_CURRENT_DESKTOP:-${XDG_SESSION_DESKTOP:-${DESKTOP_SESSION:-}}}"
    desktop=$(printf '%s' "$desktop" | tr '[:upper:]' '[:lower:]')

    case "$desktop" in
        *gnome*|*unity*|*cinnamon*) echo "GNOME" ;;
        *kde*|*plasma*) echo "KDE Plasma" ;;
        *xfce*) echo "Xfce" ;;
        *) echo "Unknown" ;;
    esac
}


proxy_desktop() {
    echo "平台: $(_platform_name)"
    echo "桌面环境: $(_desktop_name)"
}


# ==========================================
# Get Linux Desktop Proxy
# ==========================================
#
# 根据平台和桌面环境读取代理：
#
#   macOS      -> scutil --proxy
#   GNOME      -> gsettings
#   KDE Plasma -> kreadconfig5 或 kreadconfig6
#   Xfce       -> 当前 shell 中已有的代理变量
#
# Xfce 没有统一的系统代理配置存储，因此建议使用 proxy_on 手动设置。
#
# GNOME:
#   org.gnome.system.proxy mode = none | manual | auto
#
# manual 模式读取 HTTP/HTTPS/SOCKS 代理；auto 模式使用 PAC 地址，
# 但不会尝试将 PAC 脚本转换成 HTTP_PROXY 环境变量。
#
# return 0
#   检测到可用于 shell 的系统代理
#
# return 1
#   未启用代理或无法读取桌面代理
#
# ==========================================

_macos_proxy() {
    command -v scutil >/dev/null 2>&1 || return 1

    local proxy_info
    proxy_info=$(scutil --proxy 2>/dev/null) || return 1

    local http_enabled https_enabled socks_enabled
    http_enabled=$(awk '/^[[:space:]]*HTTPEnable[[:space:]]*:/ {print $3}' <<< "$proxy_info")
    https_enabled=$(awk '/^[[:space:]]*HTTPSEnable[[:space:]]*:/ {print $3}' <<< "$proxy_info")
    socks_enabled=$(awk '/^[[:space:]]*SOCKSEnable[[:space:]]*:/ {print $3}' <<< "$proxy_info")

    if [[ "$http_enabled" != "1" && "$https_enabled" != "1" && "$socks_enabled" != "1" ]]; then
        return 1
    fi

    local host="" port=""
    if [[ "$http_enabled" == "1" ]]; then
        host=$(awk '/^[[:space:]]*HTTPProxy[[:space:]]*:/ {print $3}' <<< "$proxy_info")
        port=$(awk '/^[[:space:]]*HTTPPort[[:space:]]*:/ {print $3}' <<< "$proxy_info")
    elif [[ "$https_enabled" == "1" ]]; then
        host=$(awk '/^[[:space:]]*HTTPSProxy[[:space:]]*:/ {print $3}' <<< "$proxy_info")
        port=$(awk '/^[[:space:]]*HTTPSPort[[:space:]]*:/ {print $3}' <<< "$proxy_info")
    elif [[ "$socks_enabled" == "1" ]]; then
        host=$(awk '/^[[:space:]]*SOCKSProxy[[:space:]]*:/ {print $3}' <<< "$proxy_info")
        port=$(awk '/^[[:space:]]*SOCKSPort[[:space:]]*:/ {print $3}' <<< "$proxy_info")
    fi

    [[ -n "$host" && -n "$port" ]] || return 1

    local noproxy
    noproxy=$(awk '
        /^[[:space:]]*ExceptionsList[[:space:]]*:/ { in_list=1; next }
        in_list && /^[[:space:]]*}/ { in_list=0; next }
        in_list && /^[[:space:]]*[0-9]+[[:space:]]*:/ {
            sub(/^[[:space:]]*[0-9]+[[:space:]]*:[[:space:]]*/, "")
            print
        }
    ' <<< "$proxy_info" | paste -sd ',' -)

    DESKTOP_PROXY_HOST="$host"
    DESKTOP_PROXY_PORT="$port"
    DESKTOP_PROXY_NOPROXY="${noproxy:-$PROXY_NOPROXY}"
    return 0
}


# ==========================================

_gnome_proxy() {
    command -v gsettings >/dev/null 2>&1 || return 1

    local mode
    mode=$(gsettings get org.gnome.system.proxy mode 2>/dev/null) || return 1
    mode=${mode#\'}
    mode=${mode%\'}

    [[ "$mode" == "manual" ]] || return 1

    local host=""
    local port=""
    local http_host http_port
    local https_host https_port
    local socks_host socks_port

    http_host=$(gsettings get org.gnome.system.proxy.http host 2>/dev/null)
    http_port=$(gsettings get org.gnome.system.proxy.http port 2>/dev/null)
    https_host=$(gsettings get org.gnome.system.proxy.https host 2>/dev/null)
    https_port=$(gsettings get org.gnome.system.proxy.https port 2>/dev/null)
    socks_host=$(gsettings get org.gnome.system.proxy.socks host 2>/dev/null)
    socks_port=$(gsettings get org.gnome.system.proxy.socks port 2>/dev/null)

    http_host=${http_host#\'}; http_host=${http_host%\'}
    http_port=${http_port//[^0-9]/}
    https_host=${https_host#\'}; https_host=${https_host%\'}
    https_port=${https_port//[^0-9]/}
    socks_host=${socks_host#\'}; socks_host=${socks_host%\'}
    socks_port=${socks_port//[^0-9]/}

    if [[ -n "$http_host" && -n "$http_port" ]]; then
        host="$http_host"
        port="$http_port"
    elif [[ -n "$https_host" && -n "$https_port" ]]; then
        host="$https_host"
        port="$https_port"
    elif [[ -n "$socks_host" && -n "$socks_port" ]]; then
        host="$socks_host"
        port="$socks_port"
    else
        return 1
    fi

    local noproxy
    noproxy=$(gsettings get org.gnome.system.proxy ignore-hosts 2>/dev/null)
    noproxy=${noproxy#\@as }
    noproxy=${noproxy#[}
    noproxy=${noproxy%]}
    noproxy=${noproxy//\'/}
    noproxy=${noproxy//,/,}
    noproxy=${noproxy// /}

    DESKTOP_PROXY_HOST="$host"
    DESKTOP_PROXY_PORT="$port"
    DESKTOP_PROXY_NOPROXY="${noproxy:-$PROXY_NOPROXY}"
    return 0
}


_kde_config_get() {
    local key="$1"
    local reader

    if command -v kreadconfig6 >/dev/null 2>&1; then
        reader=kreadconfig6
    elif command -v kreadconfig5 >/dev/null 2>&1; then
        reader=kreadconfig5
    else
        return 1
    fi

    "$reader" --file "$HOME/.config/kioslaverc" \
        --group "Proxy Settings" --key "$key" 2>/dev/null
}


_kde_proxy() {
    local proxy_type
    proxy_type=$(_kde_config_get ProxyType) || return 1

    # 0 = no proxy，1 = manual，2/3 = PAC/WPAD。
    [[ "$proxy_type" == "1" ]] || return 1

    local endpoint host port
    endpoint=$(_kde_config_get HTTPProxy)
    if [[ -z "$endpoint" ]]; then
        endpoint=$(_kde_config_get HTTPSProxy)
    fi
    if [[ -z "$endpoint" ]]; then
        endpoint=$(_kde_config_get SOCKSProxy)
    fi

    case "$endpoint" in
        *:*)
            host="${endpoint%:*}"
            port="${endpoint##*:}"
            ;;
        *) return 1 ;;
    esac
    [[ "$port" =~ ^[0-9]+$ ]] || return 1

    DESKTOP_PROXY_HOST="$host"
    DESKTOP_PROXY_PORT="$port"
    DESKTOP_PROXY_NOPROXY="$(_kde_config_get NoProxyFor)"
    DESKTOP_PROXY_NOPROXY="${DESKTOP_PROXY_NOPROXY:-$PROXY_NOPROXY}"
    return 0
}


_xfce_proxy() {
    # Xfce 没有统一的系统代理配置；如果当前 shell 已有代理，复用它。
    local endpoint="${http_proxy:-${HTTP_PROXY:-}}"
    local endpoint_without_scheme
    case "$endpoint" in
        http://*|https://*) endpoint_without_scheme="${endpoint#*://}" ;;
        *) return 1 ;;
    esac
    case "$endpoint_without_scheme" in
        *:*)
            DESKTOP_PROXY_HOST="${endpoint_without_scheme%:*}"
            DESKTOP_PROXY_PORT="${endpoint_without_scheme##*:}"
            ;;
        *) return 1 ;;
    esac
    [[ "${DESKTOP_PROXY_PORT}" =~ ^[0-9]+$ ]] || return 1
    DESKTOP_PROXY_NOPROXY="${no_proxy:-${NO_PROXY:-$PROXY_NOPROXY}}"
    return 0
}


_desktop_proxy() {
    case "$(_desktop_name)" in
        macOS) _macos_proxy ;;
        GNOME) _gnome_proxy ;;
        "KDE Plasma") _kde_proxy ;;
        Xfce) _xfce_proxy ;;
        *) return 1 ;;
    esac
}


# ==========================================
# Enable Proxy
# ==========================================

proxy_on() {
    local host="${1:-$PROXY_HOST}"
    local port="${2:-$PROXY_PORT}"
    local noproxy="${3:-$PROXY_NOPROXY}"
    local http="http://${host}:${port}"
    local socks="socks5://${host}:${port}"

    export http_proxy="$http"
    export https_proxy="$http"
    export HTTP_PROXY="$http"
    export HTTPS_PROXY="$http"
    export all_proxy="$socks"
    export ALL_PROXY="$socks"
    export no_proxy="$noproxy"
    export NO_PROXY="$noproxy"

    echo "🟢 代理已启用"
    echo ""
    echo "HTTP    : $http"
    echo "HTTPS   : $http"
    echo "SOCKS   : $socks"
    echo "NO_PROXY: $noproxy"
}


# ==========================================
# Disable Proxy
# ==========================================

proxy_off() {
    unset http_proxy https_proxy all_proxy
    unset HTTP_PROXY HTTPS_PROXY ALL_PROXY
    unset no_proxy NO_PROXY
    echo "🔴 代理已关闭"
}


# ==========================================
# Status
# ==========================================

proxy_status() {
    if [[ -n "${http_proxy:-}" || -n "${https_proxy:-}" || -n "${all_proxy:-}" ]]; then
        echo "🟢 代理已启用"
        echo ""
        echo "HTTP    : ${http_proxy:-}"
        echo "HTTPS   : ${https_proxy:-}"
        echo "SOCKS   : ${all_proxy:-}"
        echo "NO_PROXY: ${no_proxy:-}"
    else
        echo "🔴 代理未启用"
    fi
}


# ==========================================
# Proxy Gateway
# ==========================================

proxy() {
    if [[ $# -eq 0 ]]; then
        if _desktop_proxy; then
            proxy_on "$DESKTOP_PROXY_HOST" "$DESKTOP_PROXY_PORT" "$DESKTOP_PROXY_NOPROXY"
        else
            proxy_off
        fi
        return
    fi

    proxy_on "$@"
}

# 被统一加载时只注册命令，不自动修改当前 Shell 的代理环境变量。
