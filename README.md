# Scripts Toolbox

个人脚本工具箱。每个脚本按照运行平台和具体功能分类管理。

## 目录约定

每个具体功能单独建立一个文件夹，文件夹内至少包含：

```text
功能目录/
├── 脚本文件
└── README.md
```

例如：

```text
scripts/
├── cross-platform/
│   ├── auto/
│   │   ├── loader/
│   │   ├── proxy/
│   │   └── docker-proxy/
│   └── manual/
│       └── docker-ctl/
└── windows/
    ├── auto/
    └── manual/
        ├── LoopbackExempt/
        │   ├── 脚本文件
        │   └── README.md
        └── SGuardLimiter/
            ├── 脚本文件
            └── README.md
```

## 分类规则

- 当前按运行平台放入 `scripts/cross-platform/` 或 `scripts/windows/`；支持多个平台的脚本放入 `scripts/cross-platform/`，Windows 专用脚本放入 `scripts/windows/`。
- 自动加载的脚本放入对应平台的 `auto/`，手动执行的脚本放入 `manual/`。
- 同一平台下，按具体用途建立功能目录。
- 一个功能目录只处理一个相关用途。
- 功能目录中的 `README.md` 记录功能、依赖、使用方法、参数和注意事项。

## 工具索引

| 工具 | 简介 | 路径 |
| --- | --- | --- |
| [Shell Script Loader](scripts/cross-platform/auto/loader/README.md) | 递归加载自动执行的 Shell 脚本，并跳过 `manual/` 目录。 | `scripts/cross-platform/auto/loader/` |
| [Cross-platform Proxy](scripts/cross-platform/auto/proxy/README.md) | 检测桌面代理或手动设置当前 Shell 的代理环境变量。 | `scripts/cross-platform/auto/proxy/` |
| [Docker Proxy](scripts/cross-platform/auto/docker-proxy/README.md) | 根据当前 Shell 的代理变量配置 Docker client 和 daemon 代理。 | `scripts/cross-platform/auto/docker-proxy/` |
| [Docker Container Controller](scripts/cross-platform/manual/docker-ctl/README.md) | 管理固定配置的 Docker 容器。 | `scripts/cross-platform/manual/docker-ctl/` |
| [Windows LoopbackExempt](scripts/windows/manual/LoopbackExempt/README.md) | 将当前用户的 MSIX/AppX 应用加入 Windows Loopback 豁免列表。 | `scripts/windows/manual/LoopbackExempt/` |
| [SGuardLimiter](scripts/windows/manual/SGuardLimiter/README.md) | 调整指定 Windows 进程的 CPU 优先级和处理器亲和性。 | `scripts/windows/manual/SGuardLimiter/` |
