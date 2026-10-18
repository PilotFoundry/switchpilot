# SwitchPilot QA 基线审计（v0.2 HEAD）与 v0.3 验收矩阵

- 审计者：独立 QA（只读源码/文档；未改源码、文档、Git、TCC、系统设置；仅写本文件）
- 基线对象：`a6ddaa5`（v0.2.0，Git HEAD 干净）。审计期间其他成员在共享工作区写入 v0.3 WIP；为避免半成品干扰，基线用 `git archive HEAD` 快照 `/tmp/switchpilot-qa-head` 独立构建执行，本文件基线数字全部来自该快照
- 环境：macOS 27.0.1 (26A434) arm64、SIP enabled、Gatekeeper enabled；CLT Swift 6.4（swift-driver 1.168.6），无完整 Xcode/XCTest
- 时间：2026-10-18 11:51–11:58 CST；未执行任何 TCC/屏幕状态/登录项变更动作

## 1. 基线结果（HEAD a6ddaa5）

| # | 检查 | 方法 | 实际结果 | 判定 |
|---|---|---|---|---|
| B1 | 版本/plist | bundle `plutil -p` + `plutil -lint` | 0.2.0；bundle id `local.personal.SwitchPilot`；LSUIElement=true；NSAppleEventsUsageDescription 存在；Info.plist entries=10；lint 通过 | PASS |
| B2 | 构建 | `./scripts/build-app`（干净快照，无 .build） | exit 0；`Build complete! (51.93s)`，墙钟 54.27s；输出 `.app` 路径；仅 `--build-system native` deprecated 警告×2（CLT 限制，预期） | PASS |
| B3 | 自动验收 | `python3 scripts/verify-app.py` | 8/8 通过（7.63s）：build / plists / signature / core checks **10/10** / launch smoke / leftover process（忽略基线中 1 个预存在实例）/ original app unchanged / static scripts | PASS |
| B4 | 核心自检 | `SwitchPilotChecks`（`swift build --show-bin-path` 定位） | 10/10，exit 0；appearance dark=false；engine=`/System/Library/CoreServices/ScreenSaverEngine.app`；Automation `-600`（System Events 未运行，非拒绝）、辅助功能未授权；未授权时锁屏拒绝执行 | PASS |
| B5 | 签名 | `codesign --verify --strict` / `-dv` / `-d --entitlements` | 通过；ad-hoc + Hardened Runtime（flags=0x10002）；entitlement `com.apple.security.automation.apple-events`；CDHash `dda8718…`；sealed files=0；`spctl` rejected（ad-hoc 预期，无 quarantine 仍可本地运行） | PASS |
| B6 | 启动/退出 | 快照二进制直接启动；3s 后 SIGTERM | 存活 >3s（pid 80950）；前后 `pmset` 均无 SwitchPilot 断言；退出码 143；无残留进程；stderr 有 `sandbox_extension_issue_file_to_process …`（代理环境限制，非应用错误） | PASS |
| B7 | 应用图标 | bundle Resources / Info.plist | **Resources 目录为空；无 CFBundleIconFile/CFBundleIconName；无任何 .icns** → Finder 等系统界面使用通用图标 | **缺口确认** |
| B8 | 菜单栏图标 | 代码 + SF Symbol 实测 | `NSImage(systemSymbolName: "switch.2")` 在本机可解析（16×14，template=true）；代码无 nil 回退（符号缺失则状态项无图） | PASS（带风险） |
| B9 | 原应用不变 | `defaults read` / `shasum -a 256` / `codesign --verify` | One Switch 1.35.4；主程序 sha256 `ee4551f9…`；签名通过 | PASS |
| B10 | 登录项基线 | `sfltool dumpbtm` / `~/Library/LaunchAgents` | 无 SwitchPilot BTM 记录、无 LaunchAgent plist；HEAD 代码无 SMAppService | PASS（基线） |
| B11 | 是否触发 TCC | 启动前后 `log show`（只读） | 无 `AUTHREQ_PROMPTING` 提及 SwitchPilot；`AXIsProcessTrusted` 仅做只读 TCCAccessRequest（不弹窗）；Automation 目标未运行 | PASS（未触发） |

说明：快照构建的二进制 SHA-256 为 `f1c3089…`、CDHash 为 `dda8718…`，与 `evidence/app-runtime.md` 记录的 `f3185f0…`/`01e7ecb…` 不同——debug 构建对路径敏感，两者不可直接比较，不作为回归失败。

