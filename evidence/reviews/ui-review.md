# SwitchPilot UI 评审（v0.3 WIP）：视觉 / 对比度 / 图标 / macOS 27

- 评审者：独立 UI 评审人（非实现者）；只读源码/文档，仅写本文件；未改源码、文档、Git，未触发 TCC、屏幕状态或登录项。
- 时间：2026-10-18 11:51–12:13 CST。工作区被并发实现持续修改；本文件在 12:12 复核，基线为 12:02 构建快照，行号对应此快照。
- 基线：HEAD `a6ddaa5`（v0.2）；被评审对象为未提交 v0.3 WIP：PanelView `a29a4b5…`、Theme `b2e6f3b…`、StatusIcon `f21c11f…`、AppDelegate `fcea8cf…`、SettingsView `ca3642b…`、main `6fa1000…`、AppIcon.icns `97b23ab…`、Info.plist `c7b4b86…`。
- 方法：离屏渲染 `--dump-panel` / `--dump-settings`（2x，浅/深）；v0.2 用户截图逐像素取样；Python 按 WCAG 2.x 相对亮度计算；`NSWorkspace.icon(forFile:)` 读取 bundle 图标；`codesign --verify`；AppKit 单独渲染菜单栏图标与 `switch.2` 对比。
- 边界：离屏渲染不含 NSPopover 真机 vibrancy/定位；TCC 弹窗图标与真机面板高度需用户在场按 `docs/TESTPLAN.md` M5 复测。权限流程语义另见并行 `evidence/reviews/ux-review.md`。

## 结论摘要

- 用户 5 项抱怨中，v0.3 WIP 已实质修复 4 项：橙色文字改 `warningInk` 图标+primary 文本、行内文字按钮全部改 `bordered`/带图标按钮、应用图标补齐（icns + CFBundleIconFile，系统已能解析）、权限 CTA 按缺失权限分支（12:02 快照，PanelView L223-230/L277-300）。
- 仍未闭环：浅色次级说明 2.97–3.65:1（WCAG AA 需 4.5）；guide 里 `.green` 文本 1.90:1；自绘菜单栏图标与 `switch.2` 同构；app icon 不符合 macOS 图标网格且 16px 不可辨；首屏引导面板 840pt 且无滚动；设置窗口视觉/交互未对齐面板。
- 视觉方向正确（系统材质、语义色、SF Symbols、卡片层级、主操作优先），差距集中在对比度 token、首屏高度与图标质量三件事。
- 分级：**P0 1 项，P1 6 项，P2 7 项**。建议修复顺序：P0-1 → P1-2/P1-1（图标）→ P1-3（高度）→ 其余。
- 结论：可以继续 M5 前修复，但暂不应把"UI 视觉/可访问性"记为通过（TESTPLAN M5/M7 仍 pending）。

## 证据与现状

- 图标链已通：Info.plist 第 6 行 `CFBundleIconFile=AppIcon`；`scripts/build-app` 第 13 行拷贝 icns；bundle 内 `Contents/Resources/AppIcon.icns`（1,175,735B）；`codesign --verify --strict` 通过；`NSWorkspace.icon(forFile:)` 解析出 16–1024px 多尺寸 → 截图 2 的"通用图标"属 v0.2 旧构建；Finder/系统设置/TCC 提示显示需重注册后人工确认。
- 面板实测（12:02 构建，离屏 2x）：guide 隐藏 380×649pt；guide 展开 380×840pt。AppDelegate 第 34 行 `contentSize=380×620`，第 48–57 行按 `preferredContentSize` 调整且上限 900（未按屏幕可见高度约束）。
- v0.2 截图复测：橙色文字峰值 `#F0872B` on `#939395` = **1.20:1**（token `#FF9500` = **1.39:1**），次级灰字约 **2.89:1**；用户"橙色对比低"抱怨成立。
- 浅色渲染底色：panel `#FCFCFC`、card `#F1F1F1`、tile `#E5E5E5`、callout `#F2E8E1`、guide `#E6EEFC`；深色：panel `#181818`、card `#222222`、callout `#332A22`。
- 菜单栏：StatusIcon 为代码绘制的"两枚开关轨道+旋钮"；与 SF Symbol `switch.2` 对比渲染（18pt、light/dark）几乎同构，见 P1-1。
- 设置窗口：460pt 宽；12:01 版已把 `tccutil` 撤销改为"手动到系统设置撤销"（源码复核，本评审未重渲染该版）。

