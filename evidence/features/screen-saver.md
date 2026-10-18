# 屏幕保护：原行为线索与个人版实现

对象 One Switch 1.35.4 (440)，arm64 主 slice SHA-256 `0c3ba5c7a8f840d13114046283d2609e2bbd2762e69c359c85f5649c8f247528`；REA 6.5.0 / Ghidra 12.1.4。原始只读查询：`evidence/raw/rea/mvp-queries/`、`evidence/raw/rea/mvp-trace-queries/`（不入 Git）。

## 已观察证据（事实）

- `Contents/Resources/DefaultSwitches.plist` 存在 `EnableScreensaveSwitch`，`switchNameKey = screen-saver`，`enableByDefault = true`；类名 `One_Switch.EnableScreensaveSwitch`。
- 本地化文案：zh-Hans `screen-saver = 屏幕保护`；en `screen-saver = Screen Saver`；欢迎页 `welcome-screen-saver.description = 不知道何时进入屏保？现在你可以随时手动打开。` / `Sometimes you would like to turn it on manually.`。
- 主程序字符串 `ScreenSaverEngine` 位于 `0x100209de0`（REA `trace_feature` literal 匹配；无自动 xref 结果时只按字符串记录）。
- 系统侧：`/System/Library/CoreServices/ScreenSaverEngine.app` 存在，bundle id `com.apple.ScreenSaver.Engine`，版本 5.0，AdHoc/平台签名的系统应用；`NSWorkspace.urlForApplication(withBundleIdentifier:)` 可解析（本机只读核验，2026-10-18）。
- 另有一条 AppleScript 路径：System Events 脚本字典包含 Screen Saver Suite，命令 `start` / `stop`，属性 `current screen saver`；未采用（见下）。

## 推断（不是已验证事实）

- 原版"屏幕保护"开关很可能是通过启动系统 `ScreenSaverEngine` 实现，而非调用公开 SDK；字符串存在且与类名/文案一致，但本轮未对 `EnableScreensaveSwitch` 的具体调用函数做反编译确认（init 只是类初始化壳）。
- 启动 ScreenSaverEngine 属于"启动系统自带应用"的系统行为依赖，不是 Apple 公开 API 合约；未来 macOS 可能改变路径或启动方式。

## 个人版实现候选

- 采用 `NSWorkspace.openApplication(at:configuration:)` 启动 `ScreenSaverEngine.app`，执行前二次确认（会立即改变屏幕状态，可能触发唤醒密码）。
- 不做持续开关、不写屏保偏好、不调用 System Events 启动屏保（避免与深色模式共用权限门控时引入额外提示）。
- 启动后 best-effort 检查 `ScreenSaverEngine` 进程；读不到可靠状态时显示"已请求，未确认"。

## 未验证 / 风险

- **运行时未执行**：为避免打断当前会话或在"唤醒需要密码"设置下意外锁屏，本轮没有真正启动屏保；`docs/TESTPLAN.md` M2 为需用户在场的验收步骤。
- 无法读回"屏保是否真的显示"；进程存在不等于用户看到屏保。
- 系统升级可能改变引擎路径/bundle id；实现会在引擎缺失时显示不可用而不是重试。
- 与"显示器休眠"是不同功能；原版另有 `DisplaySleepSwitch` / `display-sleep` 文案与 `displaysleepnow` 线索，本版不实现，避免语义混淆。
- 补充：REA `xrefs` 对字符串地址 `0x100209de0` 返回空数组（2026-10-18 查询），未定位到调用函数；字符串地址匹配是事实，调用关系仍按推断处理。