## 2. 环境限制与审计边界

- TCC 状态不可程序化读取：`~/Library/Application Support/com.apple.TCC` 在当前系统不可访问（路径 ENOENT/受保护），无法用 sqlite 查询授权；只能由用户看系统设置或应用 UI。统一日志 `log show` 可读（只读）。
- 代理进程是 TCC “responsible process”：日志显示由 DSH 启动的应用被归属到 `com.deepseek.dsh`（无 automation entitlement）。**从代理 shell 启动的 app 无法真实验证 TCC 提示/图标归属**，手测必须由用户从 Finder/`open` 启动。
- ad-hoc 重建改变 cdhash，TCC 可能把新构建视为新应用并要求重新授权（docs/PRD 已记录）；验收需记录每次 cdhash。
- 无完整 Xcode/XCTest；native SwiftPM 构建已 deprecated、非零警告，属既定限制。
- 审计期间工作区被并发写入（v0.3 WIP）；主工作区一次构建报 `input file modified during build`（未改源码）；为做干净构建，曾在发现问题前对主工作区执行 `swift package clean`（仅删除 .build 生成物）。
- 存在预存 v0.2 应用实例 pid 23882（11:38 启动，`switchpilot.hasSeenWelcome=1`）；`verify-app.py` 以基线 PID 忽略。手测 TCC/登录项/多实例前应先退出，避免身份与实例歧义。
- 本轮自动化只创建/释放秒级 IOPM 断言、启动并终止应用、只读日志；未锁屏、未启动屏保、未切外观、未请求/撤销 TCC、未注册登录项。

## 3. 图标审计：缺失资源与系统显示位置

- 当前 bundle 无应用图标资源（见 B7），但菜单栏图标由 SF Symbol 提供（不依赖 icns）。因此所有“应用图标”类界面会显示通用图标；菜单栏显示正常。
- 菜单栏图标实现：`AppDelegate` 中 `NSImage(systemSymbolName:"switch.2", accessibilityDescription:"SwitchPilot")` + `isTemplate=true` + `button.toolTip`；只有 `switch.2` 单一静态符号（不随保活状态变化）。
- 系统会显示应用 logo/图标的位点（v0.3 需逐一验收）：

| 显示位置 | 当前（HEAD）表现 | v0.3 验收点 |
|---|---|---|
| Finder 列表/图标视图/Get Info | 通用应用图标 | 自定义图标出现且清晰 |
| Spotlight 结果/Launchpad（若入 /Applications） | 通用 | 同上 |
| TCC 授权弹窗（Automation/Accessibility） | 通用图标；代理启动时责任进程可能是 DSH | 自定义图标 + 正确应用名 |
| 系统设置 › 隐私与安全性 各权限列表 | 显示应用名；无自定义图标资源 | 图标正确 |
| 系统设置 › 通用 › 登录项与扩展 | 未注册，无条目 | 图标 + 名称 + 状态 |
| 通知中心/通知横幅（若 v0.3 发通知） | 未发送 | 图标正确 |
| Dock / Cmd-Tab | 不应出现（LSUIElement=true，需人工确认） | 仍不得出现 |
| 菜单栏 | `switch.2` 模板符号，正常 | 可见、可点、随外观着色 |

## 4. 权限流程审计（HEAD 实现）

| 操作 | 使用 API / 服务 | 会否弹窗 | 失败/错误码路径 | 未授权时行为 |
|---|---|---|---|---|
| 启动、面板刷新 | Automation 预检 `AEDeterminePermissionToAutomateTarget(…, false)`；`AXIsProcessTrusted()`；`CFPreferencesCopyAppValue` 读外观 | 否 | 0/-1743/-1744/-600/unknown 映射；AX bool | 全部只读功能可用：保活、屏保、外观显示、权限摘要、打开设置 |
| 深色模式开关 | 先预检；非 allowed 直接拒绝；否则 `NSAppleScript` 写 System Events 后读回 | 否 | `-1743`→permission；`-1744`；脚本错误号；`readbackMismatch` | 开关回弹，不改系统外观，行内显示“需要授权” |
| “请求授权…” | `AEDeterminePermissionToAutomateTarget(…, true)`；目标未运行再发无害读以拉起 System Events | 是（仅用户点击后） | 拒绝后保持 -1743，不再重复弹窗 | 显示状态/系统设置入口 |
| 锁定屏幕 | 需 Automation + Accessibility；System Events 注入 Ctrl+Cmd+Q | 申请时可能弹窗（仅用户点击） | 缺任一权限→`LockScreenError.permissions`，**不发送按键**；脚本错误号 | 显示缺权限，不执行 |
| 打开设置 | `x-apple.systempreferences:…Privacy_Automation/Accessibility` | 否（打开系统设置窗口） | URL 构造失败则静默 | 可用 |
| 启动屏保 | `NSWorkspace` 启动 ScreenSaverEngine | 无 TCC | `engineMissing` / `launchFailed` | 可用（会改变屏幕状态） |
| 撤销/批量授权 | HEAD 未实现；v0.3 WIP 出现 `tccutil reset`（见 §6 风险） | 视实现 | 需记录真实 OSStatus | 不应在未授权时执行写操作 |

