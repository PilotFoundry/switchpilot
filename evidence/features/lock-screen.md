# 锁定屏幕：原行为线索与个人版实现

对象 One Switch 1.35.4 (440)，arm64 主 slice SHA-256 `0c3ba5c7a8f840d13114046283d2609e2bbd2762e69c359c85f5649c8f247528`；REA 6.5.0 / Ghidra 12.1.4。原始只读查询：`evidence/raw/rea/mvp-queries/`、`evidence/raw/rea/mvp-trace-queries/`（不入 Git）。

## 已观察证据（事实）

- `DefaultSwitches.plist` 存在 `LockScreenSwitch`，`switchNameKey = lock-screen`，`enableByDefault = false`；类名 `One_Switch.LockScreenSwitch`。
- 本地化：zh-Hans `lock-screen = 锁定屏幕`；en `Lock Screen`。
- 主程序字符串位于 `0x100209fc0`：
  `tell application "System Events" to keystroke "q" using {command down,control down}`
  （REA `trace_feature` literal 匹配；这是 macOS 的 Ctrl+Cmd+Q 锁屏快捷键等价按键）。
- 原应用 `Info.plist` 含 `NSAppleEventsUsageDescription = "One Switch requires automation features to control third-party apps."`，entitlements 含 `com.apple.security.automation.apple-events`（来自原包只读检查）。
- 原主程序字符串含 `#Critical Unable to create event tap: make sure Accessibility is enabled`；该字符串也可能来自其快捷键录制依赖，不能单独证明锁屏需要辅助功能。
- 本机不存在旧路径 `/System/Library/CoreServices/Menu Extras/User.menu/.../CGSession`。
- 原版另有 `DisplaySleepSwitch` / `display-sleep = 显示器休眠` 与 `displaysleepnow` 字符串；这与锁屏是不同功能，不能把 `pmset displaysleepnow` 当作锁屏等价物。

## 推断（不是已验证事实）

- 原版锁屏很可能就是向 System Events 发送 Ctrl+Cmd+Q 按键（字符串与类名/文案一致；未对实际调用函数完成反编译确认）。
- 通过 System Events 注入按键需要 **Automation**（控制 System Events）与 **Accessibility**（UI 脚本/按键注入）两类授权；缺少任一授权时按键不会生效。
- `CGSessionCopyCurrentDictionary` 的 `CGSSessionScreenIsLocked` 键可用于 best-effort 读回；`CGSessionCopyCurrentDictionary` 是公开 API（macOS 10.3+），但该键未在当前公共 SDK 头文件中声明，读不到时必须标"未确认"。

## 个人版实现

- 同一 AppleScript（与系统 Ctrl+Cmd+Q 等价），仅在 Automation 与 Accessibility 都满足时发送；缺权限时只显示缺失项与设置入口，**不发送按键**。
- 执行前二次确认（会立即锁定屏幕，需要密码解锁）。
- 执行后 1 秒 best-effort 读回 `CGSSessionScreenIsLocked`；不可用则显示"已请求锁定（未确认）"。
- 不采用私有 API（`SACLockScreenImmediate`、`CGSession -suspend`）、不修改 TCC、不关闭 SIP、不重签原应用。

## 未验证 / 风险

- **运行时未执行**：本轮没有授予 Accessibility、没有发送按键、没有真正锁屏（避免把用户锁在外面）；`docs/TESTPLAN.md` M3 为需用户在场的验收步骤。
- 该路径属于 UI 脚本，Apple 可能在未来系统限制；权限摩擦高于深色模式。
- 如果用户不接受 Accessibility 授权，锁屏应降级为"打开系统锁屏设置/提示使用 Ctrl+Cmd+Q"，不能声称可用。
- ad-hoc 签名重新构建后 TCC 可能视为新应用，需要重新授权。
- 补充：REA `xrefs` 对字符串地址 `0x100209fc0` 返回空数组（2026-10-18 查询），未定位到调用函数；字符串地址匹配是事实，调用关系仍按推断处理。
