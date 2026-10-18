# 验证与已知缺口

## 已完成的检查

- 工具包发布 SHA-256 匹配，REA provider scoped doctor healthy；复导入同函数的地址/汇编/伪代码相同。
- Main 6/6 + 3/3、XPC 4/4 批反编译有结果；检查失败计数，不以 RPC 无错误替代功能成功。
- Swift 自检先以 stub 得到 0/4，再实现到 4/4；真实 OS assertion 类型、级别、释放与 deinit 都检查。
- `scripts/build-pilot` 构建成功；独立 ad-hoc app codesign --verify --strict 通过；两份 plist 通过 plutil -lint。
- `python3 scripts/verify-pilot.py`：5/5 真实进程用例通过。结束时 pmset 未发现本原型断言。
- Python py_compile、shell sh -n、git diff --check 通过；没有独立 lint 配置，不声称跑过不存在的静态分析器。
- 原应用与研究副本的 293 个已记录文件 SHA-256、12 个链接目标仍匹配基线；两份 deep/strict 签名仍通过。四个所读原版偏好前后相同。

## 明确保留的缺口

- 完整 Xcode SDK 使用仍需要许可；没有代为接受。XCTest 模块在当前 CLT 不可用。
- Native SwiftPM 回退提示 deprecated；未来 SDK 需切换受支持构建流程。不是零警告构建。
- 深色模式只有未运行目标 -600 / 需授权 -1744 的真实门控结果；未验证授权后的读写、恢复、拒绝与撤销。
- 研究代号和 app bundle 不等于产品 UI；没有菜单栏设计、VoiceOver/键盘/对比度、Liquid Glass、分发签名、公证、Sandbox 适配测试。
- 未对原版运行调试、杀进程或做行为等价对照。原始源码未恢复；Swift 伪代码存在参数/receiver 恢复误差。
- 未做跨睡眠、合盖、设备切换、重启、长时间稳定性测试。合盖保活和 Night Shift 不在候选原型能力内。
- Token 输入/输出/缓存及人工工时没有可信计量来源，均未知。会话记录显示两次 `usage_limit_exceeded` 中断（10:02、10:38 CST，第二次在最终提交前）；用户已授权现有重置卡用完为止，但本地无卡消耗记录，也未新购额度。

## 收口核验（DSH 接手）

- 两份 HTML 报告（结果与执行计划）在 390/768/1440 视图宽度无横向溢出；无 console/page 错误；内部链接与锚点完整；无外部资源依赖；复制、导出、tab 与折叠控件可用。
- 原应用仍为 1.35.4 (440)，主程序 SHA-256 与基线一致，`codesign --verify --strict` 通过；无本原型进程或断言残留，System Events 未被修改。
- `scripts/rea doctor --provider ghidra --format json` 复核 `healthy=true`；Ghidra/Java 版本与证据一致。
- 上述检查只验证文档与工作区可安全接手，不新增任何功能行为或动态验收通过项。

## 个人自用 v0.1 应用验收（2026-10-18）

自动化（`python3 scripts/verify-app.py`，8/8 通过；详见 `evidence/app-runtime.md`）：

- 构建 + bundle/plist + ad-hoc Hardened Runtime 签名 + 退出 0 均通过；应用可执行文件 SHA-256 `238524889cbe…`、CDHash `19e82d8c…`。
- `SwitchPilotChecks` 9/9 通过：时长校验、权限状态码映射、三轮真实 IOPM 断言生命周期、deinit 释放、定时会话自动释放、深色模式全局外观只读、屏保引擎解析、无权限时锁屏拒绝执行。
- 启动冒烟：菜单栏应用进程存活 >2 秒，SIGTERM 退出后无本应用电源断言、无残留进程。
- 原应用 1.35.4 (440) 主程序 hash 与签名未变；未启动或修改原应用。
- 本轮自动化未请求 TCC、未发送锁屏按键、未启动屏保、未切换深色模式、未修改系统设置。

仍未验证（需用户在场，`docs/TESTPLAN.md` M1–M6）：

- 深色模式真实授权、切换、读回、拒绝/撤销；
- 屏保真实启动与退出；
- 锁屏授权、锁定/解锁、读回；
- 睡眠/唤醒、合盖、长时间稳定性（强退清理仅冒烟到 SIGTERM）；
- 菜单栏/面板视觉、键盘、VoiceOver、深浅外观；多实例与卸载残留。

## v0.2 正式命名与 UI/UX 重设计验收（2026-10-18）

- 正式名确定：SwitchPilot（候选冲突比较见 `artifacts/20261018-1138-oneswitch-naming-ui-redesign.html`）；bundle id 不变。
- 新面板：状态胶囊、首次引导（UserDefaults 持久化）、保活进度、权限行内化、动作磁贴、权限摘要 footer。
- 自动化：`SwitchPilotChecks` 10/10（新增进度模型检查）；`scripts/verify-app.py` 8/8（v0.2.0 构建、plist、签名、自检、启动冒烟、无新增残留进程、原应用不变、脚本语法）。
- 设计/命名报告 HTML 在 390/768/1440 无横向溢出、无 console 错误、无外部资源加载、交互预览可用。
- 用户 2026-10-18 口头确认 v0.1 初步验收可行；未提供逐项记录，因此 M1–M3 仍不记为通过。
- 仍未验证：深色模式真实授权/切换/拒绝/撤销、屏保真实启动、锁屏授权与锁定/解锁、睡眠/唤醒、VoiceOver/键盘手测、M7 首次引导与面板视觉手测。