自动化/人工分界：

- 可自动：构建、plist、签名、版本、核心自检、只读权限预检与错误码映射、启动冒烟与退出清理、只读日志（无 prompt 证据）、bundle 图标静态检查、BTM/LaunchAgents 只读检查、静态红线扫描。
- 必须人工（用户在场）：任何 TCC 允许/拒绝/撤销、辅助功能勾选、首启引导交互、登录项注册/注销/重启、图标在系统 UI 的显示、对比度/键盘/VoiceOver、屏保与锁屏真实动作。
- 禁止自动化：`tccutil reset`、TCC.db 写入、`SMAppService.register/unregister`、修改系统设置、`screencapture`/VoiceOver 自动化（会触发屏幕录制/辅助功能 TCC）、锁屏/屏保（改变屏幕状态）。

## 5. v0.3 验收矩阵

图例：**自**=可自动；**手**=人工目视/交互；**【改】**=会改变系统或用户状态，必须用户在场、先记录基线并可恢复。前置：从 HEAD 构建 v0.3.0；记录 cdhash、`defaults read local.personal.SwitchPilot`、`sfltool dumpbtm`、TCC 现状；手测一律从 Finder 启动。

| ID | 测试项 | 方法 | 预期证据 | 边界与失败判定 |
|---|---|---|---|---|
| A1 | 首启不自动触发 TCC | 自：启动冒烟 + `log show` 过滤 `AUTHREQ_PROMPTING`/SwitchPilot；手：目视 | 无弹窗、日志无 prompt 记录；仅显示引导 | 失败=任一 TCC 弹窗或日志 prompt；边界：干净 TCC 状态 |
| A2 | 首启引导内容/跳过/重开 | 手【改】：先备份再 `defaults delete`；关闭、重开、重启 | 三条规则+权限说明；可“稍后”；footer 可重开；键持久化 | 失败=无法跳过/每次启动重复/说明与真实权限不符 |
| A3 | 批量授权：Automation 允许 | 手【改】：点“一键授权”，弹窗选允许 | 弹窗一次；“已授权”读回；深色模式可切换并回读 | 失败=无弹窗/假成功/重复弹；边界：拒绝→重启→再授权 |
| A4 | 批量授权：Automation 拒绝 | 手【改】：弹窗选“不允许” | -1743 状态；不重复弹；给系统设置入口；外观不变 | 失败=反复请求/显示成功/崩溃 |
| A5 | 辅助功能引导（无程序化授权） | 手【改】：跳系统设置手动勾选，回面板“重新检查” | 跳转正确面板；勾选后状态更新（可能需重启 app） | 失败=跳错面板/状态不刷新；边界：勾选前返回、撤销后重进 |
| A6 | 已授权/已看过引导路径 | 自读 defaults + 手点按 | 不强制重复引导；“使用说明”可重开 | 失败=已授权仍强制引导 |
| B1 | 设置内“重新申请”语义 | 手【改】：未决定、拒绝、撤销后分别测 | 未决定→弹窗一次；-1743 不重复弹，指向系统设置 | 失败=把系统禁止重复弹窗解释为成功/无反馈 |
| B2 | “撤销”不得程序化改 TCC | 自：静态扫描无 `tccutil`/TCC.db/私有 API（白名单审查）；手：点“撤销” | 仅打开系统设置或二次确认后由用户手动撤销；日志无 tccutil 调用 | 失败=调用 `tccutil reset`/改 TCC.db（红线，需回滚并记录） |
| B3 | 外部撤销 Automation 后读回 | 手【改】：系统设置关掉 → 面板刷新/重启 | 状态=被拒绝/未授权；深色模式回弹、不发命令 | 失败=仍显示已授权/假成功/崩溃 |
| B4 | 外部撤销 Accessibility 后锁屏门控 | 手【改】：取消辅助功能 → 点锁屏 | 不发送按键、显示缺权限、无锁屏动作 | 失败=仍发送按键/锁屏（高风险） |
| B5 | 重建（ad-hoc cdhash 变化）后 TCC 失效 | 自记新 cdhash + 手测重授权 | 显示未授权并引导重授；不崩溃、不误报已授权 | 失败=崩溃/静默失效/误导 |
| C1 | 登录项状态只读映射 | 自：`SwitchPilotChecks` 读 `SMAppService.mainApp.status`，不注册 | notRegistered/enabled/requiresApproval/notFound/unknown 映射且不崩溃 | 失败=测试中注册/注销（红线）或崩溃 |
| C2 | 开启登录时启动 | 手【改】：用户点开关，必要时系统设置批准 | 应用状态与系统登录项条目一致；ad-hoc 被拒时显示真实错误 | 失败=显示已开启但无条目/崩溃；前置：记录 BTM 基线 |
| C3 | 系统设置外部禁用/批准前状态 | 手【改】：系统设置切换/关闭登录项 → 应用刷新 | 状态读回 requiresApproval/notRegistered；不自动强注册 | 失败=强制写回/状态过期 |
| C4 | 关闭登录时启动 | 手【改】：应用内关闭，查条目消失 | 条目消失；重启后不自启 | 失败=残留/仍自启 |
| C5 | 重启/注销后自启与单实例 | 手【改】：重启登录 | 菜单栏图标出现一次、进程 1 个、无重复断言 | 失败=不自启/双启/断言重复 |
| C6 | 卸载/移动后残留 | 手【改】：退出并移走 .app，查 BTM/LaunchAgents | 记录残留与清理步骤（不自动改系统） | 失败=无记录（残留本身可接受，必须记录） |
| D1 | 图标资源与 Info.plist 引用 | 自：build 后查 `Resources/AppIcon.icns`、CFBundleIconFile、plutil、codesign 封签 | icns 存在、被 Info.plist 引用、被签名封签 | 失败=缺失/名字不一致/未封签 |
| D2 | 图标多尺寸与暗色适配 | 自：`file`/`sips -g` 校验 16–1024；手：目视 | 各尺寸存在且非空白；暗背景下有边界 | 失败=缺小尺寸/模糊 |
| D3 | Finder/Get Info/Spotlight/Launchpad 图标 | 手：Finder 查看 | 自定义图标出现，非通用空白 | 失败=通用图标 |
| D4 | TCC 提示/隐私列表/登录项/通知图标 | 手【改】：触发一次 Automation 提示、查看登录项列表 | 各系统界面显示自定义图标与应用名 | 失败=通用图标/错位 |
| D5 | 菜单栏图标可见/可点/模板适配 | 自：StatusIcon 非空/template/bitmap、SF Symbol 解析；手：浅/深/高对比 | 图标可见、点击开合面板、随菜单栏着色 | 失败=空白不可点/不适配；边界：符号缺失回退 |
| D6 | 状态变化时图标/提示一致性 | 手：保活开/关观察菜单栏与面板 | 图标/状态胶囊与真实断言一致 | 失败=状态不同步 |
| E1 | 深浅外观对比度 | 手：浅色/深色各截图 | 正文/按钮可读（建议正文≥4.5:1、大字≥3:1） | 失败=文字或边框看不清 |
| E2 | 增加对比度/降低透明度 | 手：系统辅助功能开关各看一次 | 控件边界与文字仍可辨 | 失败=按钮消失 |
| E3 | 禁用/可用态区分 | 手：权限未授予 vs 已授予 | disabled 按钮明显不同且不误导 | 失败=看不出是否可点 |
| E4 | 键盘/焦点/VoiceOver | 手：Tab/Space/Return 与 VoiceOver | 全控件可达、名称/状态可读 | 失败=不可达/无标签 |
| E5 | 缩放/分辨率/小尺寸 | 手：不同显示器缩放、窗口尺寸 | 不截断、按钮在可视区 | 失败=裁切/按钮移出 |
| F1 | 基线回归 | 自：build/verify/checks/启动冒烟/原应用不变 | 全绿；无 TCC、断言、进程残留 | 失败=任一非零或残留 |
| F2 | 自动化副作用红线 | 自+对比：运行前后 `pmset`、`sfltool dumpbtm`、unified log、defaults | 前后一致；无 tccutil/register/unregister；无 TCC 授权变化 | 失败=系统状态被改 |
| F3 | 预存在实例/多实例 | 手：先确认无遗留实例，再测双开 | 记录真实行为；不把“无单实例限制”误判为通过 | 失败=断言/图标混乱且未记录 |
| F4 | 版本/文档一致 | 自：plist + verify 断言 | 0.3.0；README/TECH/TESTPLAN 同步 | 失败=版本不一致/文档写“已通过” |

