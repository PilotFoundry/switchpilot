# SwitchPilot UX 评审：首启授权、权限入口、登录启动与设置

- 评审人：ux-reviewer（独立 UX 评审，非实现者）｜日期：2026-10-18 12:00 CST
- 对象：① 用户提供的 v0.2.0 面板截图（1088×1298，含红框标注；任务给的附件路径与实际文件名有哈希差异，已按同目录实际文件评审）② 当前工作区未提交的 v0.3 WIP（Info.plist 已到 0.3.0，新增 SettingsModel/SettingsView/LoginItem 等）。
- 方法：只读源码/文档/SDK 头/Apple 文档；**未执行任何 TCC、系统设置、登录项写操作，未运行应用**；外部网页只作参考。
- 结论：核心保活/屏保无需权限、路径正确；**权限界面尚未达到"第一次打开就知道点哪里"**（用户红框即证据）。建议先修 4 个 P0、8 个 P1；批量撤回不应内置发布。HIG/启发式综合 **2.6/5**。

## 1. 摘要

- v0.2 把权限状态拆到外观行、锁屏行、footer 三处；锁屏行同时出现"Automation：已授权"与"请求 Automation…"，真正缺失的辅助功能入口却是弱化的 borderless 按钮，用户自然会问"点哪里授权"——**结论：不清晰**；根因是状态与动作按"功能"而非"缺失权限"组织。
- 首启只有三条规则 + "知道了"，没有"申请全部权限"入口；设计稿还写明"点锁屏磁贴只更新行内说明"（`artifacts/20261018-1138-oneswitch-naming-ui-redesign.html:126`、HEAD `PanelView.swift:230-255`），截图证明该设计不可理解。
- v0.3 WIP 已补首启申请按钮、设置窗口（权限/登录/关于）、SMAppService 登录项、可读性主题色，方向正确；但"全部申请"仍是一步打开系统设置、未用 AX 系统提示，登录项状态机与 tccutil 撤回有实质风险（见 §5）。
- 批量撤回结论：`tccutil reset Accessibility|AppleEvents <bundle>` 受支持、默认只影响当前用户（sudo 才影响所有账户）；但 Apple 将其定位为开发/测试工具，无恢复 API、无提示再现保证，`reset All` 会清空所有应用所有隐私决定——**不推荐在应用内提供批量撤回**，只保留设置深链 + README 手动命令。
- 登录启动：SMAppService.mainApp（macOS 13+）在本机 ad-hoc + `.build` 路径实测 `register()` 成功、`unregister()` 后 status 回到 notRegistered（`evidence/raw/app/login-item-test.log`），但系统 BTM 留有 disabled 记录、无 Developer Name；"登录后能否真正启动、重建后是否失效、requiresApproval UI"必须现场验证。

## 2. 推荐首启授权流程（谁触发什么系统 UI）

```
用户点菜单栏图标 → 首次打开面板（应用内 UI，不自动请求任何 TCC）
└─ 开始使用卡：3 条规则 +「保持亮屏/屏保无需权限」 + [申请全部权限] [稍后再说]
   ├─ 稍后再说 → 关闭引导；保活/屏保照常可用；footer「设置…」可随时再申请
   └─ 申请全部权限（只有用户点击才触发；启动时不请求）
      ├─ ① 应用调 AEDeterminePermissionToAutomateTarget(System Events, askUserIfNeeded:true)
      │   └─ tccd 弹系统 Automation 弹窗 [不允许] [允许]（系统 UI，应用不能代替选择）
      │      ├─ 允许 → 面板状态=Automation 已授权
      │      └─ 拒绝 → 状态=已拒绝；隐藏"申请"，只留 [打开自动化设置]（通常不再弹，需验证）
      ├─ ② 面板显示"下一步：开启辅助功能"（应用内说明，不叠加自定义模态）
      │   └─ 应用调 AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt:true])
      │      └─ 系统异步提示 → [打开系统设置] → 隐私与安全性 › 辅助功能 → 用户手动勾选
      │         （仅系统 UI 可授予；提示异步，返回值不能用来判断用户已拒绝）
      ├─ ③ 用户回面板点 [重新检查]（或面板再次打开时自动 refresh）
      │   └─ 仍缺 → 降级：保活/屏保可用；深色/锁屏行只列缺失项与设置入口
      └─ ④ 登录时启动不是权限：设置 › 登录 → SMAppService.mainApp.register()
            └─ 系统写入登录项；status=requiresApproval → 显示 [打开登录项设置] 请用户批准
```

