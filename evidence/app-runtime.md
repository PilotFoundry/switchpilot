# 个人自用 v0.1 应用运行验收

日期：2026-10-18。本文件按时间累积；当前构建见 v0.3.6 节。对象：`~/Applications/SwitchPilot.app`（bundle id `local.personal.SwitchPilot`，本地自签名 Hardened Runtime；早期节保留历史 ad-hoc 哈希）。规格：`docs/PRD.md`、`docs/TECH.md`、`docs/TESTPLAN.md`。原始日志：`evidence/raw/app/`（不入 Git）。

## 构建产物

| 项目 | 值 |
|---|---|
| 应用可执行文件 SHA-256 | `238524889cbe3f1949b05bb0191935618b340c7da178cd6757bd90de6e7fa5b3` |
| CDHash | `19e82d8cfb38560c9d88c19297356363ef98baa3` |
| 签名 | ad-hoc，CodeDirectory flags `0x10002(adhoc,runtime)`，Info.plist entries=10 |
| Runtime | 27.0.0；目标 arm64-apple-macosx27.0.0 |
| 构建工具 | CLT Swift 6.4（swift-driver 1.168.6），`--build-system native`；无完整 Xcode |

## 自动化验收结果

`python3 scripts/verify-app.py`：**8/8 通过**（2026-10-18 11:23 CST）。

| 检查 | 结果 |
|---|---|
| 构建（`scripts/build-app`） | 通过；输出 `.app` 路径 |
| plist（LSUIElement / usage description / automation entitlement / plutil） | 通过 |
| ad-hoc Hardened Runtime 签名（`codesign --verify --strict`） | 通过 |
| 核心自检 `SwitchPilotChecks` | **9/9 通过** |
| 启动冒烟（进程存活 ≥2s，SIGTERM 退出） | 通过 |
| 退出后无 `SwitchPilot` 电源断言 / 无残留进程 | 通过 |
| 原应用版本/hash/签名不变 | 通过（1.35.4，主程序 `ee4551f9…`，`codesign --verify --strict`） |
| Python/shell 语法检查 | 通过 |

`SwitchPilotChecks` 的 9 项：

1. 预设时长映射（15/30/60/无限期）；
2. 非正数/NaN/∞ 时长拒绝；
3. Automation 状态码映射（0/−1743/−1744/−600/未知）；
4. 三轮真实 IOPM 断言创建、读回、幂等 start、释放；
5. owner deinit 释放真实断言；
6. 定时会话到时自动释放（真实 OS 断言消失）；
7. 深色模式全局外观只读（当前 light）；
8. 屏保引擎可解析（`/System/Library/CoreServices/ScreenSaverEngine.app`）；
9. 未授予 Automation + Accessibility 时 `LockScreen.lock()` 抛权限错误且**未发送按键**。

## 权限预检与未执行动作

- 应用身份下预检：Automation `-600`（System Events 未运行，不能解释为拒绝）；Accessibility 未授权。
- 本轮自动化**没有**发送锁屏按键、没有启动屏保、没有切换深色模式、没有请求 TCC 授权、没有修改 TCC 数据库/系统设置。
- 启动冒烟未观察到本应用创建保活断言；退出后 `pmset -g assertions` 无本应用记录。

## 仍未验证（需用户在场，见 `docs/TESTPLAN.md` M1–M6）

- M1 深色模式真实授权、切换、读回、拒绝/撤销；
- M2 屏保真实启动与退出；
- M3 锁屏权限授予、锁定与解锁、读回；
- M4 睡眠/唤醒、合盖、长时间稳定性；强退清理仅自动化到 SIGTERM 冒烟，未做真实开关后强退的完整组合；
- M5 菜单栏图标/面板视觉、键盘、VoiceOver、深浅外观；
- M6 多实例、权限撤销后行为、卸载残留。

这些项目不得在 README/能力矩阵中记为通过。

## 成本记录

