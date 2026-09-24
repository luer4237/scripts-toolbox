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
├── macos/
│   └── proxy/
│       ├── 脚本文件
│       └── README.md
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

- 按运行平台放入 `scripts/macos/`、`scripts/windows/` 等目录；支持多个平台的脚本放入 `scripts/cross-platform/`。
- 自动加载的脚本放入对应平台的 `auto/`，手动执行的脚本放入 `manual/`。
- 同一平台下，按具体用途建立功能目录。
- 一个功能目录只处理一个相关用途。
- 功能目录中的 `README.md` 记录功能、依赖、使用方法、参数和注意事项。
- 根目录 `README.md` 只维护项目目录约定和分类规则。