## 6. 风险（按严重度）

1. **`tccutil reset` 红线（v0.3 WIP 已出现）**：`Permissions.resetTCC` 会执行 `/usr/bin/tccutil reset AppleEvents|Accessibility <bundleid>`，真实删除用户授权、可能触发重新授权，无法自动恢复原授权。QA 不执行；建议改为“打开系统设置由用户手动撤销”，若保留则必须二次确认+明确影响+仅用户点击，并只做人工验收。
2. **`SMAppService` 注册/注销改变系统登录项状态**：写入 BTM，可能触发批准通知/系统设置条目变化；测试必须先记录可恢复命令（unregister），自动测试只读 `status`，注册/注销需用户在场。
3. **ad-hoc 重建使 TCC 身份失效**：每次 build 后 cdhash 变化，旧授权可能失效；验收顺序把 TCC 授权/撤销放最后，记录 cdhash 与每步状态，“重建后仍已授权”不能作为通过标准。
4. **代理环境不能真实验证 TCC 提示**：responsible process 为 DSH 且缺 automation entitlement；从代理 shell 启动时弹窗归属/图标不可信，且可能显示 DSH 身份。手测必须 Finder/`open` 启动；自动化只能证明“启动不触发 prompt”。
5. **首启引导依赖 UserDefaults**：现有 `switchpilot.hasSeenWelcome=1`，v0.3 新增键需备份/重置才能测首启（改变用户偏好，可恢复）；测试前后记录 `defaults read`。
6. **预存实例与多实例**：pid 23882 仍在运行；`NSApplication` 未强制单实例（v0.2 已知限制），会干扰 TCC/登录项/多实例判断，手测前先退出。