## v0.3 反馈修复与独立评审（2026-10-18）

- 自动化：`scripts/verify-app.py` **11/11**（新增应用图标、对比度 token、面板尺寸、语义色静态检查）；`SwitchPilotChecks` **12/12**。
- 对比度：`secondaryInk` 浅色 panel/card/tile 5.74/5.65/5.15:1、深色 7.47/6.69/6.04:1；warning/success/error ink 浅色最差 5.50/5.99/6.03:1（全部 ≥4.5）。
- 面板逻辑尺寸：无 guide 380×672、有 guide 380×710；AppDelegate 再按屏幕 visibleFrame clamp。
- 首启权限流程：后台请求 Automation（系统弹窗）+ Accessibility 系统提示；拒绝后保活/屏保仍可用；设置页可再申请；引导可见时隐藏重复权限 callout。
- 登录项：SMAppService register/unregister 本机实测成功并回滚（`evidence/raw/app/login-item-test.log`）；登录后真实启动、requiresApproval、重建失效待现场。
- 图标：应用图标链（Info.plist → build 拷贝 → bundle → NSWorkspace 解析 32 个表示）通过；菜单栏/系统 UI 显示需现场。
- 独立评审：`evidence/reviews/ui-review.md`（P0×1/P1×6）、`ux-review.md`（P0×4/P1×8）、`qa-baseline.md`（v0.3 验收矩阵 31 项）。v0.3 已修主要 P0/P1；复评与现场仍 pending。
- 批量撤回研究：tccutil bundle-scoped 可行但不内置（无恢复 API、reset All 危险）；设置页给系统设置深链，README 给手动命令。
- 仍未验证：TCC 允许/拒绝/撤销、锁屏/屏保真实执行、睡眠/唤醒、登录后启动、Finder/TCC/菜单栏图标显示、VoiceOver/键盘、小屏/放大字体真机布局。

## v0.3.3 权限身份修复（2026-10-18）

- 根因：ad-hoc 重建使 TCC 记录与当前代码要求不匹配（tccd: Failed to match existing code requirement）；Automation 的 -600 被误显示为待授权（System Events 未运行）。
- 修复：稳定自签名身份（SwitchPilot Local Signing）+ designated requirement `identifier + certificate leaf`；-600 自动启动 System Events 后重探测；设置页诊断行/`--diagnose-permissions`。
- 已清理旧 bundle-scoped TCC 记录；清理后诊断 automation -1744、accessibility false，符合重置预期。
- 待用户：用当前稳定签名版本重新授予 Automation + Accessibility，再验证设置页/「重新检查」；之后重建应保持授权（需下一次重建验证）。

## v0.3.4 设置页撤销 IA（2026-10-18）

- 权限成功态：移除「申请全部权限」；「如何撤销授权…」默认折叠，展开含系统设置深链 + 高级 tccutil 命令（仅复制）；三态 CTA/诊断仅在未就绪时出现。
- 窗口高度随 disclosure 自动调整（544 → 711，实测）；键盘/VoiceOver 说明写入 DESIGN/TECH。
- 稳定签名身份复核：重建 + 重装 + 重启后 Automation/辅助功能仍为已授权（diagnostic 输出 allowed/true）。
- 自动化 verify 11/11、自检 12/12。

## v0.3.5 应用内高级撤销（2026-10-18）

- 应用内重置入口位于高级命令区，带确认框；范围固定本应用 Automation + Accessibility，无 sudo/reset All，后台执行，完成后刷新并提示重新授权。
- 自动化只验证构建/命令可用性与 UI；真实重置未在用户授权上执行，列为 M8 手动破坏性项。
- verify 11/11、自检 12/12；版本 0.3.5。

## v0.3.6 M1/M3/M8 前置（2026-10-18）

- 只读探针确认当前 TCC：Automation 已授权、Accessibility 已授权、System Events 运行；登录项 `已开启`（BTM enabled/allowed/notified）；图标资源 32 个表示，菜单栏 S monogram template；无遗留电源断言。
- 未执行：M1 深色切换、M3 真实锁屏、M8 注销/登录启动与图标目视（需用户在场；Screen Recording 不可用，无法代理截图）。**不记为通过。**
- 步骤/记录模板：`evidence/onsite/M1-M3-M8-2026-10-18.md`；只读探针 `scripts/onsite-probe`。

## v0.3.7 M3 锁屏交互修复（2026-10-18）

- 用户现场：M1 通过、M8 简单测试通过；M3 点击锁定出现二次确认，反馈不应有。
- 修复：v0.3.7 移除锁屏二次确认，保留权限门控；屏保确认不变；文档/README/TESTPLAN 同步。
- 自动化 verify 11/11、自检 12/12；真实锁屏待用户复测，未记为通过。

