# 扫码助手 · macOS P0 原型

全局快捷键 `⌃⌥Q` → 冻结屏幕 → 框选二维码 → 本地 Vision 解码 → 结果条选择百度网盘/夸克 → **只激活已经打开的应用**。

> v1 严格模式：不冷启动、不自动保存。应用没打开时只提示，不启动。

## 直接安装（推荐）

打开 [GitHub Releases](https://github.com/M-adrigal/ScanCode/releases/latest) 下载 DMG，把「扫码助手」拖到 Applications，然后打开。会先看到欢迎窗口。

> 如果之前在 DMG 里直接打开过，先退出菜单栏里的旧实例，再从 Applications/启动台打开。

如果 macOS 提示“无法验证开发者”：右键 App → 打开；或在系统设置 → 隐私与安全性里点“仍要打开”。

## 源码构建

要求：macOS 14+、Command Line Tools（不需要完整 Xcode）。

```bash
cd /path/to/ScanCode/macos
./build.sh
open "build/ScanCode.app"
```

产物：`build/ScanCode.app`（ad-hoc 签名）。构建脚本会顺便跑一遍 `--selftest`。DMG 不提交进源码仓库，发布包见 GitHub Releases。

生成 DMG：

```bash
cd /path/to/ScanCode/macos
./make-dmg.sh
```

> 本机 CLT 的默认 Swift module cache 在 `/var/folders` 被沙箱拒绝，所以脚本显式使用
> `-module-cache-path ../.build/modulecache`。如果你在别的机器上构建且没有这个限制，也可以保留该参数。

## 运行

```bash
# 在 macos 目录下
open "build/ScanCode.app"

# 或在项目根目录
open "macos/build/ScanCode.app"
```

首次使用：

1. 屏幕会弹出/需要手动到「系统设置 → 隐私与安全性 → 屏幕录制」允许「扫码助手」；授权后如仍无权限，退出并重新打开应用；
2. **先手动打开百度网盘 / 夸克**（严格模式不会替你启动）；
3. 按 `⌃⌥Q`，拖拽框选二维码，松手后点「解析二维码」；如果框里有多个二维码，再点编号选择要识别的那一个；
4. 在结果条点百度网盘或夸克：
   - 百度：复制链接+提取码，激活客户端；你在「我的分享 → 输入提取码」里粘贴/输入并自己保存；
   - 夸克：直接打开分享页，你自己点保存。

> 重新 `./build.sh` 会改变 ad-hoc 签名，macOS 可能要求重新授权屏幕录制。
> 如果 macOS 提示“无法打开”或“已损坏”，右键 App → 打开，或执行：
> `xattr -dr com.apple.quarantine macos/build/ScanCode.app`。

## 权限问题

- macOS 删除 App 不会删除屏幕录制授权记录；0.1.5 在未授权启动时会自动执行
  `tccutil reset ScreenCapture com.yuanye.scancode`，再请求系统授权；
- 如果系统设置里仍有旧的「扫码助手 / ScanCode」条目但授权不生效：选中旧条目点减号删除，再打开 App；
- 启动时会做一次实际截屏自检；开关假开/旧授权残留时会自动清理并重新请求；
- 如果授权开关看起来是开的但仍无法截屏：菜单栏图标 →「修复屏幕录制权限…」；
- 覆盖安装新的 ad-hoc 构建后，首次打开通常需要重新授权一次；
- 诊断日志：`~/Library/Application Support/ScanCode/ScanCode.log`（只记录事件，不记录二维码内容）。

## 测试二维码

用 Preview 打开 [`../assets/qr-demo.png`](../assets/qr-demo.png)（百度网盘链接），然后按 `⌃⌥Q` 框选它，即可走完整流程。

## 测试命令

```bash
# QR 生成 + Vision 解码 + 分类/提取码
./build/ScanCode.app/Contents/MacOS/扫码助手 --selftest

# 严格模式：百度/夸克未运行时必须被拦截，不产生新进程
./build/ScanCode.app/Contents/MacOS/扫码助手 --dispatch-test

# 查看两个应用的安装/运行状态
./build/ScanCode.app/Contents/MacOS/扫码助手 --list-apps

# 真实屏幕捕获自检（需要屏幕录制权限）
./build/ScanCode.app/Contents/MacOS/扫码助手 --capture-test
# 输出 /tmp/scancode-capture-0.png

# 真实捕获 + 自建二维码窗口 + 自动框选 + 解码 + 结果条（调试用）
./build/ScanCode.app/Contents/MacOS/扫码助手 --integration-test

# 离屏渲染 UI（不需要屏幕权限、不需要解锁）
./build/ScanCode.app/Contents/MacOS/扫码助手 --snapshot
# 输出：build/snapshots/overlay.png、panel-running.png、panel-not-running.png

# UI 演示：用合成桌面 + 自动框选，1 秒后显示结果条
./build/ScanCode.app/Contents/MacOS/扫码助手 --demo
```

`--demo` 使用合成图像，不需要屏幕录制权限；真实使用必须授权。

## 手动验收

- [ ] 关闭百度网盘后框选百度链接，点“百度网盘”：提示“未启动”，**不启动应用**；
- [ ] 打开百度网盘后再点：剪贴板有链接+提取码，客户端到前台；
- [ ] 打开夸克后框选夸克链接：夸克打开分享页；
- [ ] 未安装某应用（或改名 App）时：提示“本地暂无可使用的应用”；
- [ ] `Esc` 可取消框选；`1/2/Enter` 可操作结果条；
- [ ] 多屏下每块屏都能框选（有副屏时）。

## 已实现（P0）

- 菜单栏常驻、`⌃⌥Q` 全局热键；
- ScreenCaptureKit 冻结多屏画面、每屏遮罩、拖拽框选、`Esc` 取消；
- Vision QR 解码 + 放大/灰度/反色兜底；
- 百度/夸克域名识别、提取码提取；
- 结果条：类型、摘要、提取码、两个应用状态、推荐、复制/关闭、键盘 `1/2/Enter`；
- 严格分发：只激活已运行应用；未运行只提示；未安装给下载入口；
- 剪贴板识别（图片/文本）；
- HUD/Alert；demo/snapshot 自测。

## 已知限制 / P1

- 无设置页、快捷键不可配置（固定 `⌃⌥Q`）；
- 无放大镜、多码选择、全屏预识别；
- 百度只能做到“复制 + 唤起 + 引导”，不能自动打开分享页；
- 夸克 macOS 走 `NSWorkspace.open` 直达；Windows 版后续实现 L1.5；
- 物理热键/鼠标的真人操作未在自动化环境中验证（CGEvent 注入受辅助功能权限限制）；
- 屏幕录制权限、ad-hoc 签名重编译后的 TCC 重置需要手动处理；
- Windows 版本尚未开始（按确认：macOS 先）。

## 目录

```
macos/
├── Sources/            Swift 源码
├── Info.plist          LSUIElement / bundle id
├── build.sh            构建 + 自测
└── build/ScanCode.app  产物
```