- **降级矩阵**：拒绝 Automation → 深色模式不可用（开关回弹、不写外观）；拒绝辅助功能 → 锁屏不发送按键；两者都不影响保持亮屏、启动屏保；面板显示缺失原因与设置入口，不重复弹窗。
- **再申请路径**：设置 › 权限 › [申请全部权限] 为主入口（面板 footer「设置…」可达）；对应行也可单独申请；已被拒绝时只能打开系统设置，不再尝试系统弹窗。

## 3. 权限能力矩阵（申请 / 再申请 / 撤销）

| 能力 | 用途 | 首次申请（谁触发系统 UI） | 可程序化？ | 再申请 | 撤销 | 风险/结论 |
|---|---|---|---|---|---|---|
| Automation（AppleEvents → System Events） | 深色模式读写；锁屏按键注入 | 应用调 `AEDeterminePermissionToAutomateTarget(ask:true)`，tccd 弹窗 | 可触发提示；仅未决定时；-600 需先启动目标进程 | 被拒(-1743)后系统不再弹，只能打开"自动化"设置；未决定/-600 可再请求 | 系统设置›自动化 关闭/删除，或 `tccutil reset AppleEvents <bundle>` | 撤销后功能降级、需重新授权；应用不可恢复授权 |
| Accessibility | 锁屏按键注入（System Events UI 脚本） | 无程序化授予；`AXIsProcessTrustedWithOptions(prompt:true)` 异步提示并引导到系统设置，用户手动勾选 | 只能提示/打开设置；`AXMakeProcessTrusted` 需 root 且 10.9 弃用，不用 | 再次提示或手动"+"/勾选；提示是否重现需现场验证 | 系统设置›辅助功能 取消勾选/删除，或 `tccutil reset Accessibility <bundle>` | 应用无通知回调，要主动 refresh；重置后列表可能不显示，需提示/手动重新添加 |
| 批量撤回（研究项） | 测试/维护 | `tccutil reset <Service> [bundle]`；Apple 文档明确列出 Accessibility、AppleEvents、All | 技术上非沙盒 app 可 spawn `/usr/bin/tccutil`；**不推荐** | 无恢复 API，只能重走申请 | 默认仅当前用户；sudo 才影响所有账户；`reset All` 清空所有应用所有隐私决定 | 不可逆、可能需重启/重新授权；Apple 定位为开发测试；应用内批量撤回是反模式 |
| 无需权限 | 保持亮屏、启动屏保 | 无系统 UI | 是 | N/A | 无需撤销 | 这是拒绝全部权限后的保底能力，文案必须明说 |

注：登录时启动不是 TCC 权限，见 §4；`tccutil reset All`（不带 bundle id）**禁止**在应用中调用。不推荐做法：① 无 bundle 的 `reset All`；② sudo/root 提权；③ 静默或自动执行；④ 不告知"需重启/重新授权"；⑤ 直接读写 TCC 数据库或使用私有 API。

## 4. 设置页信息架构与登录项设计

