# 扫码助手 · Windows

PC 上出现网盘二维码时，按 `Ctrl+Alt+Q` 框选 → 本地识别 → 唤起**已经打开**的百度网盘 / 夸克，剩下的保存动作按官方客户端的流程走。

技术栈 **C# / .NET 10 / WPF**（无 XAML，界面全部用代码构建）。macOS 版在 [`../macos/`](../macos/)，两端共用产品规则，不共享运行时代码。

## 下载与运行

到 [Releases](https://github.com/M-adrigal/ScanCode/releases/latest) 下载 `ScanCode-win-x64.zip`，解压后双击 `ScanCode.exe`。

- 自带 .NET 运行时，不需要另装任何东西；
- 未签名，首次运行若被 SmartScreen 拦截：**更多信息 → 仍要运行**；
- 系统要求 Windows 10 22H2+ / Windows 11，x64。

## 用法

1. 先手动打开百度网盘或夸克（v1 只唤起，不冷启动，客户端没开就提示你先开）；
2. 按 `Ctrl+Alt+Q`，屏幕变暗后拖动框选二维码，回车或点「解析二维码」；
3. 结果条只显示链接对应的那个应用，点它；
4. 链接和提取码进剪贴板，客户端被拉到前台，你在官方客户端里完成保存。

选区内有多个二维码时出现 1 / 2 编号，点哪个用哪个。普通网页二维码只显示地址和「复制链接」。

截图、识别全部在本机完成，不联网、不落盘、不留历史。诊断日志只记事件、不记二维码内容：`%LOCALAPPDATA%\ScanCode\ScanCode.log`。

## 从源码构建

需要 .NET 10 SDK（`winget install Microsoft.DotNet.SDK.10`），在仓库根目录执行：

```powershell
dotnet restore windows/ScanCode.Windows.sln
dotnet build windows/ScanCode.Windows.sln -c Release
dotnet run --project windows/tests/ScanCode.Core.Tests/ScanCode.Core.Tests.csproj -c Release   # 输出 ALL PASS
dotnet run --project windows/src/ScanCode.App/ScanCode.App.csproj
```

也可以直接打开 `ScanCode.Windows.sln`，把 `ScanCode.App` 设为启动项目按 F5。

### 打单文件 exe

```powershell
powershell -ExecutionPolicy Bypass -File windows\build.ps1
```

脚本依次做：还原 → 编译 → 跑测试 → 发布单文件 → 算 SHA256 → 压 zip。产物 `windows\dist\ScanCode.exe`，约 78 MB，自带运行时。

参数：`-SkipTests` 跳过测试；`-FrameworkDependent` 出约 2–3 MB 的瘦 exe（用户需先装 .NET 10 桌面运行时）。

手工等价命令：

```powershell
dotnet publish windows/src/ScanCode.App/ScanCode.App.csproj -c Release -r win-x64 -o windows/dist `
  -p:SelfContained=true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true `
  -p:EnableCompressionInSingleFile=true -p:DebugType=None -p:DebugSymbols=false
```

最后两个开关不能省：WPF 带一批原生 dll，不设它们会散落在 exe 旁边，就不是单文件了。图标已嵌入程序集，exe 不依赖任何外部文件。

## 目录结构

| 路径 | 职责 |
|---|---|
| `src/ScanCode.Core` | 纯规则：链接属于哪个网盘、提取码是什么、复制什么。不碰界面也不碰系统 |
| `src/ScanCode.Capture` | 抓屏：每块屏整屏拍图，再按框选区域裁 |
| `src/ScanCode.Interop` | Win32：热键、DPI 换算、找窗口、把窗口拉到前台 |
| `src/ScanCode.App` | 界面与流程：托盘、欢迎页、框选遮罩、结果条 |
| `tests/ScanCode.Core.Tests` | Core 规则自测，不依赖第三方测试框架，跑通输出 `ALL PASS` |

## 常见问题

| 现象 | 处理 |
|---|---|
| `dotnet` 不是内部或外部命令 | 没装 .NET 10 SDK，或装完没重开终端 |
| 双击后「Windows 已保护你的电脑」 | exe 未签名，更多信息 → 仍要运行 |
| 杀毒软件报毒 | 单文件自解压的常见误报，加白名单或改用 `-FrameworkDependent` 版 |
| 提示「全局快捷键 Ctrl+Alt+Q 注册失败」 | 被 QQ / 微信 / 截图工具占用，改用托盘菜单「开始识别二维码」 |
| 框选出来一片黑 | GDI 拍不到硬件加速或受保护画面，见「已知限制」 |
| 多屏框选位置偏移 | 混合 DPI 待调，可报一下两台显示器的缩放比例 |
| 点了应用按钮没反应 | 看日志里的 `activate:` 行 |

## 已知限制

- 未签名、无安装器，首次运行可能被 SmartScreen 拦一次；
- 截屏用 GDI `CopyFromScreen`，视频、受保护内容、部分远程桌面会黑屏，后续换 WGC；
- Windows 前台锁可能让 `SetForegroundWindow` 失效，唤起不保证 100%；
- 夸克只做到「复制 + 唤起 + 尝试聚焦」，不保证自动打开保存页；
- 多屏混合 DPI 仍在验证；
- 单文件版约 78 MB，是自带运行时换来的零依赖。

## 实现选择

| 模块 | 方案 | 为什么 |
|---|---|---|
| 热键 | Win32 `RegisterHotKey` + 隐藏 `HwndSource` | 全局热键只能走 Win32，WPF 没有对应 API |
| 截屏 | GDI `CopyFromScreen` | P0 优先简单可靠，WGC 留作后续 |
| 遮罩 | 每块显示器一个无边框置顶窗口 | 多屏各自框选，不用拼跨屏坐标 |
| 解码 | ZXing.Net `DecodeMultiple` | 一次选区可能有两个码 |
| 应用检测 | 进程名 + 安装路径 + 卸载注册表 | 三路兜底，覆盖不同安装方式 |
| 唤起 | `ShowWindow` + `SetForegroundWindow` + `AttachThreadInput` | 绕过前台锁，把客户端真正拉到最前 |
| 托盘 | WinForms `NotifyIcon` | WPF 没有托盘 API，WinForms 最轻 |
| 图标 | 嵌入程序集，按显示尺寸选帧 | 单文件不依赖外部文件；ico 内 7 种尺寸，取错帧放大就发虚 |
| 单实例 | 命名互斥量 | 两个实例会抢热键、出现两个托盘图标 |

## 发版

CI 两个文件，各管一件事：

| 文件 | 触发 | 干什么 |
|---|---|---|
| [`windows.yml`](../.github/workflows/windows.yml) | 推 `windows/**` 或提 PR | 编译 + 跑测试 + 出 exe，产物在 Actions artifact |
| [`windows-release.yml`](../.github/workflows/windows-release.yml) | 推 `win-v*` 标签 | 同上，再建 Release 并挂 zip + SHA256 |

```powershell
git tag win-v0.1.6
git push origin win-v0.1.6
```

`win-` 前缀用来和 macOS 的 `v*` 标签区分，两边发版互不干扰。发版前记得改 `ScanCode.App.csproj` 里的 `<Version>` 和欢迎页的版本文案。

## License

MIT © 2026 M-adrigal