## v0.3.8 交互确认策略（2026-10-18）

- 用户确认：明确告知 + 常用操作不做二次确认。屏保确认已移除（锁屏 v0.3.7 已移除）；权限门控和不可逆高级重置确认保留。
- 文档/测试计划同步；真实屏保/锁屏操作待用户现场执行，仍未记为通过。
- verify 11/11、自检 12/12；版本 0.3.8。

## v0.3.8 收尾测试 backlog（2026-10-18）

- 用户指示：M8-3 注销/重启真实登录启动操作较重，留到功能收尾时与其余现场测试一起验证。
- 该项保持未执行；M2/M3 真实动作、M4 睡眠/唤醒、M5 VoiceOver/小屏、M7 首次引导、应用内重置真实执行等一并列入 `docs/TESTPLAN.md` §3.1，均不记通过。
- 版本 0.3.8，无代码变更；自动化 11/11、12/12。

## v0.3.9 UI/UX 复评修复（2026-10-18）

- UI/UX 独立复评无 P0；P1 文案/权限卡/不可逆重置/单实例均已处理，详见 `evidence/reviews/fix-response-2026-10-18.md`。
- 自动检查新增 Info.plist 单实例 key、`switchpilot://diagnose` URL scheme、PanelView stale confirmation copy；verify 11/11、自检 12/12。
- 普通重复启动实测 1 实例；URL 诊断与 onsite-probe 正常；面板 637/710pt，设置窗口 523/774pt。
- 未记通过：M2/M3 真实动作、M8-3 登录真实启动、M8-4 图标目视、M5 无障碍/小屏；按收尾 backlog 处理。

## v0.3.9 现场补充：M2/M3 自测通过（2026-10-18）

- 用户自测通过启动屏保与锁定屏幕（均为点击即执行，无二次确认）；M1 此前已通过。
- 未执行项保持：M8-3 注销/重启登录启动（长期待办）、M8-4 图标目视、M5 无障碍/小屏等；不记通过。

## v0.4.0 扩展前置（2026-10-18）

- 已实现快捷键、关闭显示器、音量原型；verify 11/11、自检 14/14；面板 729/802pt。
- 快捷键注册已读回 `hotKeysRegistered=true`（随后恢复默认关闭）；pmset 可用未执行；当前默认输出 unsupported、支持设备能力已只读枚举。
- 真实按键/休眠/音量写入需现场，列入 M9–M11，未记通过；M8-3/M8-4/M5 继续收尾 backlog。

## v0.4.1 现场反馈（2026-10-18）

- M10 关闭显示器：用户自测通过（鼠标唤醒）。
- M9 快捷键：用户要求并入长期统一测试，不阻塞当前迭代。
- M11 音量卡：修复静音态显示歧义（动作按钮、静音禁用滑块、"已静音"），待复验真实写入；版本 0.4.1，verify 11/11、自检 14/14。

## v0.5.0 麦克风静音 / 屏幕清洁前置（2026-10-18）

- 输出音量已按核心原则移出；新增麦克风静音与屏幕清洁实现。
- verify 11/11、自检 14/14；面板 788/861pt；诊断读回麦克风支持 mute、当前 muted；屏幕清洁未启动。
- M12/M13 真实动作需用户现场；M9 快捷键长期统一测试；M10 已用户自测通过；未验项不记通过。

## v0.5.1 麦克风/屏幕清洁 UI 修复（2026-10-18）

- M12 用户自测通过；取消静音按钮改为普通 bordered，仅保留红色状态文字。
- M13 退出按钮改为自定义绘制控件 + key window 遮罩，离屏预览确认可见；普通模式无倒计时/不自动退出，测试环境变量可启用；真实键鼠行为待复测。
- verify 11/11、自检 14/14；版本 0.5.1。

## v0.5.1 现场补充（2026-10-18）

- M12 麦克风静音用户自测通过。
- M13 屏幕清洁步骤 1–3 用户自测通过；无权限降级（M13-4）未执行，仍待验。

## v0.5.2 UI/UX 与回归门禁（2026-10-18）

- UI/UX 走查修复：麦克风静音状态项/右键、面板压缩为 380×730/803、清洁无权限行内入口、内部 5 分钟隐藏失效保护、a11y 文案修正。
- `scripts/qa-regression.py` 13 项政策回归已并入 `scripts/verify-app.py` 第 12 步；verify 12/12、checks 14/14。
- 未执行：静音状态项目视、M13-4、M9、TCC/登录/图标/睡眠唤醒；不写通过。

## v0.5.3 状态栏图标回退（2026-10-18）

- 按用户反馈撤销麦克风静音状态栏图标变体；顶栏始终显示 SP 的 S。
- 保留 tooltip/右键菜单状态操作；用户接受内部 5 分钟隐藏失效保护。
- verify 12/12、checks 14/14、policy 13/13；未执行状态栏 tooltip/右键目视与 M13-4。