- **入口**：保留面板 footer「设置…」；增加状态项右键菜单「设置… / 使用说明 / 退出」。accessory/LSUIElement 应用平时不显示 App 菜单，Cmd+, 入口不可依赖（HIG Settings / Menu bar extras），必须给出可见入口。
- **窗口**：单窗格 `SwitchPilot 设置`（HIG 允许单窗格用 "App Name Settings" 标题），约 460pt；打开时刷新；从系统设置返回或窗口重新激活时自动刷新，并保留 [重新检查]。
- **权限区**：固定两行（Automation → System Events、辅助功能），每行=状态图标 + 名称 + 一句用途 + 唯一动作（已授权→无按钮；未决定→申请；已拒绝→打开系统设置）。顶部 [申请全部权限] + [重新检查]（即"再次发起全部申请授权"入口）；底部说明"保持亮屏/屏保无需权限；随时可在系统设置撤销"。
- **登录区**：`Toggle on = enabled || requiresApproval`；`requiresApproval` 显示 [打开登录项设置]；错误给中文原因 + 手动添加备用路径；说明"由系统登录项管理，移动应用或重新构建后请复查"。
- **关于区**：版本、bundle id、应用路径、签名（ad-hoc）、菜单栏行为、卸载/恢复步骤、文档链接——便于 ad-hoc 重建后核对 TCC 身份。
- **不要**：把"撤销授权"放主界面；如保留，收进"高级/维护"折叠，bundle-scoped、无 sudo/无 All、二次确认并说明需重启与重新授权（见 P0-3）。

### 4.1 登录项状态 → UI（SMAppService.mainApp.status）

| status | 含义（本机/文档） | Toggle | 文案 | 动作 |
|---|---|---|---|---|
| notRegistered | 未注册 | 关 | 未开启 | 开启（register） |
| enabled | 已注册可启动 | 开 | 已开启（登录时启动） | 关闭（unregister） |
| requiresApproval | 已注册但用户/系统未批准 | **开** | 需要批准 | [打开登录项设置] |
| notFound | 系统未找到；本机实测未注册状态下返回此值 | 关 | 未开启（首次开启时注册） | 开启；失败给手动添加指引 |
| 错误（kSMError*） | register/unregister 失败 | 恢复原状态 | 中文原因 + 详情（OSStatus/domain） | [打开登录项设置]，重建后复查 |

- ad-hoc / 非 /Applications：SDK 头只要求"code signed"，未规定主应用必须在 /Applications（LaunchDaemon 才有 /Applications 与公证建议）；MacOSX27.0 SDK 头无新增限制/弃用标记，仍是 macOS 13+ API。本机 ad-hoc `.build` 路径注册成功，但不能承诺登录时一定启动，也未验证重启与重建。建议固定路径（/Applications 或 ~/Applications）+ 稳定签名（Apple Development/Developer ID 或固定自签证书）；否则每次重建 cdhash 变化，登录项与 TCC 身份都可能失效，需重新开启。
- 用户批准 UI：register 后出现在 系统设置›通用›登录项；`requiresApproval` 用 `SMAppService.openSystemSettingsLoginItems()` 引导；系统可能发"后台项目已添加"通知（未验证本机文案）。不要回退到 LaunchAgent plist / `SMLoginItemSetEnabled`。

## 5. 发现清单

### P0（阻断"首次可用/不误导"）

- **P0-1 锁屏行让用户找不到"点哪里授权"**（截图红框三处：需授权徽标、橙色说明、两个按钮）
  - 证据：footer 明写 `Automation：已授权 · 辅助功能：未授权`；橙色文案仍称"需要 Automation + 辅助功能"，主按钮却是"请求 Automation…"（已授权、点击无效），真正需要的"打开辅助功能设置"是 borderless；点磁贴只在下方小字写 `锁屏：未执行：缺少权限`（HEAD `PanelView.swift:230-255`、`PanelModel.swift:155-185`；设计稿 artifacts:126 明确此行为）。
  - 建议：按缺失项生成唯一主 CTA；此处主按钮="打开辅助功能设置"，Automation 只显示 ✓；磁贴点击展开/聚焦该权限行，不再只写远处小字；文案统一为"缺少：辅助功能"。
  - 验收：Automation=allowed、AX=false 时界面不得出现"请求 Automation"；点击磁贴后 1s 内出现展开/焦点；用户可仅凭面板完成授权。
