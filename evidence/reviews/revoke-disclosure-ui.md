# 设置页「权限」区：撤销授权信息的 IA / 视觉评审

- 评审对象：`SettingsView.swift` `permissionSection`（L35-99，快照 `001b504…`，12:28:49）与截图 `/tmp/settings-permissions-current.webp`（12:33，两项权限均已授权）；边界：只读评审，未改源码/文档/Git，未触发 TCC/系统设置/登录项；行号对应上述快照。
- 相关：`evidence/reviews/ui-review.md`（本面板对比度/图标基线）、`docs/DESIGN.md` §9（v0.2 未含设置窗口，v0.3 需补规格）。

## 结论（明确推荐）

- **推荐：一级只保留一个次要 DisclosureGroup「如何撤销授权…」，默认收起、inline 展开；成功态移除蓝色「申请全部权限」；撤销说明只在"至少一项已授权"时出现。** 不建议常驻说明块、popover/sheet、高级菜单或"仅未授权时展示"。
- 一级标签用 **「如何撤销授权…」**（说明性措辞 + 省略号 + chevron），不要用「撤销授权」直接当一级按钮（易被读成"点了就执行/不可逆"）；也不要用「高级」「更多」这类无信息标签。
- 展开内容分三层：一句"须在系统设置手动完成，本应用不会自动调用 tccutil" → 两个系统设置深链按钮 → 二级折叠「终端命令（高级）」内含可复制命令（不自动执行）。
- 权限已授权时："申请全部权限"不再成立，应替换为"✓ 全部权限已授权"状态行；保留小的「重新检查」与上述 disclosure。权限区成功态可从约 6 行压到约 4 行，去掉 Divider 与常驻说明。

## 现状问题（截图 + 源码证据）

- 成功态仍出现大蓝「申请全部权限」（L61-67，`.disabled` 只绑定 `busy`，未绑定 `permissionsReady`）→ 与"已授权"矛盾，用户会怀疑状态是否真实，也稀释主操作层级。
- Divider（L78）+ ⓘ「如何撤销授权」+ 长段说明 + 两个按钮（L79-97）常驻一级，占权限区近半高度；撤销是低频、引导性信息，不应与"当前状态"同权重。
- 「打开自动化设置」「打开辅助功能设置」（L91/L94）在已授权状态下语义模糊：打开系统设置 ≠ 撤销，需要用户在系统设置里再找/再操作，按钮文案未说明"去那里撤销"。
- 文案把 `tccutil`（终端命令）放在一级说明里（L86），既增加视觉噪声，也容易被理解为应用会执行危险操作。

## 方案比较

| 方案 | 评价 | 结论 |
|---|---|---|
| A. 当前常驻块 | 发现性好，但成功态噪声大、与"已授权"冲突、把低频说明升为主内容 | 不推荐 |
| B. 一级 DisclosureGroup，inline | 渐进披露；保持设置页上下文；原生键盘/VoiceOver；无模态层 | **推荐** |
| C/D. popover / sheet | popover 承载纯说明不符合 HIG Settings；sheet 对纯说明过重，焦点/VoiceOver 成本高（将来若应用内执行撤销再用确认 sheet） | 不推荐 |
| E. 收进「高级/…」菜单 | 菜单无法承载说明/深链/状态联动；发现性差、VoiceOver 路径长 | 不推荐 |
| F. 仅未授权时展示 | 方向反了：撤销需求恰好发生在**已授权之后**，会在最需要时隐藏 | 不推荐 |

## 推荐布局与文案

成功态（折叠，权限区约 4 行）：

```
权限                                        ✓ 全部权限已授权
只在需要时申请；不授权也可使用保持亮屏与启动屏保。
✓ Automation（System Events）      已授权
✓ 辅助功能（Accessibility）        已授权
[重新检查]                              ⌄ 如何撤销授权…   ← 次要文字+chevron
```

展开后（inline，位于同一卡片底部）：

```
⌃ 如何撤销授权…
  撤销需在系统设置中手动完成；SwitchPilot 不会自动调用 tccutil。
  [打开自动化设置]  [打开辅助功能设置]
  ▸ 终端命令（高级）                              [复制]
      tccutil reset AppleEvents local.personal.SwitchPilot
```

未就绪态：保留蓝色主 CTA「申请全部权限」（`borderedProminent`）+「重新检查」+诊断块；**只有当 Automation 或辅助功能至少一项已授权时才显示撤销 disclosure**；全部未授权时隐藏（无撤销对象）。