## 7. 建议的自动化补充

- `verify-app.py`：增加图标断言（bundle 内 `AppIcon.icns` 存在、magic/尺寸、Info.plist 引用、codesign 封签）、版本 0.3.0、静态红线扫描（`tccutil`/`TCC.db`/`register(`/`unregister(` 调用点必须白名单且仅用户触发）、启动前后 `AUTHREQ_PROMPTING` 日志对比、登录项前置断言（`sfltool dumpbtm | grep SwitchPilot` 为空、无 LaunchAgents plist）。
- `SwitchPilotChecks`：StatusIcon 非空/尺寸/template/bitmap；LoginItemState 全映射（含 unknown）；`Permissions.bundleIdentifier` 非空；v0.3 引导状态机抽纯函数后单测。
- 增加只读诊断入口（参数/env 输出 JSON：版本、cdhash、automation 状态、AX、登录项状态），便于自动采集且不触发 TCC；不要用 `screencapture`/VoiceOver 自动化。
- 每次验收记录：cdhash、`defaults read`、`sfltool dumpbtm`、`pmset -g assertions`、`log show --last 10m` 摘要；手测截图由用户保存。
- 自动检查禁止执行：tccutil、TCC.db 写入、SMAppService 注册/注销、锁屏、屏保、切换外观、`defaults write/delete`（测试专用备份恢复除外）。

## 8. 本轮未执行 / 未验收

- 未执行任何 TCC 请求/允许/撤销、未修改 TCC 或系统设置、未锁屏/启动屏保/切换外观、未注册登录项、未做自动截图或 VoiceOver。
- 未做 M1–M3、M5、M7 等现场人工项；v0.3 WIP 未纳入基线。本基线仅代表 HEAD `a6ddaa5` 的构建/静态/只读运行时状态。
