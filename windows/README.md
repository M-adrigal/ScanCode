# 扫码助手 · Windows P0

Windows 10 22H2+ / Windows 11（x64）的独立实现，技术栈 **C# / .NET 10 / WPF**。

macOS 版在 [`../macos/`](../macos/)；两端共用产品规则，不共享运行时代码。

> 本目录是在 macOS 上编写的首版 P0，尚未在 Windows 上编译验证；第一次构建可能需要少量编译修正。

## 当前能力

- 托盘常驻，无主窗口；
- 全局热键 `Ctrl+Alt+Q`；
- 冻结屏幕 + 多显示器框选；
- 本地 ZXing 解码，不上传、不落盘；
- 百度/夸克只显示匹配应用的结果条；
- 多二维码编号，二次点选；
- 严格只唤起已运行应用，不冷启动；
- 客户端只剩托盘图标时，尝试让其重开主窗口；
- 普通网页/文本二维码显示完整地址，只提供复制链接。

## 环境

- Windows 10 22H2 或 Windows 11，x64；
- .NET 10 SDK；
- 可选 Visual Studio 2022/2026（WPF 工作负载）。

## 构建

在仓库根目录：

```powershell
dotnet restore windows/ScanCode.Windows.sln
dotnet build windows/ScanCode.Windows.sln -c Release
dotnet test windows/tests/ScanCode.Core.Tests/ScanCode.Core.Tests.csproj -c Release
```

运行：

```powershell
dotnet run --project windows/src/ScanCode.App/ScanCode.App.csproj
```

发布自包含包：

```powershell
dotnet publish windows/src/ScanCode.App/ScanCode.App.csproj `
  -c Release -r win-x64 --self-contained true `
  -p:PublishSingleFile=false -p:PublishReadyToRun=false `
  -o windows/dist

Compress-Archive -Path windows/dist/* -DestinationPath ScanCode-win-x64.zip -Force
```

或直接：

```powershell
powershell -ExecutionPolicy Bypass -File windows/build.ps1
```

## 使用

1. 先手动打开百度网盘或夸克；
2. 按 `Ctrl+Alt+Q`；
3. 拖动框选二维码，点「解析二维码」；
4. 结果条只显示匹配的应用；
5. 点应用按钮：复制链接并唤起客户端。

## 实现说明

| 模块 | 方案 |
|---|---|
| 热键 | Win32 `RegisterHotKey` + 隐藏 `HwndSource` |
| 截屏 | GDI `CopyFromScreen`（P0）；WGC 作为后续增强 |
| 遮罩 | 每块显示器一个 WPF 无边框置顶窗口 |
| 解码 | ZXing.Net `DecodeMultiple` |
| 应用检测 | 进程名 + 已知安装路径 + 卸载注册表 |
| 唤起 | `ShowWindow` + `SetForegroundWindow` + `AttachThreadInput` |
| 托盘 | WinForms `NotifyIcon` |

Windows 没有 macOS 的屏幕录制 TCC 权限，不需要授权弹窗；未签名 exe 首次运行可能被 SmartScreen 拦截，右键运行即可。

## 已知限制

- P0 用 GDI 截屏，硬件加速/受保护内容可能黑屏；后续换 WGC。
- Windows 前台锁可能让 `SetForegroundWindow` 失败，需要按客户端差异调。
- 夸克 Windows 是独立客户端，只做 L1.5：复制 + 唤起 + 尽量聚焦地址栏，不保证自动打开保存页。
- 多屏混合 DPI 仍在验证；如坐标偏移，先反馈显示器缩放比例。
- 未签名、未做安装器；发布包是 zip。

## CI

[`.github/workflows/windows.yml`](../.github/workflows/windows.yml) 在 `windows-latest` 上构建、跑 Core 测试、发布 `win-x64` 产物。
