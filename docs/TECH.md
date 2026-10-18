# TECH：SwitchPilot 个人自用菜单栏应用 v0.3 实现与接口

日期：2026-10-18；对应 PRD：`docs/PRD.md`、DESIGN：`docs/DESIGN.md`；正式名与设计依据：`artifacts/20261018-1138-oneswitch-naming-ui-redesign.html`；证据摘要：`evidence/features/*`、`evidence/app-runtime.md`。v0.2 = 正式命名 + 面板/引导重设计；v0.3 = 权限首启流程 + 设置/登录启动 + 品牌图标 + 对比度修复。

## 1. 技术栈与约束

- macOS 27.0.1 (26A434)，Apple Silicon arm64；Swift 6.4（Command Line Tools），macOS 27.0 SDK。
- 构建：SwiftPM（`--build-system native`，CLT 无 XCTest 时的回退；Swift 6.4 已提示该构建系统 deprecated），无完整 Xcode 许可。
- 应用形态：`.app` bundle，`LSUIElement=true`（无 Dock 图标），AppKit `NSStatusItem` + `NSPopover` + SwiftUI `NSHostingController`；版本 0.2.0。
- 正式名 SwitchPilot，bundle id 保持 `local.personal.SwitchPilot`：重命名 bundle id 会重置 TCC 授权，个人自用阶段不划算。
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
├── Sources/SwitchPilot/          # 菜单栏应用（AppDelegate / PanelModel / PanelView）
└── Sources/SwitchPilotChecks/    # 标准库自检可执行文件（替代 XCTest）
scripts/build-app                 # 构建 + bundle + ad-hoc 签名 + 校验
scripts/verify-app.py             # 自动化验收脚本
```

模块划分原则：Core 不依赖 UI，可被自检程序直接调用；UI 层只做状态编排与呈现。PanelModel 持有跨视图状态，避免使用 `@State`/`@AppStorage`：当前 CLT + native SwiftPM 构建缺少 SwiftUI 宏插件（SwiftUIMacros），这两个宏无法编译；因此引导可见性、是否已关闭引导都放在 PanelModel，并用 `UserDefaults("switchpilot.hasSeenWelcome")` 持久化。

## 3. 功能实现

### 3.1 显示器保活（P0，已验证）

- 接口：IOKit `IOPMAssertionCreateWithName(kIOPMAssertPreventUserIdleDisplaySleep, kIOPMAssertionLevelOn, "SwitchPilot personal" as CFString, &id)`；释放 `IOPMAssertionRelease(id)`。
- 读回：`IOPMAssertionCopyProperties(id)` 检查 `kIOPMAssertionTypeKey == "PreventUserIdleDisplaySleep"` 且 `kIOPMAssertionLevelKey == 255`；释放后再读应不存在。
- 语义边界：只阻止"用户空闲导致的显示器休眠"，不阻止合盖、手动睡眠、低电量睡眠；与原版 `caffeinate -d` 的常规表现对齐，不承诺合盖行为。
- 生命周期：开启/时长到期/关闭/退出/错误路径各释放一次；保证 Create/Release 配对，不重复释放。
- 计时：`Timer`（主 RunLoop，0.5s）刷新剩余秒数与进度 `fractionRemaining`（限时 1→0，无限期为 nil）；到时释放并回调 UI；退出兜底释放。测试钩子允许秒级时长以做真实断言生命周期自检。
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
- UI（v0.2）：未授权时开关回弹，状态行显示橙色"需要授权/首次操作会请求授权"，行内提供"请求授权…"与"打开系统设置"；不再用模态弹窗解释权限。
- 不做"退出恢复"：深色模式是用户可见的系统持久设置，开关即用户意图。

### 3.3 启动屏保（P2，静态验证，运行时待现场验收）

- 实现：`NSWorkspace.shared.openApplication(at: ScreenSaverEngine.appURL, configuration:)` 启动系统应用 `/System/Library/CoreServices/ScreenSaverEngine.app`（bundle id `com.apple.ScreenSaver.Engine`，版本 5.0，LaunchServices 可解析；本机只读核验）。
- 依据：原版主程序存在 `ScreenSaverEngine` 字符串与 `EnableScreensaveSwitch` 类；原版本地化文案为"屏幕保护/随时手动打开"（见 `evidence/features/screen-saver.md`）。
- 无 TCC 权限要求；属于"启动系统应用"而非公开 API，系统升级可能改变行为。
- 读回：启动后 best-effort 检查 `NSRunningApplication.runningApplications(withBundleIdentifier:)`；无法可靠读回时 UI 显示"已请求，未确认"。
- 动作前确认（会立即启动屏保，可能需密码解锁）；不后台自动触发。UI 为快速动作磁贴，读数不明时显示"已请求启动（未确认）"。

### 3.4 锁定屏幕（P3，权限门控，运行时待现场验收）

- 原版实现线索：`LockScreenSwitch` 类 + 主程序字符串 `tell application "System Events" to keystroke "q" using {command down,control down}`（见 `evidence/features/lock-screen.md`）。等价于系统快捷键 Ctrl+Cmd+Q。
- 实现：同一 AppleScript 通过 System Events 发送按键；等价效果由系统快捷键持有者（System Events）执行。
- 权限：需要 Automation（System Events）与 **Accessibility**（UI 脚本/按键注入）：
  - `AXIsProcessTrusted()` 只读检查；
  - `AEDeterminePermissionToAutomateTarget(..., false)` 同上映射；
  - 缺少任一权限时**不发送按键**，只显示缺少项、错误码与设置入口（辅助功能 `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`、自动化对应面板）。
- UI（v0.2）：缺权限时磁贴显示「需授权」，行内说明 + "请求 Automation…" / "打开辅助功能设置"；**不弹权限模态框、不发送按键**。权限齐备时才进入确认框。
- 读回（best-effort）：`CGSessionCopyCurrentDictionary()` 的 `CGSSessionScreenIsLocked` 布尔（`CGSessionCopyCurrentDictionary` 为公开 API，10.3+；该键未在当前公共 SDK 头文件中声明，属未文档化键，必须标注不确定性）。读不到时显示"已请求，未确认"。
- 不使用的路径：私有 `SACLockScreenImmediate`/`CGSession -suspend`、修改 TCC 数据库、关闭 SIP、重签原应用。
- 不把 `pmset displaysleepnow` 当锁屏等价物；它是原版"显示器休眠"功能的线索，锁屏语义不同（是否锁屏取决于系统"唤醒需要密码"设置）。

### 3.5 UI/UX 重设计（v0.2）

- 面板宽 360，单列分区：Header（名称/版本/状态胶囊）→ 首次引导卡 → 保持亮屏 → 外观 → 快速动作 → Footer。
- 主操作突出：保活开关 + 时长分段 + 进度条 + 剩余时间；无限期不显示进度。
- 首次引导：三条规则 + "知道了"；`UserDefaults("switchpilot.hasSeenWelcome")` 持久化；footer 可重新打开。
- 权限行内化：深色模式/锁屏的权限状态、原因与授权入口在对应行内；只有屏保/锁屏执行前保留 NSAlert 二次确认。
- macOS 27 方向：减少装饰图标、沿用 popover 系统材质、低对比卡片底色、系统语义色、统一圆角；不新增自定义皮肤。
- 可访问性：标准控件 + `accessibilityLabel`/`accessibilityValue`；状态不只靠颜色。

### 3.6 权限汇总

| 权限 | 用途 | 触发方式 | 未授权时行为 |
|---|---|---|---|
| Automation（System Events） | 深色模式读写；锁屏按键注入 | 用户点击开关/授权按钮后由系统提示 | 只读状态、显示"需要授权"与入口，不写系统设置 |
| Accessibility | 锁屏按键注入（UI 脚本） | 用户手动在系统设置中勾选 | 不发送按键，显示辅助功能设置入口 |

不申请 Full Disk Access、屏幕录制、输入监控、蓝牙等无关权限；不注册全局事件监听。

## 4. 生命周期与状态

- `NSApplication` accessory 模式；`applicationDidFinishLaunching` 创建状态项与 popover。
- 单实例：v0.2 不强制单实例；重复启动会出现多个菜单栏图标与独立断言（已知限制，见 §9）。
- 退出：`applicationWillTerminate`/退出按钮调用 `model.shutdown()`：释放保活断言、停止计时器、关闭 popover。
- 崩溃/强退：保活断言由系统在进程退出时回收；本轮沿用前轮证据，不额外安装守护进程。
- 状态刷新：动作成功后主动读回并更新 `@Published` 状态；计时器每 0.5 秒刷新剩余时间与进度。

## 5. 构建与运行

```sh
scripts/build-app                 # 构建并输出 .app 路径
swift run --package-path app/SwitchPilot --build-system native SwitchPilotChecks
python3 scripts/verify-app.py     # 自动化验收
open app/SwitchPilot/.build/SwitchPilot.app
```

- `scripts/install-app` 构建后把 `.app` 复制到 `~/Applications/SwitchPilot.app` 并注册 LaunchServices，便于 Finder 启动与稳定路径下的登录项；`scripts/uninstall-app` 仅删除该副本，不碰 TCC/登录项。
- `build-app` 复制 Info.plist、构建产物到 `SwitchPilot.app`，执行 `codesign --force --sign - --options runtime --entitlements Entitlements.plist`，再用 `codesign --verify --strict` 校验。
- 首次运行无权限提示；只有用户点击相关动作才会触发 Automation 提示或打开设置。
- 重新构建会改变 ad-hoc cdhash，TCC 可能把新构建视为新应用而要求重新授权；个人使用可接受，正式分发需 Developer ID + 公证。

## 6. 数据与隐私

- 不写全局偏好（除深色模式这一用户显式触发的系统设置，经 System Events）。
- 不修改原 One Switch 的 app、偏好、数据；不读取其私有数据库。
- 应用自身只在内存保留状态；v0.1 不持久化设置（时长为会话内选择）。
- 日志仅 `os.Logger` 本地统一日志；不联网、不上传、不包含用户数据。

## 7. 测试钩子

- `SwitchPilotChecks`（标准库可执行文件，v0.2 共 10 项）：时长解析、权限映射、真实断言三轮生命周期、定时释放、限时进度/无限期无进度、屏保引擎解析、锁屏权限快照、深色模式全局外观只读。
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

## 9. 已知限制（v0.2）

- 深色模式真实授权/读写/拒绝/撤销、屏保与锁屏运行时行为、睡眠/唤醒、设备切换均未在本轮自动执行，需用户在场按 `docs/TESTPLAN.md` 验收。
- 锁屏读回键未文档化；屏保/锁屏的机制属于系统行为依赖，不是公开 SDK 合约。
- 无完整 Xcode、无 XCTest、非零警告构建；无 Sandbox/公证/Developer ID。
- 单实例未强制；菜单栏图标不随状态变化；无多语言；仅持久化"引导是否已看过"。
- 正式名已确定（SwitchPilot），但分发前的商标/域名检索未做；本轮不改 bundle id。
- 未做 VoiceOver/键盘全路径验收；仅代码层使用标准控件并给出标签。

## 10. v0.3 增量实现

### 10.1 权限请求异步化

`AEDeterminePermissionToAutomateTarget` 可能阻塞（SDK 头明确不建议在主线程等待），因此权限预检与请求放到 `DispatchQueue.global(qos: .userInitiated)`，完成后再回主线程更新 `@Published` 状态；UI 显示"正在请求/检查…"。启动时不再同步预检。辅助功能使用 `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])` 显示系统提示；应用无法授予 Accessibility。

### 10.2 首启全部申请状态机

`PanelModel.requestAllPermissions()`：Automation 请求 → 若 Accessibility 未授权则系统提示 → 用户去设置勾选 → "重新检查"；`permissionSetupMessage` 按真实状态生成，拒绝时不会显示"已发起"。引导可见时隐藏重复的权限 callout。基本功能（保持亮屏、启动屏保）不依赖权限。

### 10.3 设置与登录项

- `SettingsWindowController` + `SettingsView`/`SettingsModel`：权限区（状态、申请全部、重新检查、辅助功能提示、两个系统设置深链、撤销说明）、登录区、关于。
- `LoginItem`：`SMAppService.mainApp.register()/unregister()/status`（macOS 13+）；状态映射 `notRegistered/enabled/requiresApproval/notFound`；`SMAppService.openSystemSettingsLoginItems()` 引导批准。实测（本机 ad-hoc + .build 路径）：register 成功、unregister 后回到 notRegistered（`evidence/raw/app/login-item-test.log`）；但登录后真实启动、requiresApproval、重建失效仍需现场验证。
- 单实例：启动时检测同 bundle 的其它实例，弹窗提示并退出；`SWITCHPILOT_SMOKE_TEST=1` 供自动化启动冒烟绕过。
- 状态项右键菜单：设置… / 使用说明 / 退出；应用激活时自动刷新权限状态。

### 10.4 品牌图标与构建

- `StatusIcon.make()`：代码绘制 template "S" monogram（16–18pt 光学居中），替换 SF Symbol。
- `Resources/AppIcon.icns`：1024 画布、824×824 内容居中、squircle、深绿渐变 + 奶油 S；`Resources/AppIcon.html` 为可重生成的源；`scripts/build-app` 复制 `.icns`；Info.plist `CFBundleIconFile=AppIcon`。小尺寸（16/32）仍可辨，但未在 Finder/TCC 提示现场确认。
- 自动验收新增：icon 资源存在/大小、对比度 token 脚本、面板尺寸、语义色静态检查；`verify-app.py` 共 11 项，`SwitchPilotChecks` 12 项。

### 10.5 批量撤回研究结论

`tccutil reset AppleEvents|Accessibility <bundle>` 在本机可用（man 仅列出 reset；`list` 子命令不可用）；默认只影响当前用户，sudo 才影响所有账户，`reset All` 会清空所有应用隐私决定。Apple 将其定位为开发/测试且无恢复 API。**应用内不自动执行**；设置页只提供系统设置深链与文案，README 给出手动 bundle-scoped 命令，避免不可逆副作用。

### 10.6 v0.3 已知限制

- 首启授权、TCC 弹窗归属/图标、从 Finder 启动、真实登录启动与重建失效、辅助功能提示是否重现，均需用户现场验证（见 TESTPLAN M1–M3/M8）。
- ad-hoc 重建改变 cdhash，TCC 与登录项身份可能失效；建议固定路径与稳定签名后再长期使用。
- 应用图标需重新注册/启动后在 Finder、系统设置、TCC 提示中目视确认；代理启动无法验证 responsible process。
- 菜单栏 S monogram 与 app icon 的 16px 可辨性仅离屏检查，未在浅/深/选中菜单栏状态实机确认。

## 11. v0.3.3：TCC 身份与权限探测修复

### 11.1 问题证据

- 用户 v0.3.2 设置页显示 Automation「待授权（首次操作时提示）」、辅助功能「未授权」，但用户已在系统设置授权。`log show --predicate 'subsystem == "com.apple.TCC"'` 显示 tccd 对当前 `~/Applications/SwitchPilot.app` 报 `Failed to match existing code requirement for subject local.personal.SwitchPilot and service kTCCServiceAccessibility`：授权记录属于之前的 ad-hoc 构建，重建后 cdhash 改变，当前二进制不匹配。
- 另：`AEDeterminePermissionToAutomateTarget` 在 System Events 未运行时返回 **-600**，被 UI 映射成"待授权"，即使 Automation 实际已授权也无法判定。

### 11.2 修复

- `Permissions.automationStatusResolvingTarget()`：-600 时后台启动 System Events（不激活、不发送 AppleEvent），等待后重跑只读 preflight，得到真实 0/-1743/-1744；设置/面板刷新与"重新检查"都走该函数。
- 签名：创建本机自签名身份 **SwitchPilot Local Signing**（Keychain，私钥不入 Git），`scripts/build-app` 优先用它签名，否则回退 ad-hoc；designated requirement 变为 `identifier "local.personal.SwitchPilot" and certificate leaf = H"02f684b1…"`，重建不再改变 TCC 匹配条件。
- 设置页在权限未就绪时显示诊断行（应用路径、Automation 原始状态、辅助功能布尔值）和"若系统设置已开启仍显示未授权，通常是签名身份变化"的提示；`--diagnose-permissions` 可把同样的信息写到 `/tmp/switchpilot-permission-diagnose.txt`。
- 已用 `tccutil reset AppleEvents local.personal.SwitchPilot` 与 `tccutil reset Accessibility local.personal.SwitchPilot` 清理旧 ad-hoc 授权记录（仅 SwitchPilot、当前用户），需要用户对稳定签名版本重新授权一次。
- 版本 0.3.3；verify-app 11/11、自检 12/12。

## 12. v0.3.4：设置页撤销授权 IA

- `SettingsModel` 新增 `showsRevokeHelp` / `showsAdvancedTCCUtil` / `tccutilCopied` 与复制状态；全部 @Published，避免 SwiftUI `@State` 宏依赖。
- `SettingsView.revokeDisclosure`：一级「如何撤销授权…」+ chevron 的 plain button；展开显示系统设置深链与二级「终端命令（高级）」；命令使用 `NSPasteboard` 复制，应用不执行。
- 成功态移除「申请全部权限」主 CTA，改为状态行；未就绪态按缺失权限分支（automation denied → 打开自动化设置；部分缺失 → 对应 CTA）。
- `SettingsWindowController` 改为 designated init，使用 Combine 订阅 `model.objectWillChange`，异步调用 `resizeToFit()`：`preferredContentSize` 变化时按内容调整窗口高度并保持顶边；展开实测 544 → 711。
- 预览钩子（仅 DEV/dump）：`SWITCHPILOT_PREVIEW_AUTHORIZED=1` 模拟已授权，`SWITCHPILOT_EXPAND_REVOKE=1` 展开，`--dump-settings` 渲染两态；`SWITCHPILOT_DEV=1` 才允许自动打开设置窗口。
- 验收：verify-app 11/11、自检 12/12；权限在重建/重签/重装后仍为 `已授权`（稳定签名身份实测）。

## 13. v0.3.5：应用内权限重置实现

- `Permissions.resetInAppPermissions()`：`Process` 调用 `/usr/bin/tccutil reset AppleEvents|Accessibility <bundle-id>`；仅这两个服务、仅当前用户、无 sudo、无 `All`；在后台队列执行，输出/退出码汇总；bundle id 从 `Bundle.main` 读取，无法确定时直接失败、不猜测。
- `SettingsModel.resetInAppPermissions()`：二次确认后调用（确认在 `SettingsView.confirmInAppReset()` 的 `NSAlert` 中，取消为默认，重置为 destructive），完成后刷新权限状态并提示重新授权；若状态未变提示重启。
- 安全边界：不是 Apple 官方支持 API；应用不自动调用；不提供静默/一键批量（重置范围固定本应用两项）；从 UI 默认路径与文案上仍推荐系统设置手动撤销。原先 QA 反对的是"应用内自动/静默 reset"，此实现改为用户显式确认的高级选项，且保留系统设置路径。
- 验证：build/verify 11/11、自检 12/12；tccutil 命令用不存在的 bundle id 试跑返回 `No such bundle identifier (-10814)`，未触碰真实授权；真实执行需用户在确认框中触发，列为 TESTPLAN M8 手动项。