- **P0-2 首启没有可执行的"全部申请"状态机**
  - 证据：v0.2 引导只有三条规则 + "知道了"（HEAD `PanelView.swift:68-107`）；v0.3 `requestAllPermissions()` 直接 `openAccessibilitySettings()`，未调用 AX 提示、未说明"分 2 步、可能被拒"；Automation 被拒时仍可能显示"已发起 Automation 授权"（`PanelModel.swift:215-230`、`SettingsModel.swift:31-50`）。
  - 建议：按 §2 顺序执行并显示每步状态与下一步；不使用第二个自定义模态（HIG Privacy 的 pre-alert 规则）；任何一步拒绝都保留保活/屏保。
  - 验收：删除 `switchpilot.hasSeenWelcome` 后手测允许/拒绝两遍；被拒时无"已发起"假状态；保活/屏保始终可用。
- **P0-3 应用内批量撤回不可发布**
  - 证据：v0.3 `Permissions.resetTCC` 用 `Process` 调 `/usr/bin/tccutil reset Accessibility|AppleEvents <bundle>`（`Permissions.swift:108-142`），`SettingsView.swift:68-85` 以"撤销授权…"暴露；Apple 文档将 tccutil 定位为开发/测试，撤销无恢复 API、提示不保证再现（Accessibility 还要重新加入列表），`reset All` 会清空所有应用隐私决定；`waitUntilExit()` 在主线程还会冻结 UI。
  - 建议：移出主 UI；若保留个人维护能力，改为隐藏"维护"入口或 README 命令，bundle-scoped、绝不 sudo/All，并说明需重新授权/重启；更推荐只提供系统设置深链。
  - 验收：默认构建中不存在可达的 tccutil reset 调用（或位于显式隐藏开关后）；文档给出手动命令；若保留，手测并记录 stdout、重启与重新授权路径。
- **P0-4 权限动作的 scope 与状态不匹配**
  - 证据：外观行主按钮"申请 Automation 授权"实际调 `requestAllPermissions()`，会顺带打开辅助功能设置（`PanelView.swift:220-228` → `PanelModel.swift:215-230`）；锁屏行同样；Automation 已被拒时仍显示"申请"类按钮（TCC 通常不再弹）。
  - 建议：按入口定义动作矩阵：未决定→请求；已拒绝→打开设置；targetNotRunning→请求+说明；已授权→不显示动作；failed→打开设置+详情。外观行只请求 Automation，锁屏行只打开缺失项设置；"全部申请"只在引导/设置出现。
  - 验收：allowed/denied/notDetermined × AX true|false 组合走查，按钮文案与点击结果一致、请求范围不超该行。

### P1（影响可理解性/恢复）

- **P1-1 登录项状态机**：`requiresApproval` 时 Toggle 显示关，再点开会 `register()` → `kSMErrorAlreadyRegistered`；未注册状态下 `status=.notFound` 会在设置显示"系统未找到登录项"（本机实测：`login-item-test.log` 的 `before=系统未找到登录项`），像故障。建议 Toggle on=(enabled||requiresApproval)；notFound 归为"未开启/待注册"；错误映射中文并给 [打开登录项]；register 后以读回状态为准。
- **P1-2 AEDeterminePermissionToAutomateTarget 在主线程**：SDK 头明确"may take arbitrarily long / 不要在 main thread 调用"（`AppleEvents.h:347-363`），当前 `PanelModel`/`SettingsModel` 在主线程调用，等待系统弹窗期间菜单栏面板会卡住。建议后台队列 + 主线程回写，按钮显示"等待系统授权…"。
- **P1-3 设置可发现性**：v0.3 只有面板 footer「设置…」，无状态项右键菜单、无 App 菜单/设置快捷键（accessory 应用限制）。建议右键菜单 + header/footer 设置入口；首次引导末尾提示可去设置重复申请。
- **P1-4 撤销/拒绝后的状态与再申请**：撤销后要等打开面板/设置或手动 [重新检查] 才更新；"再申请全部"对 denied 的 Automation 语义错误（见 P0-2/P0-4）。建议监听应用激活/窗口 key 自动 refresh；denied 文案="已在系统设置中被拒绝，去重新开启"，不显示"请求"。
- **P1-5 辅助功能引导缺少系统提示与手动添加**：当前仅打开设置页，用户可能在列表找不到 SwitchPilot（尤其 ad-hoc 重建后身份变化）。建议 `AXIsProcessTrustedWithOptions` 提示 + 文案"若列表没有，用 + 添加或按系统提示重新加入"，并提示"完成后回面板重新检查"。
- **P1-6 权限信息重复与术语漂移**：同一屏出现"需授权/未授权/已授权/待授权/需要授权"，分布在徽标、橙色说明、状态行、footer。建议单一权限模型 + 固定词表（已授权/未授权/已拒绝/检查中），面板只留一条摘要 + 设置入口承载详情。
- **P1-7 11pt 状态色对比与无障碍**：v0.2 截图的橙色 `需授权`/说明是 caption2 小字，系统橙在浅色底对比不足；v0.3 `Theme.warningInk` 已改善但未验收。建议小字用 primary/secondary + 图标，橙色只用于图标/填充；徽标加 accessibilityLabel（与 ui-reviewer 的视觉评审交叉核对）。
- **P1-8 单实例与登录启动叠加**：登录项 + 手动打开可能产生多个菜单栏图标（TECH §9 已知），登录启动后更易触发。建议 Info.plist `LSMultipleInstancesProhibited` 或启动时检测并激活已有实例，至少在登录项文案说明。