- 从 2026-10-18 11:14:46 开始读到 11:23:43 完成自动化验收，墙钟约 **8 分 57 秒**（含重复构建/启动冒烟；不含文档写作与最终审阅）。
- token、缓存、计费与人工工时：未知（无权威计量），不以估算冒充实测。
- 本轮未触发 GPT 限额；未使用新的重置卡/额度。

## v0.2 正式命名与面板重设计验收（2026-10-18）

- 正式名 SwitchPilot 确定；bundle id 保持 `local.personal.SwitchPilot` 以减少迁移；ad-hoc 重建后 TCC 仍可能要求重新授权。命名依据见 `artifacts/20261018-1138-oneswitch-naming-ui-redesign.html`。
- 面板重写：状态胶囊、首次引导卡（`UserDefaults("switchpilot.hasSeenWelcome")`）、保活进度条、外观/锁屏权限行内入口、动作磁贴、权限摘要 footer。
- `SwitchPilotChecks` 扩为 **10/10**：新增“限时进度 / 无限期无进度”检查。
- `python3 scripts/verify-app.py`：**8/8 通过**（构建、plists、ad-hoc Hardened Runtime 签名、自检 10/10、启动冒烟、无新增残留进程、原应用不变、脚本语法）。
- v0.2.0 可执行文件 SHA-256 `f3185f00fc8185aad1008a60c809028df10f4832677c1a6d05da3f7685ea76a7`，CDHash `01e7ecb48834f4b7981a44800bfcae413ce94f9d`。
- 用户 2026-10-18 口头确认 v0.1 初步验收可行（未提供逐项清单；不据此把 M1–M3 记为已通过）。v0.2 的新面板/引导交互验收（TESTPLAN M7）仍待用户手动确认。
- 本轮自动化同样未请求 TCC、未启动屏保、未发送锁屏按键、未切换系统外观。

## v0.3 反馈修复与独立评审验收（2026-10-18）

- 版本 **0.3.0**；应用图标 `Contents/Resources/AppIcon.icns`（1024 画布/824 内容/16–1024 全套）+ `CFBundleIconFile=AppIcon`；菜单栏为自绘 S monogram template 图标。
- 面板：单一不透明表面；新增 `secondaryInk`；权限 CTA 按缺失项分支；首启引导可"申请全部权限"；引导可见时隐藏重复 callout；面板逻辑尺寸 **380×672（无 guide）/380×710（guide）**。
- 设置窗口：权限（申请全部/重新检查/辅助功能提示/系统设置深链/撤销说明）、登录时启动（SMAppService）、关于；状态项右键菜单（设置/使用说明/退出）。应用内**不调用** tccutil reset（研究结论见报告 §05）。
- 登录项实测（`evidence/raw/app/login-item-test.log`）：初始 `notFound` → `register()` 后 `enabled` → `unregister()` 后 `notRegistered`；未验证登录后真实启动。
- `SwitchPilotChecks`：**12/12**；`scripts/verify-app.py`：**11/11**（新增对比度、面板尺寸、语义色静态检查；应用图标检查）。
- 对比度（`scripts/check-contrast.py`）：secondaryInk 浅色最差 5.15:1、深色最差 6.04:1；warning/success/error ink 浅色最差 5.50/5.99/6.03:1；全部 ≥4.5:1。
- 应用身份：可执行 SHA-256 `71a3db8f22117729cf5a6a022e808a161e12ee7cc9b7615834474a32da0e9b1d`，CDHash `322f452f00381553ef09afa69edfe7f2262f8ddc`。
- 独立评审（`evidence/reviews/`）：UI P0×1/P1×6、UX P0×4/P1×8、QA 基线 8/8+10/10；v0.3 已修主要 P0/P1，评审报告注明"修复后未复评"，真机 TCC/登录/图标/菜单栏三态仍未验证。
- 用户 2026-10-18 同意 SwitchPilot 转正；此前 v0.1 初步验收为口头确认，未逐项记录。