## 发现清单

### P0（1 项）

**P0-1 浅色外观次级说明 2.97–3.65:1 < WCAG AA 4.5:1，用户"对比看不清"未完全闭环。**
- 证据：Theme.swift 只有 warning/success/errorInk，未定义次级墨色；离屏实测 `.secondary` 核心 `#848484`：panel `#FCFCFC` = **3.65**、card `#F1F1F1` = **3.31**、tile `#E5E5E5` = **2.97**；字号为 11pt caption2。涉及 PanelView L49-50/171-182/206-217/272-276/329/411-415、SettingsView L31-32/76-77/98-99/109-110/138/152。guide 的 `.green` 文本（PanelView L83）`#34C759` on `#E6EEFC` = **1.90:1**。
- 违反：WCAG 2.2 1.4.3 普通文本 4.5:1；HIG Color / Accessibility 要求文字在深浅外观下可读。
- 修复：Theme.swift 增 `secondaryInk = adaptive(light:(0.37,0.37,0.37), dark:(0.66,0.66,0.66))`，实测 panel/card/tile = 5.07–6.22（light）、5.79–7.47（dark）；权限/边界等关键说明改用 `.primary` + `.footnote`(13pt)；guide 状态改 `successInk` 图标 + primary 文本（或 tinted badge），禁用 `.green` 作文本。
- 验收：对比度脚本在 light/dark 的 panel/card/tile 三底色断言 ≥4.5:1；PanelView/SettingsView 中 `.green`/`.orange` 作前景文本出现次数 = 0。

### P1（6 项）

**P1-1 菜单栏图标品牌区分度不足，用户"switch 图标俗气"未真正解决。**
- 证据：StatusIcon.swift L11–L35 仍是两枚圆角轨道+旋钮（宽 0.68×18≈12.2pt、胶囊高≈4.0pt、描边≈1.44pt、旋钮≈2.6pt），与 `switch.2` 同母题；18pt 对比渲染显示两者轮廓几乎一致，仅填充方式不同；坐标含小数，1x 会糊。HIG 菜单栏图标要求 template、简洁剪影、可识别，当前无品牌差异。
- 修复：方案 A（推荐）单开关轨道 + 航向箭头/缺口（"pilot"），与 app icon 同基因；方案 B 保留双开关但只保留一个旋钮并加方向性元素；在 36×36@2x 画布上按 2px 对齐绘制后降采样，内容 16×16、留 1pt 光学边距。
- 验收：浅/深/选中三种菜单栏状态下与相邻系统图标视觉重量一致；1x 截图无发虚；与 `switch.2` 并排可区分。

**P1-2 应用图标不符合 macOS 图标网格，16/32px 不可辨。**
- 证据：`AppIcon.icns` 内容铺满 1024 画布（alpha bbox 0..1024，四边中点不透明）；源 `Resources/AppIcon.html` 为 1024 全幅、圆角 232px。macOS 图标模板约 824×824 内容 + 四周 ~100px 透明边距；16px 实测只剩两团奶白胶囊（描边环糊成一团）。
- 修复：1024 画布缩至 ~824×824 居中（continuous squircle 半径≈185）；重导出 16/32/64/128/256/512/1024 + @2x；为 16/32 单独简化为"实心单开关"小尺寸稿；保留 icns + CFBundleIconFile + build-app 拷贝链。
- 验收：Finder Get Info、系统设置隐私列表、登录项、TCC 提示显示新图标且与系统 App 视觉尺寸一致；16/32px 缩略图仍可辨。

**P1-3 首屏默认显示引导时面板 840pt，接近/超出小屏可用高度且无滚动。**
- 证据：离屏实测 guide 展开 380×840pt、guide 隐藏 649pt；AppDelegate L48–57 `min(size.height,900)` 未按 `NSScreen.visibleFrame` 约束，面板无 ScrollView；footer"使用说明"重开 guide（PanelView L419）会把面板从 649 拉到 840。
- 风险：1440×900/1280×800 等小工作区下底部"设置/退出"可能出屏；NSPopover 真机布局未复测。
- 修复：内容套 `ScrollView` + `.frame(maxHeight: max(480, visibleFrame.height - 120))`；guide 压缩为 2 行/独立引导窗（推荐 2 行要点+一个主按钮）；`resizePopover` 用屏幕可见高度 clamp；新增自动断言：dump 高度 guide ≤720、no-guide ≤660。