交互细节：
- 状态放 `SettingsModel`（`@Published private(set) var showRevokeHelp` + `toggleRevokeHelp()`），不要用 `@State`——CLT 缺 SwiftUI 宏插件（`app/SwitchPilot/README.md` 已记录），当前项目所有状态都在 model。
- 一级行用整行可点击的 `.buttonStyle(.plain)` + 自绘 chevron（`chevron.down/right`），字体 `.caption`/13pt，颜色 `Color.secondaryInk`（不要系统 `.secondary`，见 ui-review P0），不要 bordered/红色/强调色。
- 展开动画用系统默认即可（尊重"减少动态效果"）；chevron 需 `accessibilityLabel` 描述"如何撤销授权，已收起/已展开"。
- 深链按钮用 `.bordered` + `.controlSize(.small)`；打开系统设置后不假设成功，提示用户回来点「重新检查」。
- tccutil 命令：`Text` 等宽 + `.textSelection(.enabled)` + 「复制」按钮，复制成功用 `accessibilityAnnouncement` 反馈；**应用内绝不自动执行**（与 QA 红线一致）。
- 状态联动：外部撤销 → 「重新检查」→ 未就绪时主 CTA 回归、撤销 disclosure 自动隐藏；全部授权后不显示蓝色 CTA；`message` 仍可显示在区外一行。

## 避免的反模式

- 一级出现红色/描边 destructive 按钮（看起来会立即、不可逆执行）。
- 「撤销授权」纯文字按钮实际只打开系统设置（文案与结果不符）。
- 常驻 Divider + 说明段 + 两个按钮把低频信息升为主内容。
- 把 `tccutil` 放一级或提供"一键撤销"而不做二次确认/不说明影响。
- 成功态仍显示「申请全部权限」或同时存在两个「重新检查」（当前已重复）。
- 隐藏撤销入口（仅未授权展示）或在展开区里放第三个同义"打开系统设置"按钮。

## 依据

- Apple HIG：[Settings](https://developer.apple.com/design/human-interface-guidelines/settings)（设置窗口应层级清晰、把低频/高级选项放入渐进披露而非并列）、[Disclosure controls](https://developer.apple.com/design/human-interface-guidelines/disclosure-controls)（chevron 表示可展开、键盘可操作）、[Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons)（按钮层级与文案要可预期）、[Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)。
- macOS 27 方向（二手，未独立核实）：`artifacts/20261018-1138-oneswitch-naming-ui-redesign.html` §03 "少即是多、收敛装饰/层级"；撤销说明属二级信息，符合渐进披露。
- 可访问性：DisclosureGroup 原生提供展开/收起语义；对比度用 `secondaryInk`（≥4.5:1）；命令文本可选可复制；Tab 顺序 = 状态行 → 重新检查 → 撤销 disclosure →（展开后）深链按钮。

## 验收点（评审者视角）

1. 成功态权限区不出现 Divider/长说明/深链按钮；只出现状态行、两行权限、「重新检查」、「如何撤销授权…」；整体高度较当前减少 ≥25%。
2. 撤销 disclosure 默认收起；点击整行/chevron 可展开；Space/Return 可切换；VoiceOver 读出名称与"已展开/已收起"。
3. 一级无蓝色「申请全部权限」；未就绪时它恢复为 `borderedProminent`，且与「重新检查」并列不重复。
4. 展开内容不默认展示 tccutil 命令；二级「终端命令（高级）」可展开/复制，复制有反馈，应用不执行任何 TCC 写操作。
5. 深链按钮打开正确的系统设置面板；返回后「重新检查」状态更新，权限区在已授权/未授权间切换一致。
6. 浅/深外观下说明文本与命令文本对比度 ≥4.5:1；无 `.green`/`.orange` 文本（沿用 ui-review P0 修复要求）。
7. 键盘 Tab 顺序合理、焦点环可见；窗口 460pt 宽下中文换行不破词、不横向滚动。

## 未决定 / 风险

- 「如何撤销授权…」较「管理权限…」更长，但避免"已执行"歧义；若后续改为应用内执行撤销，入口与文案需重新评审（应改为确认 sheet + 明确不可逆影响）。
- 当前实现状态（12:28）仍在并发修改；建议实现后重跑 `--dump-settings` 离屏渲染，复测折叠/展开两态高度与对比度。