## v0.3.1 修复（2026-10-18）

- 修复：从设置页打开系统设置（自动化/辅助功能）后，返回或关闭系统设置窗口时，SwitchPilot 设置窗口会重新前置/保持可用；`SettingsWindowController` 设置 `hidesOnDeactivate=false` 并在应用重新激活时按标记重新 present；设置页打开系统设置前登记回调。权限仍需在系统设置中手动授予/确认，应用不代授。
- 新增 `scripts/install-app` / `scripts/uninstall-app`：构建后复制到 `~/Applications/SwitchPilot.app` 并注册 LaunchServices，便于 Finder/Launchpad 启动与稳定路径下的登录项；不修改 TCC/登录项。
- 版本 0.3.1；自动化 11/11、自检 12/12 复跑通过。

## v0.3.2（2026-10-18，视频复现修复）

- 用户调试视频（iShot 2026-10-18 12.18.14）复现：在 SP 设置页打开系统设置（自动化）→ 授权/关闭系统设置后，SP 设置窗口被其他窗口盖住，看起来消失，用户需重新点菜单栏才能继续；授权刚完成时也无法立刻“重新检查”。
- 根因：只依赖“应用重新激活”通知；关闭系统设置时若前台回到浏览器/其它应用，SP 不会激活，设置窗口不会回前台。
- 修复：打开系统设置时轮询前台应用；检测到系统设置曾在前台、随后离开（关闭/切换/退出）后，自动把 SP 设置窗口前置并刷新真实权限状态；180 秒超时自动停止。app activation 路径保留为兜底。
- 修复：持久轮询（设置窗口存在期间）+ `NSWorkspace.didActivateApplicationNotification` / `didTerminateApplicationNotification` 观察者；系统设置关闭/切换/退出后自动前置 SP 设置窗口并刷新权限；设置窗口关闭时停止观察。
- 版本 0.3.2；build/verify 复跑 11/11、自检 12/12；`--dev` 窗口自动打开钩子仅由 `SWITCHPILOT_DEV=1` 启用。

## v0.3.3：权限"已授权仍显示未授权"根因与修复（2026-10-18）

- 现象：用户已在系统设置开启 Automation / 辅助功能，SP 设置页仍显示"待授权（首次操作时提示）/未授权"，"重新检查"无变化。
- TCC 日证据（tccd）：`Failed to match existing code requirement for subject local.personal.SwitchPilot and service kTCCServiceAccessibility`，当前路径 `~/Applications/SwitchPilot.app`。说明授权记录属于旧 ad-hoc 构建；重建改变 cdhash 后当前应用不匹配。Automation 显示"待授权"的直接原因是 System Events 未运行（-600），非真实授权状态。
- 修复：自签名稳定身份 `SwitchPilot Local Signing`（Keychain，设计化要求 `identifier + certificate leaf = H"02f684b1…"`）；build-app 优先使用；-600 时启动 System Events 后重探测；设置页显示诊断行；`--diagnose-permissions` 输出当前状态。
- 已清理旧 ad-hoc TCC 记录（bundle-scoped，当前用户）：
  `tccutil reset AppleEvents local.personal.SwitchPilot` / `tccutil reset Accessibility local.personal.SwitchPilot` → `Successfully reset ...`。
- 清理后诊断（LaunchServices 启动）：`automationRaw=需要用户授权 (-1744)`、`automationResolved=需要用户授权 (-1744)`、`systemEventsRunning=true`、`accessibilityTrusted=false`。这是重置后的预期状态；待用户对稳定签名版本重新授权并验证"重新检查"。
- 版本 0.3.3；verify-app 11/11（签名步骤允许本地身份或 ad-hoc）、自检 12/12。

## v0.3.4：设置页撤销授权 IA + 稳定签名复核（2026-10-18）