**P1-4 首屏信息层级冗余，macOS 27"少即是多"未落实。**
- 证据：同一屏出现 guide 三按钮（L98-116）、appearance callout（L223-230）、quick actions callout（L277-300）、深色模式行权限文案（L203-217）、status 行（L277）、footer 权限摘要（L411-415）；callout 与 guide 的权限动作重复。
- 修复：权限信息收敛为 1 处（首屏 guide 或顶部单一 banner）；外观/动作区仅在相关控件旁保留一行状态+一个主按钮；footer 改为单句摘要；目标首屏 = 1 个主操作 + 2 个次要动作 + 1 个权限入口。

**P1-5 动作磁贴仍 `.plain`，无 hover/pressed/focus 反馈，"看起来是按键"只部分解决。**
- 证据：PanelView L343 `.buttonStyle(.plain)` + 6% fill + 10% border；tile/card 边界对比 **1.12:1**；全仓无 `onHover`/`focusable`/`focusEffect`。footer/权限区按钮已是系统 bordered，已可识别。
- 修复：磁贴改标准 `.bordered`，或自定义 hover(0.06→0.12)/pressed(0.16)/focus ring（`.focusable(true)` + 可见描边）；加 `contentShape(Rectangle())`；保留圆角卡片视觉但提高边界对比（参考 WCAG 1.4.11 非文本 3:1）。
- 验收：悬停/按压/Tab 焦点三态截图可见差异；磁贴边界在 light/dark 下可辨。

**P1-6 设置窗口未沿用面板的视觉/交互 token。**
- 证据：SettingsView 460pt 宽、全篇 11pt caption/caption2；顶部与 footer 各有一个"重新检查"按钮（L27、L58）；登录项 `Toggle` 开关紧跟标签未右对齐（L94）；标题同时有窗口标题"SwitchPilot 设置"与内容"设置"（L8）。
- 修复：去除重复 CTA（保留权限区一个）；`HStack { 标签; Spacer(); Toggle().labelsHidden() }` 右对齐；正文升到 12–13pt；节标题/按钮/圆角复用 PanelView token。
- 验收：设置窗口与面板同 token 表；Tab 顺序、按钮层级、浅深外观一致。

### P2（7 项）

- **P2-1 字体与控件尺寸**：caption2(11pt) 承载权限/边界信息；分段控件高 20pt、CTA 18pt（`controlSize(.small)`）。建议语义字号（`.footnote`/`.caption`/`.body`）+ 主 CTA `controlSize(.regular)`；`Toggle` 标签与开关整行可点（当前 `labelsHidden` + 兄弟 Text，点标签无效）。
- **P2-2 文案与本地化**：中英混排"Automation/辅助功能"；"等价 Ctrl+Cmd+Q"应使用 ⌃⌘Q 符号；"首次操作时提示"可精简；状态词（待授权/未授权/需授权/被拒绝）统一为一张状态词表；"设置…"省略号正确保留。
- **P2-3 材质与圆角 token 收敛**：PanelView L26-31 在 popover 材质上再叠 `.regularMaterial` + `windowBackgroundColor.opacity(0.82)`，双层半透明与 macOS 27"收敛 Liquid Glass"方向相反；圆角混用 12/10/9。建议单一 surface（opaque windowBackground 或只用系统 popover 材质）+ 圆角 token 10/12 两档。
- **P2-4 键盘/焦点/VoiceOver**：无 Esc 关闭、无取消快捷键、装饰性 `Image(systemName:)` 未 `accessibilityHidden`；M5 未验收。建议补 `.keyboardShortcut(.cancelAction)`、焦点环与 VoiceOver 标签/值检查。
- **P2-5 深浅/高对比/降低透明度未验收**：本评审仅离屏 light/dark 两版；"增加对比度""降低透明度"下 callout 边框/按钮可辨性未验证（TESTPLAN E1/E2）。
- **P2-6 文档与验收漂移**：README/PRD/DESIGN/TECH/TESTPLAN 仍写 v0.2；DESIGN §9 把"设置窗口、登录自启、正式图标/品牌稿"列为非目标，而 v0.3 WIP 已实现，需更新规格与验收矩阵（否则不能据此宣称通过）；`scripts/verify-app.py` 已加 icon 检查（好）。
- **P2-7 dev 辅助入口副作用**：main.swift L12-13 的 `SWITCHPILOT_HIDE_GUIDE` 调 `dismissGuide()`，会写 `UserDefaults("switchpilot.hasSeenWelcome")`（改变真实首启状态）；`--login-item-test` 会注册/注销登录项；`openSystemSettings` 仍用旧 pane id（`com.apple.preference.security?…`）需在 macOS 27 验证。建议预览路径只改内存态、测试入口移出发布二进制、深链加失败回退。

