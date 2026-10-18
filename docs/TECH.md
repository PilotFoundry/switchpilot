# TECH：个人自用菜单栏应用 v0.1 实现与接口

日期：2026-10-18；对应 PRD：`docs/PRD.md`、DESIGN：`docs/DESIGN.md`；证据摘要：`evidence/features/*`、`evidence/app-runtime.md`。

## 1. 技术栈与约束

- macOS 27.0.1 (26A434)，Apple Silicon arm64；Swift 6.4（Command Line Tools），macOS 27.0 SDK。
- 构建：SwiftPM（`--build-system native`，CLT 无 XCTest 时的回退；Swift 6.4 已提示该构建系统 deprecated），无完整 Xcode 许可。
- 应用形态：`.app` bundle，`LSUIElement=true`（无 Dock 图标），AppKit `NSStatusItem` + `NSPopover` + SwiftUI `NSHostingController`。
- 签名：ad-hoc + Hardened Runtime，entitlement 仅 `com.apple.security.automation.apple-events`（与 Automation 权限请求相关，不绕过 TCC）。
- 无网络、无第三方依赖、无后台常驻 helper、无私有 API；不修改原 One Switch 及其数据。

## 2. 代码结构

```
app/SwitchPilot/
├── Package.swift                 # SwitchPilotCore / SwitchPilot / SwitchPilotChecks
├── Info.plist                    # LSUIElement、NSAppleEventsUsageDescription、bundle id
├── Entitlements.plist            # automation.apple-events
├── Sources/SwitchPilotCore/      # 可测试逻辑与系统接口封装
│   ├── PowerAssertion.swift
│   ├── KeepAwakeSession.swift
│   ├── DarkMode.swift
│   ├── ScreenSaver.swift
│   ├── LockScreen.swift
│   └── Permissions.swift
├── Sources/SwitchPilot/          # 菜单栏应用（AppDelegate + PanelModel + PanelView）
└── Sources/SwitchPilotChecks/    # 标准库自检可执行文件（替代 XCTest）
scripts/build-app                 # 构建 + bundle + ad-hoc 签名 + 校验
scripts/verify-app.py             # 自动化验收脚本
```

模块划分原则：Core 不依赖 UI，可被自检程序直接调用；UI 层只做状态编排与呈现。

## 3. 功能实现

### 3.1 显示器保活（P0，已验证）

- 接口：IOKit `IOPMAssertionCreateWithName(kIOPMAssertPreventUserIdleDisplaySleep, kIOPMAssertionLevelOn, "SwitchPilot personal" as CFString, &id)`；释放 `IOPMAssertionRelease(id)`。
- 读回：`IOPMAssertionCopyProperties(id)` 检查 `kIOPMAssertionTypeKey == "PreventUserIdleDisplaySleep"` 且 `kIOPMAssertionLevelKey == 255`；释放后再读应不存在。
- 语义边界：只阻止"用户空闲导致的显示器休眠"，不阻止合盖、手动睡眠、低电量睡眠；与原版 `caffeinate -d` 的常规表现对齐，不承诺合盖行为。
- 生命周期：开启/时长到期/关闭/退出/错误路径各释放一次；保证 Create/Release 配对，不重复释放。
- 计时：`Timer`（主 RunLoop）每秒刷新剩余秒数；到时释放并回调 UI；`deinit`/退出兜底释放。测试钩子允许秒级时长以做真实断言生命周期自检。
- 失败：`IOPMAssertionCreateWithName` 返回非 `kIOReturnSuccess` 时抛错并显示原始 `IOReturn` 值；读回不一致视为失败并释放。

### 3.2 系统深色模式（P1，权限门控）