- 设置页权限区：成功态移除「申请全部权限」，显示「✓ 全部权限已授权」+「重新检查」；撤销说明收进默认收起的「如何撤销授权…」，展开后才显示系统设置深链与二级「终端命令（高级）」（复制、不执行）。
- 窗口自适应：`SettingsWindowController` 订阅 `objectWillChange` 调整内容尺寸；离屏/真机窗口实测展开前后高度 544 → 711，未裁切。
- 稳定签名复核：用 `SwitchPilot Local Signing` 重建 v0.3.4、`install-app` 覆盖安装并重启后，`--diagnose-permissions` 输出 `automationRaw=已授权`、`automationResolved=已授权`、`accessibilityTrusted=true`，证明 TCC 授权跨重签/重装保持。
- 预览：`--dump-settings` + `SWITCHPILOT_PREVIEW_AUTHORIZED=1` / `SWITCHPILOT_EXPAND_REVOKE=1` 渲染折叠/展开，浅/深外观检查通过。
- 评审：`evidence/reviews/revoke-disclosure-ui.md`（推荐 inline disclosure、一级「如何撤销授权…」）、`revoke-disclosure-ux.md`（推荐「管理权限…」，强调 tccutil 只复制不执行、三态 CTA）。
- 版本 0.3.4；verify-app 11/11、自检 12/12。

## v0.3.5：应用内高级撤销实现（2026-10-18）

- 设置页「如何撤销授权…」展开 →「终端命令（高级）」下新增「在应用内重置权限…」；点击先弹 `NSAlert`（取消默认、重置按钮 destructive），确认后后台执行 `/usr/bin/tccutil reset AppleEvents|Accessibility local.personal.SwitchPilot`。仅本应用两项、无 sudo、无 reset All、非自动；完成后刷新权限状态并提示重新授权，若状态未变提示重启。
- 定位：默认路径仍是系统设置手动撤销；应用内重置是高级/unsupported 选项（Apple 无正式 revoke API），不是推荐主路径。
- 验证：verify 11/11、自检 12/12；用不存在 bundle id 试跑 tccutil 返回 `No such bundle identifier (-10814)`，未触碰真实授权。真实重置需用户在确认框触发，列为 M8 手动项（自动化不执行破坏性操作）。
- 版本 0.3.5。

## v0.3.6：M1/M3/M8 现场验收前置（2026-10-18）

- 构建/版本 0.3.6；本地身份 `SwitchPilot Local Signing`，designated requirement `identifier + certificate leaf = H"02f684b1…"`；可执行 SHA-256 `4b9e34563dfec54f8d245e06da3751776694e9f80059d345c54f34be09bbdf71`。
- 只读探针（`scripts/onsite-probe /tmp/onsite-baseline.log`）：`automationRaw/Resolved=已授权`、`accessibilityTrusted=true`、`systemEventsRunning=true`、`loginItemState=已开启`；BTM `enabled, allowed, notified`；应用图标 32 个表示（16–2048）、菜单栏 S monogram 18×18 template；`pmset` 无遗留断言；`hasSeenWelcome=true`。
- Screen Recording 在本机不可用（`screencapture` 失败），菜单栏/Finder/TCC 提示的图标显示仍需用户目视；M1 深色切换、M3 真实锁屏、M8 注销/登录启动均未执行，按边界不记为通过。
- 现场前置/步骤/记录模板：`evidence/onsite/M1-M3-M8-2026-10-18.md`。自动化 verify-app 11/11、自检 12/12。

## v0.3.7：M1/M8 现场反馈与 M3 交互修复（2026-10-18）

- 用户 12:49 现场反馈：**M1 深色模式验证通过**；**M8 简单测试没问题**（范围未逐项列明，注销/重启登录项与图标目视仍待明确）；**M3 点击「锁定屏幕」后出现二次确认，认为按钮语义已足够、不应再确认**。
- 修复：移除 `PanelModel.presentLockFlow` 中锁屏动作的 `NSAlert` 二次确认（权限门控仍保留；缺权限时仍显示授权引导）；屏保确认保持不变。
- v0.3.7 构建：可执行 SHA-256 `6b5dadf0693f235c098ccf4062c7406d4ae326c947d01c3bd714b42074abee6a`；签名身份继续为本地自签名；`--diagnose-runtime` 复核 Automation/Accessibility 均仍已授权、登录项已开启。
- 版本 0.3.7；verify-app 11/11、自检 12/12；锁屏真实执行需用户复测（M3-1），不代跑、不记通过。