## 对比度测量表（当前 vs 建议 token）

| # | 元素 / 当前 | 当前对比度 | 建议 token | 建议对比度 | 判定 |
|---|---|---|---|---|---|
| 1 | 正文 primary `#262626` on card `#F1F1F1` | 13.40 | 保持 | — | PASS |
| 2 | 次级 `.secondary` `#848484` on panel `#FCFCFC` | **3.65** | `secondaryInk` `#5F5F5F` | 6.22 | FAIL→PASS |
| 3 | 次级 on card `#F1F1F1` | **3.31** | `#5F5F5F` | 5.65 | FAIL→PASS |
| 4 | 磁贴副标题 on tile `#E5E5E5` | **2.97** | `#5F5F5F` | 5.07 | FAIL→PASS |
| 5 | v0.2 橙色文字 `#F0872B`/`#FF9500` on `#939395`（用户截图） | **1.20 / 1.39** | v0.3 `warningInk` `#854D05` on callout `#F2E8E1` | 5.69 | 已修复方向 |
| 6 | guide `.green` `#34C759` on `#E6EEFC` | **1.90** | `successInk` `#0D6138` | 6.47 | FAIL→PASS |
| 7 | 深色次级 `#929292` on panel `#181818` | 5.71 | `secondaryInk` `#A8A8A8` | 7.47 | PASS（可提升） |
| 8 | 深色 warning `#FFC25C` on callout `#332A22` | 8.78 | 保持 | — | PASS |
| 9 | 分段选中白字 on 系统蓝 `#0A5EF9` | 5.27 | 系统控件保持 | — | PASS |
| 10 | 磁贴边界 `#E5E5E5` vs card `#F1F1F1`（非文本） | **1.12** | hover/focus + 边界增强（1.4.11 参考 ≥3:1） | 待实现 | FAIL（非文本） |

## 品牌图标建议

### 应用图标（AppIcon）
- 规格：1024×1024 母版，内容 ~824×824 居中（四周 ~100px 透明），continuous squircle 半径≈185；导出 16/32/64/128/256/512/1024 + @2x 的 .icns；`CFBundleIconFile=AppIcon` 已就位，build-app 拷贝与签名顺序正确。
- 小尺寸：16/32px 使用简化稿（实心单开关、加粗留白、去掉细描边环）；当前 16px 不可辨，需重绘而非等比缩小。
- 深色/着色：优先用 Icon Composer（若可获得完整 Xcode）生成 light/dark/tinted 变体；CLT 限制下可接受单一 icns，但需在深色系统背景检查边缘。
- 系统显示位点（需用户在场逐项验收）：Finder 列表/图标视图/Get Info、Spotlight（若移入 /Applications）、系统设置›隐私与安全性 各列表行、TCC 授权弹窗、登录项列表、通知（若未来使用）；Dock/Cmd-Tab 因 `LSUIElement=true` 不得出现。
- 注册链：每次 ad-hoc 重建 cdhash 变化，需重新构建→启动→确认系统缓存刷新；建议安装到 `~/Applications` 并 `lsregister -f` 后再做 TCC/图标目视验收。

