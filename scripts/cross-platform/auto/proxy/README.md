# Cross-platform Proxy

## 功能

根据当前操作系统和桌面环境的系统代理状态同步 Shell 代理环境变量，并支持手动开启、关闭和查看代理状态。

## 平台与依赖

- Linux
- macOS
- Bash
- `gsettings`（自动读取 GNOME 系统代理时需要）
- `kreadconfig5` 或 `kreadconfig6`（自动读取 KDE Plasma 代理时需要）
- macOS 自带的 `scutil`（自动读取 macOS 系统代理时需要）

## 使用方式

将脚本加载到当前 Shell：

```bash
source proxy.sh
```

支持以下命令：

```bash
proxy
proxy_on [host] [port] [noproxy]
proxy_off
proxy_status
proxy_desktop
```

默认代理配置：

```text
地址：127.0.0.1
端口：7890
不代理：localhost,127.0.0.1,::1,.local,.lan
```

无参数执行 `proxy` 时，脚本会先检测当前操作系统和桌面环境：

- macOS：读取 `scutil --proxy` 的系统代理配置。
- GNOME：读取 `gsettings` 中的 `org.gnome.system.proxy` 配置。
- KDE Plasma：读取 `~/.config/kioslaverc`，支持 `kreadconfig5` 或 `kreadconfig6`。
- Xfce：没有统一的系统代理配置，优先复用当前 Shell 已有的代理变量；否则使用 `proxy_on` 手动设置。

可以使用 `proxy_desktop` 查看检测结果。

## 注意事项

- 脚本需要在当前 Shell 中 `source`，直接执行脚本不会修改当前 Shell 的环境变量。
- 脚本默认使用 HTTP 代理处理 `HTTP_PROXY`/`HTTPS_PROXY`，使用 SOCKS5 代理处理 `ALL_PROXY`。
- GNOME 的 PAC（自动代理）模式不会被转换为 Shell 代理变量。