### P2（打磨/文档）

- **P2-1 技术味文案**：磁贴副标题"等价 Ctrl+Cmd+Q"、UI 直接显示 `-1743`、`Automation` 英文；建议"发送系统锁定快捷键" + 详情折叠，OSStatus 只在错误详情/日志。
- **P2-2 状态胶囊"空闲"**：语义是保活状态而非应用状态；建议"保活：关闭"/"保护中"或明确胶囊 scope。
- **P2-3 快速动作状态行过长**：`屏保：… · 锁屏：自动化已授权；辅助功能仍需检查` 混状态与权限、窄面板可能截断；建议状态放 tile 内，权限单独一行。
- **P2-4 面板高度**：v0.2 640 / v0.3 720 固定 contentSize，首启引导 + 权限面板可能超出小屏或放大字体；建议自适应或允许 popover 滚动，并在 1280×800/深色/大字号验收。
- **P2-5 成功态冗余**：v0.3 引导同时显示"权限已就绪"绿标与 disabled"检查权限"按钮；建议只留一个完成态；"已授权，可以切换"这类一次性消息应自动消失或改为状态行。
- **P2-6 版本/文档漂移**：Info.plist 已是 0.3.0、新增设置窗口与登录项，但 PRD/DESIGN/TECH 仍写 v0.2.0；DESIGN §2 明确"不提供设置窗口…登录项"，PRD §4 把登录自启列为非目标。需求 2/3 已改变范围，收口前必须同步文档，并在 TESTPLAN 增加"授权引导/登录项/撤销恢复"手动项。

## 6. 需要用户现场验证（评审未执行任何写操作）

1. **首启全流程**：退出所有实例 → `defaults delete local.personal.SwitchPilot switchpilot.hasSeenWelcome`（需你同意）→ 从 Finder 打开（关键：代理启动会被归到 DSH 的 responsible process，不能验证 TCC 归属）→ 允许/拒绝各走一遍，记录弹窗文案与下一步提示。
2. **Automation**：允许后切深色/浅色各 3 次并读回；系统设置撤销后重开面板/设置，确认显示"已拒绝"而非假成功；再点"申请全部"确认不会假装重新弹窗。
3. **辅助功能**：触发 AX 系统提示，确认提示与 [打开系统设置]；勾选后 [重新检查] 生效；撤销后锁屏拒绝发送按键；再申请时提示是否重现、是否需重启应用。
4. **登录时启动**：开启后到 系统设置›通用›登录项 确认状态；注销/重启验证自动出现菜单栏图标；在系统设置关掉后回应用确认"需要批准"；重建 ad-hoc 后再看登录项是否仍有效。
5. **ad-hoc 重建与身份**：记录每次 cdhash；重建后检查 TCC 授权、登录项、系统设置列表是否变化，验证"需重新授权"文案。
6. **批量撤回（不推荐，仅研究）**：如仍要验证，只执行 bundle-scoped 命令（`tccutil reset AppleEvents local.personal.SwitchPilot`、`tccutil reset Accessibility local.personal.SwitchPilot`），不要 sudo、不要 `reset All`；记录退出码/输出/是否需重启/重新授权路径。
7. **视觉与无障碍**：浅色/深色下 11pt 状态文字对比度、徽标与按钮 VoiceOver 读数、Tab 键序、放大字体/小屏不截断（与 ui-reviewer 合并验收）。