### 菜单栏 template icon
- 约束：18×18pt 画布、内容 16×16 光学居中、1pt 以上透明边距；必须 `isTemplate=true`（黑+alpha，无颜色/阴影）；2x 像素对齐（36×36 画布设计），1x 不得糊；保留 `accessibilityDescription` 与 tooltip；DESIGN §9 规定不做状态变化定制，暂保持单状态。
- 方案 A（推荐）：单开关轨道 + 方向/航向元素（pilot 概念），与 app icon 同基因但剪影不同于 `switch.2`；方案 B：双开关保留但增加差异化细节（仅一个旋钮/加方向箭头）。
- 可读性验收：浅色菜单栏、深色菜单栏、被选中（高亮）三态；与相邻系统图标并排宽度差 ≤2pt；在 1x 外接屏截图中轮廓仍清楚；不得与"控制中心/电池/开关类"系统图标混淆。

## 验收清单（可自动 / 人工）

- [ ] **A1（自动）** `plutil -p` 含 `CFBundleIconFile=AppIcon`；`test -s Contents/Resources/AppIcon.icns`；`codesign --verify --strict`；`iconutil -c iconset` 含 16–1024 全套；16/32px 预览非空白（人工看图）。
- [ ] **A2（自动）** `--dump-panel` 无 guide ≤660pt、有 guide ≤720pt 或存在滚动；宽 =380pt；`--dump-panel` 不得因 HIDE_GUIDE 写 UserDefaults。
- [ ] **A3（自动）** 对比度脚本：`secondaryInk` 在 panel/card/tile × light/dark 全部 ≥4.5；`warningInk/successInk/errorInk` ≥4.5；白色 on 系统蓝分段保持 ≥4.5（或标注系统控件例外）。
- [ ] **A4（自动）** 静态扫描 PanelView/SettingsView：`.green`/`.orange` 作 `.foregroundStyle` 文本 = 0；权限 CTA 由 `lockPermissions`/`darkModePermission`/`accessibilityTrusted` 分支生成（四组合快照）。
- [ ] **A5（自动）** 磁贴含 hover/pressed/focus 处理（代码存在 `.onHover`/`.focusable` 或等价自定义 style）；三态截图人工复核。
- [ ] **M1（人工）** 首启/重开"使用说明"后，面板在用户屏幕完整可见，底部"设置/退出"不裁切；小屏/缩放（E5）重测。
- [ ] **M2（人工）** Finder/Get Info/系统设置隐私列表/登录项/TCC 提示显示自定义图标；应用名显示为 SwitchPilot（非 "SwitchPilot.app"）。
- [ ] **M3（人工）** Tab 遍历全部控件、焦点环可见、Space/Return 可操作、Esc 可关闭；VoiceOver 读出名称/状态/错误（M5）。
- [ ] **M4（人工）** 深色、增加对比度、降低透明度三种设置下，文字/按钮/callout 边框仍可辨（E1/E2）。
- [ ] **M5（人工）** 权限四组合（未决定/已允许/被拒绝/撤销后）的 CTA 文案、点击结果、错误码展示与真实 OS 状态一致（M1/M3）。

## 未验证与限制

- 离屏渲染不含真机 NSPopover 材质、箭头位置与屏幕约束；面板最终高度/裁切必须以 M1/M5 现场截图为准。
- TCC 提示/系统设置图标无法在代理环境真实触发（responsible process 为 DSH）；需用户从 Finder 启动后验收，且每次 ad-hoc 重建后重新确认。
- 12:02 后实现仍在并发修改（权限分支、设置页撤销文案已变）；本文件按 12:02 构建复核，后续提交需以最新 diff 重核。文档同步（P2-6）未完成前，本评审不构成 UI 验收通过。

## 参考

- Apple HIG：[Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons)、[App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)、[Color](https://developer.apple.com/design/human-interface-guidelines/color)、[Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)、[The menu bar](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar)。
- WCAG 2.2：[1.4.3 Contrast (Minimum)](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)、[1.4.11 Non-text Contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html)。
- macOS 27（Golden Gate）方向二手资料（未独立核实，仅作方向参考）：`artifacts/20261018-1138-oneswitch-naming-ui-redesign.html` §03；[MacRumors](https://www.macrumors.com/2026/06/08/apple-announces-macos-golden-gate/)、[The Verge](https://www.theverge.com/tech/946567/apple-macos-27-golden-gate-dev-beta-hands-on)、[9to5Mac](https://9to5mac.com/2026/06/09/macos-27-golden-gate-includes-these-changes-that-tahoe-critics-will-appreciate/)。
