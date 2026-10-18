# 系统深色模式：脚本入口与 Automation 风险

One Switch 1.35.4 (440)，arm64 主 slice `0c3ba5c7a8f840d13114046283d2609e2bbd2762e69c359c85f5649c8f247528`；REA 6.5.0 / Ghidra 12.1.4。

## 已观察证据

- 包内存在 `enableDarkMode.scpt`（SHA-256 `b8fbbd3bdf042bb703d2b2c7375efdaae5cc9c439c1ca13fd45442cbd3b756ab`）及 `disableDarkMode.scpt`（SHA-256 `1fd47ffd61589ce6092c5f840a7ebabe7581c0340ed1bd53a6a4c16129421d86`）。前次 osadecompile 返回 errOSASourceNotAvailable (-1756)，本轮不重复恢复源文本，也未执行这些原始脚本。
- 编译脚本 strings 包含 `System Events.app` 路径、四字符术语码 `aprp`、`thme`。系统自带 `SystemEvents.sdef` 将 aprp 映射到 appearance preferences、thme 映射到 dark mode。这是目标/属性证据，不是恢复出的完整脚本源码。
- 主程序导入 NSAppleScript；三个可见 executeAndReturnError 调用位置为 0x100007d80、0x1000a33bc、0x1000a3704，不能不加区分地都标为深色模式调用。
- 0x10004fe60：NSUserDefaults.stringForKey 查询；汇编在 0x10004fe90 引用 `AppleInterfaceStyle`，伪代码比较 Swift small string `Dark`。这解释原版状态查询线索，不保证该偏好键是公开长期 API。
- 0x1000521f4：EnableDarkModeSwitch 的 observeValueForKeyPath 入口；0x100056058：下拉选择入口。完整排程、定位与失败 UI 没有被本轮证明。

## 新实现规格

使用独立 bundle identity 发送自写 AppleScript：读取 `tell application "System Events" to tell appearance preferences to get dark mode`；设置则使用同一属性的布尔 setter。AppKit 的 NSApplication.appearance 只能改变本应用，不能代替系统外观切换。

- 先用 AEDeterminePermissionToAutomateTarget(..., askUserIfNeeded: false) 检查权限，不主动弹窗；未授权则返回 blocked/denied，不显示切换成功。
- 只有已有授权且能读到原始布尔状态时才允许执行短时切换；每次写入读回，结束恢复原值并读回。
- 若不能确认没有原版自动排程/用户操作竞争，本轮仅验证读回和权限拒绝，不自动改变外观。权限获得、撤销与恢复需要真实测试，不能用 stub 通过替代。
- 错误须保留真实 Apple Event OSStatus / NSAppleScriptErrorNumber，不吞掉权限失败。
- 原版 Automation 拒绝后的具体 UI/错误处理尚未证实。未来产品规格应明确失败提示、设置入口及重新读取状态。

## 规范依据与边界

本机 System Events 脚本字典 Appearance Suite 是脚本能力来源；[Apple NSAppleEventsUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nsappleeventsusagedescription) 要求用途说明；Hardened Runtime 的 [automation.apple-events entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.automation.apple-events) 允许请求权限，不绕过 TCC。[App Sandbox](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox) 的限制需单独评估。

结论：**可用 Automation 候选独立实现，需真实授权/状态/恢复验证；不等同于无权限依赖的全局外观 SDK setter。** 不恢复原脚本源码也能撰写行为规格和独立实现。

补证：通用脚本执行函数入口 0x100007bf8（0x100007d80 在函数内）读取 bundle URLForResource、NSAppleScript.initWithContentsOfURL:error: 后调用 executeAndReturnError:；失败/无值路径返回空结果。静态调用者包括深色模块范围的 0x100053464、0x100054bc8、0x10005508c、0x100055190、0x100055654，尚未把每个枚举参数恢复到确切资源名。0x10004fd18 经查询属于 EmptyPasteboardSwitch，排除为深色路径，避免按相邻地址误归类。