## 7. HIG / 可用性启发式评分（v0.2 截图为主，v0.3 改进未验收）

| 维度（HIG / Nielsen） | 分 | 依据 |
|---|---|---|
| 首次引导（HIG Onboarding：快、可选、可跳过、可再找到） | 3/5 | 有三条规则、可关闭、可重开；但无一键申请/步骤化路径，关闭后无权限完成引导 |
| 权限请求（HIG Privacy：需要时请求、说明用途、给选择与降级） | 2/5 | 用户点才请求（好）；锁屏/外观动作错配、拒绝后无法重试、Accessibility 无提示、批量撤回反模式 |
| 状态反馈（HIG Feedback：状态靠近对象、可理解） | 3/5 | 有胶囊/进度/读回（好）；锁屏反馈远离点击点、多处重复、术语不统一 |
| 一致性与标准（Nielsen #4 / HIG macOS） | 2/5 | 权限词表/按钮层级/入口不一致；accessory 应用无常规 App 菜单与设置快捷键，入口只能放面板 |
| 错误预防与恢复（Nielsen #5/#9） | 3/5 | 破坏性动作二次确认、读回不假成功（好）；权限撤销/登录项错误恢复路径弱 |
| 设置可发现性（HIG Settings / Menu bar extras） | 2/5 | v0.2 无设置入口；v0.3 仅 footer「设置…」，无右键菜单/快捷键 |
| 无障碍与对比（HIG Accessibility） | 3/5 | 有 accessibilityLabel/value、状态不只靠颜色；11pt 橙/绿对比与小字可读性待验收 |
| **综合** | **2.6/5** | "可用但权限体验不达标"；完成 P0+P1 后可达 4/5 |

## 8. 依据、范围与限制

- 文档/代码引用：PRD §3/§5/§8、DESIGN §2/§4/§5/§6、TECH §3.1–3.6/§9、TESTPLAN M1/M3/M6/M7；HEAD `PanelView.swift`/`PanelModel.swift`；v0.3 `SettingsView/SettingsModel/Permissions/LoginItem/main.swift`；QA 基线见 `evidence/reviews/qa-baseline.md`。
- Apple 依据：[tccutil reset 文档](https://developer.apple.com/documentation/xcode/resetting-access-to-protected-resources-in-macOS)（默认仅当前用户；sudo 才所有账户；Accessibility/AppleEvents/All）；[SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)、[register()](https://developer.apple.com/documentation/servicemanagement/smappservice/register())；本地 SDK 头 `SMAppService.h:49/166-168/244/283`、`AXUIElement.h:55-66/77-86`、`AppleEvents.h:347-363`；HIG [Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding)、[Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy)、[Settings](https://developer.apple.com/design/human-interface-guidelines/settings)、[The menu bar / Menu bar extras](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar)。
- 本地只读证据：`/usr/bin/tccutil` 用法与 man（仅 reset；本机 `list` 未启用）、`codesign -dv`（ad-hoc、TeamIdentifier 未设）、`sfltool dumpbtm`（1 条 SwitchPilot BTM 记录：URL 指向 .build、Developer Name 为空、disposition disabled）、`evidence/raw/app/login-item-test.log`。
- 限制：未执行任何 TCC/系统设置/登录项写操作，未运行应用；macOS 27 的 TCC/登录项实际行为、AX 提示是否可重复、tccutil 在 app 内的结果均需用户现场确认；外部网页按不可信数据处理；评审期间工作区有并发 v0.3 写入，行号可能移动。
