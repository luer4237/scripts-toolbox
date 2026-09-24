# Windows LoopbackExempt

## 功能

将当前用户安装的所有 MSIX/AppX 应用加入 Windows Loopback 豁免列表，避免本地回环网络访问受到限制。

脚本会先读取已有的豁免项，已存在的包会跳过，不会重复添加。

## 平台与依赖

- Windows
- PowerShell 5.1 或 PowerShell 7
- `CheckNetIsolation`
- 建议使用管理员权限运行

## 使用方式

在 PowerShell 中运行：

```powershell
.\LoopbackExempt.ps1
```

查看详细的跳过信息：

```powershell
.\LoopbackExempt.ps1 -Verbose
```

脚本结束时会显示新增、跳过和失败的数量。

## 注意事项

- 脚本会处理 `Get-AppxPackage` 返回的当前用户应用包。
- Loopback 豁免会改变 Windows 应用的本地网络访问行为，请只对可信应用使用。
- PowerShell 的执行策略可能阻止脚本运行，需要根据本机策略处理，不建议无条件关闭系统安全策略。