## v0.3.8：交互确认策略与屏保确认移除（2026-10-18）

- 用户确认产品原则：**如果已经明确告知、且是常用操作，就不应再做二次确认**。据此 v0.3.8 将「启动屏保」改为点击即执行（v0.3.7 已移除锁屏确认）；保持亮屏本来就无确认；权限门控不变。
- 仅不可逆/高风险动作保留确认：应用内重置权限仍为警告 + destructive 确认；TCC 授权由系统弹窗负责。
- v0.3.8 构建：可执行 SHA-256 `e9e253545f7d2c649c140da4ed48b72329c59fc167d30be162c2ffb0d363cf76`；版本 0.3.8；签名/权限/登录项状态保持。verify-app 11/11、自检 12/12。
- M2 屏保真实执行、M3 移除确认后的真实锁定仍需用户现场验证，未记为通过；M1 已由用户确认通过，M8 仅“简单测试”通过（登录真实启动/图标目视待明确）。

## v0.3.8 收尾测试计划（2026-10-18）

- 用户补充确认：M8 的注销/重启测试操作较重，**留作长期待办**，等后续功能迭代接近收尾时与其余现场测试一起验证。
- 因此 M8-3（真实登录启动）继续保持未执行，不记通过；M8-4 图标目视在收尾测试中复看；M2/M3 的真实动作、M4 睡眠/唤醒、M5 VoiceOver/小屏、M7 首次引导复现、应用内重置真实执行一并列入收尾 backlog。
- backlog 已写入 `docs/TESTPLAN.md` §3.1 与 `evidence/onsite/M1-M3-M8-2026-10-18.md` §6；版本保持 0.3.8，无代码变更。

## v0.3.9：UI/UX 复评后的细节收敛（2026-10-18）

- 复评：UI（P1×2）、UX（P1×4/P2×7）无 P0；修复响应见 `evidence/reviews/fix-response-2026-10-18.md`。
- 主要变更：guide/磁贴文案与"点击即执行"策略一致；外观与快速动作的两个权限 callout 合并为单一「需要授权」卡并动态列出缺失项；设置成功态去重复总结、版本只留关于区、诊断默认折叠、disclosure 去省略号、应用内重置独立"不可逆操作"块；登录项状态消息在刷新后生成；Info.plist 增加 `LSMultipleInstancesProhibited` 与 `switchpilot://diagnose` URL scheme。
- 自动化：verify-app 11/11（新增单实例 key/URL scheme/stale copy 检查）、`SwitchPilotChecks` 12/12。
- 尺寸实测：面板 380×637（无 guide）/380×710（guide）；设置窗口 523（折叠）/774（展开）pt。
- 单实例：普通第二次 `open` 保持 1 个实例；`open -n` 被 LaunchServices 阻止（仅开发/诊断路径），运行中诊断走 URL；`scripts/onsite-probe` 已验证可完成且不触发 TCC/屏幕操作。
- 未执行：M2/M3 真实动作、M8-3 注销/重启登录、M8-4 图标目视、M5 VoiceOver/小屏；不记为通过。版本 0.3.9；最终构建 SHA-256 `a252db3f9381faa2da3e2705b0fdb458bf393f00dda2c92052125cd89755b4b2`。

## v0.3.9 现场补充：M2/M3 用户自测通过（2026-10-18）