- 目标进程：System Events（bundle id `com.apple.systemevents`）。
- 命令来源（本机脚本字典）：`appearance preferences` 的 `dark mode` 布尔属性（前轮证据 `evidence/features/dark-mode.md`）。
- 读：AppleScript `tell application "System Events" to tell appearance preferences to get dark mode`（需授权）。
- 写：同属性 setter；写入后立即读回，读回不一致报错，不显示成功。
- 无权限时的只读展示：`CFPreferencesCopyAppValue("AppleInterfaceStyle", kCFPreferencesAnyApplication)` 为 `Dark` 时显示深色；仅用于展示，不视为受支持 API，也不替代 AppleScript 读回。
- 预检：`AEDeterminePermissionToAutomateTarget(systemEvents, typeWildCard, typeWildCard, false)`：
  - `noErr`：已授权可写；
  - `-1743`：被拒绝，显示设置入口，不重试；
  - `-1744`：尚未决定，显示"请求授权…"入口；用户点击后先调用 `AEDeterminePermissionToAutomateTarget(..., true)`，目标未运行时再发送一次无害 System Events 读取以启动目标并让系统提示出现（仅用户主动触发，不在启动时执行）；
  - `-600`：目标进程未运行或不可判定，按"需要授权/首次请求"处理，不自动弹窗。
- 失败：保留真实 `NSAppleScriptErrorNumber`/OSStatus；不吞错、不伪装成功。
- 不做"退出恢复"：深色模式是用户可见的系统持久设置，开关即用户意图。

### 3.3 启动屏保（P2，静态验证，运行时待现场验收）

- 实现：`NSWorkspace.shared.openApplication(at: ScreenSaverEngine.appURL, configuration:)` 启动系统应用 `/System/Library/CoreServices/ScreenSaverEngine.app`（bundle id `com.apple.ScreenSaver.Engine`，版本 5.0，LaunchServices 可解析；本机只读核验）。
- 依据：原版主程序存在 `ScreenSaverEngine` 字符串与 `EnableScreensaveSwitch` 类；原版本地化文案为"屏幕保护/随时手动打开"（见 `evidence/features/screen-saver.md`）。
- 无 TCC 权限要求；属于"启动系统应用"而非公开 API，系统升级可能改变行为。
- 读回：启动后 best-effort 检查 `NSRunningApplication.runningApplications(withBundleIdentifier:)`；无法可靠读回时 UI 显示"已请求，未确认"。
- 动作前确认（会立即启动屏保，可能需密码解锁）；不后台自动触发。

### 3.4 锁定屏幕（P3，权限门控，运行时待现场验收）

- 原版实现线索：`LockScreenSwitch` 类 + 主程序字符串 `tell application "System Events" to keystroke "q" using {command down,control down}`（见 `evidence/features/lock-screen.md`）。等价于系统快捷键 Ctrl+Cmd+Q。
- 实现：同一 AppleScript 通过 System Events 发送按键；等价效果由系统快捷键持有者（System Events）执行。
- 权限：需要 Automation（System Events）与 **Accessibility**（UI 脚本/按键注入）：
  - `AXIsProcessTrusted()` 只读检查；
  - `AEDeterminePermissionToAutomateTarget(..., false)` 同上映射；
  - 缺少任一权限时**不发送按键**，只显示缺少项、错误码与设置入口（辅助功能 `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`、自动化对应面板）。
- 读回（best-effort）：`CGSessionCopyCurrentDictionary()` 的 `CGSSessionScreenIsLocked` 布尔（`CGSessionCopyCurrentDictionary` 为公开 API，10.3+；该键未在当前公共 SDK 头文件中声明，属未文档化键，必须标注不确定性）。读不到时显示"已请求，未确认"。
- 不使用的路径：私有 `SACLockScreenImmediate`/`CGSession -suspend`、修改 TCC 数据库、关闭 SIP、重签原应用。
- 不把 `pmset displaysleepnow` 当锁屏等价物；它是原版"显示器休眠"功能的线索，锁屏语义不同（是否锁屏取决于系统"唤醒需要密码"设置）。

### 3.5 权限汇总

| 权限 | 用途 | 触发方式 | 未授权时行为 |
|---|---|---|---|
| Automation（System Events） | 深色模式读写；锁屏按键注入 | 用户点击开关/授权按钮后由系统提示 | 只读状态、显示"需要授权"与入口，不写系统设置 |
| Accessibility | 锁屏按键注入（UI 脚本） | 用户手动在系统设置中勾选 | 不发送按键，显示辅助功能设置入口 |

不申请 Full Disk Access、屏幕录制、输入监控、蓝牙等无关权限；不注册全局事件监听。

## 4. 生命周期与状态

- `NSApplication` accessory 模式；`applicationDidFinishLaunching` 创建状态项与 popover。
- 单实例：v0.1 不强制单实例；重复启动会出现多个菜单栏图标与独立断言（已知限制，见 §9）。
- 退出：`applicationWillTerminate`/退出按钮调用 `model.shutdown()`：释放保活断言、停止计时器、关闭 popover。
- 崩溃/强退：保活断言由系统在进程退出时回收；本轮沿用前轮证据，不额外安装守护进程。
- 状态刷新：动作成功后主动读回并更新 `@Published` 状态；计时器每秒更新剩余时间。

## 5. 构建与运行

```sh
scripts/build-app                 # 构建并输出 .app 路径
swift run --package-path app/SwitchPilot --build-system native SwitchPilotChecks
python3 scripts/verify-app.py     # 自动化验收
open app/SwitchPilot/.build/SwitchPilot.app
```

- `build-app` 复制 Info.plist、构建产物到 `SwitchPilot.app`，执行 `codesign --force --sign - --options runtime --entitlements Entitlements.plist`，再用 `codesign --verify --strict` 校验。
- 首次运行无权限提示；只有用户点击相关动作才会触发 Automation 提示或打开设置。
- 重新构建会改变 ad-hoc cdhash，TCC 可能把新构建视为新应用而要求重新授权；个人使用可接受，正式分发需 Developer ID + 公证。

## 6. 数据与隐私

- 不写全局偏好（除深色模式这一用户显式触发的系统设置，经 System Events）。
- 不修改原 One Switch 的 app、偏好、数据；不读取其私有数据库。
- 应用自身只在内存保留状态；v0.1 不持久化设置（时长为会话内选择）。
- 日志仅 `os.Logger` 本地统一日志；不联网、不上传、不包含用户数据。

## 7. 测试钩子

- `SwitchPilotChecks`（标准库可执行文件）：时长解析、权限映射、真实断言三轮生命周期、定时释放、屏保引擎解析、锁屏权限快照、深色模式全局外观只读。
- `scripts/verify-app.py`：构建产物、plist、签名、启动冒烟、无残留断言、原应用 hash/签名不变、日志摘要。
- 不依赖 XCTest（CLT 缺失）；不声称运行不存在的静态分析器。

## 8. 失败与降级策略

| 场景 | 行为 |
|---|---|
| 权限未授予 | 不执行写操作；显示原因与入口；不反复弹窗/重试 |
| 权限被拒绝 | 显示错误码；不自动重试；用户可去系统设置修改 |
| 目标进程不在 | 首次操作由系统启动 System Events；预检 `-600` 不当成拒绝 |
| 系统能力缺失（屏保引擎） | 动作禁用并说明；不伪造成功 |
| 读回失败 | 显示"已请求，未确认"；不进入 active 状态 |
| 应用退出 | 释放断言；不残留计时器 |

## 9. 已知限制（v0.1）

- 深色模式真实授权/读写/拒绝/撤销、屏保与锁屏运行时行为、睡眠/唤醒、设备切换均未在本轮自动执行，需用户在场按 `docs/TESTPLAN.md` 验收。
- 锁屏读回键未文档化；屏保/锁屏的机制属于系统行为依赖，不是公开 SDK 合约。
- 无完整 Xcode、无 XCTest、非零警告构建；无 Sandbox/公证/Developer ID。
- 单实例未强制；菜单栏图标不随状态变化；无设置持久化、无多语言。
- 未做 VoiceOver/键盘全路径验收；仅代码层使用标准控件并给出标签。