- 用户确认 M2（启动屏保，点击即执行）与 M3（锁定屏幕，点击即执行、无二次确认）均自测通过。此前 M1 已通过；M8 为“简单测试”通过，M8-3 注销/重启登录启动仍为长期待办，M8-4 图标目视收尾复看。
- 本轮未重新运行 TCC/屏幕操作；记录仅反映用户现场自测结论。

## v0.4.0：快捷键、关闭显示器、音量原型（2026-10-18）

- 用户选择 A/B/C/D 全部推进；实现 A 全局快捷键（Carbon，⌃⌥⌘K 保活 / ⌃⌥⌘S 屏保，默认关闭、可停用、冲突报错）、B 关闭显示器（公开 pmset displaysleepnow，快速动作）、C 输出音量原型（CoreAudio 能力探测；unsupported 不显示假控件）；D 收尾测试继续 backlog。
- 自动化：verify-app 11/11；`SwitchPilotChecks` 14/14（新增音频只读能力、pmset 可用性）。
- 面板逻辑尺寸：380×729（无 guide）/380×802（guide）。
- 前置探测：快捷键临时启用后 `hotKeysEnabled=true`、`hotKeysRegistered=true`、无错误（随后恢复默认关闭）；`pmset` 可用但未执行；当前默认输出不支持 mute/volume，内置/USB 设备支持（未改音量/设备）。
- 可执行 SHA-256：`b7f87a136d44561078f815e9a503acd471dd805baf5cb58815b52f60843f9186`；版本 0.4.0；权限/登录项状态未改。
- 未执行：M9 真实按键/后台触发、M10 真实休眠/唤醒、M11 支持设备上的真实音量写入；均不记通过。现场前置/步骤见 `evidence/onsite/expansion-v040-2026-10-18.md`。

## v0.4.1：音量卡静音态修复与现场反馈（2026-10-18）

- 用户反馈：关闭显示器自测通过（鼠标唤醒）；快捷键测试较复杂，按用户要求并入长期统一测试；音量卡截图显示静音态图标/滑块歧义。
- 修复：v0.4.1 将静音按钮改为动作文案（取消静音/静音 + 对应图标），静音时禁用滑块并显示“已静音”，标题图标反映当前状态；运行诊断新增 `audioVolume/audioMuted`。
- 版本 0.4.1，可执行 SHA-256 `10d286cfbb881a97e262b0726cb75c8b9a3f451242f1014e2f2950294d4eac60`；verify 11/11、自检 14/14；M10 用户自测通过，M11 待复验，M9 长期统一测试。

## v0.5.0：麦克风静音、屏幕清洁，移除输出音量（2026-10-18）

- 按核心原则（见 `docs/CORE.md`）**移除输出音量**：系统菜单栏/控制中心已有等价控制，且设备能力复杂；删除面板音量卡与 `AudioOutput`，M11 不再验收。
- 新增 **麦克风静音**：`Microphone.swift` CoreAudio 读取默认输入设备、mute 能力/当前值；面板显示状态与动作按钮，不支持时明确说明；无新增 TCC。诊断读回默认输入设备 `supportsMute=true`、`muted=true`（设备名不入库）。
- 新增 **屏幕清洁**：`ScreenCleaningManager` 全屏黑色遮罩覆盖所有屏幕；Accessibility 下用 session event tap 拦截键盘，保留鼠标；鼠标点击「退出清洁模式」退出；60 秒自动退出；PowerAssertion 防睡眠；无权限/事件 tap 失败不进入假清洁。**自动化未启动该模式**。
- 自动化：verify-app 11/11；`SwitchPilotChecks` 14/14（麦克风只读、pmset）；面板 380×788/861。
- 可执行 SHA-256 `e740d209066dbe060cff812010156a0c0141e71209c96a56942d30fd6b5ec39d`，版本 0.5.0。
- 未执行：M12 真实麦克风写入/不支持设备、M13 屏幕清洁真实键鼠/鼠标退出/多屏/自动退出；未记通过，现场步骤见 `evidence/onsite/v050-mic-screen-2026-10-18.md`。
