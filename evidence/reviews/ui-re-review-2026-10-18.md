# UI 复评（delta）：SwitchPilot v0.3.8 / commit 227dc52

- 评审者：独立 UI 评审（只读）。未改源码/文档/Git，未触发 TCC、系统设置、登录项或屏幕状态。
- 对象：v0.3.8（Info.plist 0.3.8，HEAD 227dc52）；截图 `/tmp/review-v038/*.png`（lead 提供的真实离屏 2x 渲染）；源码 `PanelView`/`SettingsView`/`Theme`/`StatusIcon`；文档 DESIGN §10-13、TECH §10-13。
- 方法：截图 alpha 测量内容尺寸；按旧评审清单逐项核对源码/截图；未重新运行 dump（时间/并发限制，数值均来自给定 PNG 与源码）。
- 说明：以下只列 delta；`ui-review.md` / `revoke-disclosure-ui.md` 中已闭环项不再算作问题。

## 结论（先看这里）

- **旧 P0 全部闭环**：`secondaryInk` 已加入 Theme 并在 Panel/Settings 全量替换 `.secondary`；`.green` 作文本已消失；按旧计算 secondaryInk 在 panel/card/tile = 5.07–6.22（light）/ 5.79–7.47（dark），≥4.5。
- **旧 P1 7 项中 6 项闭环**（图标母题、图标网格、面板高度、CTA 状态、磁贴 bordered、设置窗口一致性）；**1 项遗留**：权限告知在 guide 隐藏时仍有 2 处 callout 重复。
- **新 P1 1 项**：v0.3.8 去掉了屏保二次确认，但磁贴副标题仍是「确认后立即启动」（PanelView L259 vs PanelModel L307-315 直接执行）→ 文案与行为冲突。
- P2 层面：字体/术语、小屏无滚动、深色/高对比/VoiceOver、图标 16px/菜单栏 1x、设置展开区层级与文档数字仍有小项；无新增 P0。
- 确认策略变化本身符合用户已确认的产品原则（仅不可逆动作保留确认），但 UI 必须提供"点击前可预期 + 点击后状态可见"；当前屏保副标题问题正好破坏前者，建议先修。

## 已闭环（对照旧清单，不复述原问题）

| 旧项 | v0.3.8 证据 | 判定 |
|---|---|---|
| P0-1 次级对比度 | Theme L7 `secondaryInk`（light #5F5F5F/dark #A8A8A8）；PanelView L49/90/135/174/181/209/220/255/275/328/405/408 与 SettingsView 多处已替换；`.green` 文本消失 | 闭环 |
| P1-1 菜单栏 switch.2 | StatusIcon 改为 S monogram（与 app icon 同基因），不再是双开关/系统符号 | 闭环（真机显示列 P2） |
| P1-2 图标网格/16px | `appicon.png` alpha bbox (100,100)-(924,924)：内容 824/1024，边距 100px，符合 macOS 图标网格 | 闭环（16px/变体见 P2） |
| P1-3 面板高度 | 实测无 guide 380×672、有 guide 380×710（DESIGN §10.5 要求 ≤680/≤760）；AppDelegate L149-150 按 `visibleFrame-120` clamp | 闭环（小屏滚动见 P2） |
| P1-4 权限 CTA 状态 | 未就绪按缺失项分支（Automation/辅助功能/被拒）；设置成功态移除蓝色「申请全部权限」，改为「全部权限已授权」+ 小「重新检查」 | 闭环 |
| P1-6 磁贴 `.plain` | actionTile 改为 `.buttonStyle(.bordered)` + `.controlSize(.regular)` + `contentShape(Rectangle())`（PanelView L343-347），hover/pressed/focus 由系统提供 | 闭环 |
| P1-7 设置窗口一致性 | 460pt；成功/展开两态高度 512/744 自动调整；单「重新检查」；登录开关右对齐；正文 `secondaryInk` | 闭环 |
| 撤销 disclosure 建议 | 「如何撤销授权…」+ chevron、`.plain`/secondaryInk、a11y label+value、展开层级（说明→深链→终端命令→复制）、应用不自动执行、高级重置带 destructive 确认 | 闭环 |

## 仍存在的旧项

**P1-A（旧 P1-5 遗留）权限告知重复**：guide 隐藏且未授权时，外观区与快速动作区同时出现两个 callout，按钮组和文案指向同一组权限（panel-light/dark 截图可见）。建议只保留一个（顶部权限 banner 或仅在缺失权限所属控件旁），另一个删除或降为一行状态；验收：同一屏只出现 1 组「申请 Automation 授权 + 打开…」。

**P2-1 字体/尺寸未完全语义化**：权限 callout 正文仍 `.caption2`(11pt)，状态行/副标题大量 caption2；建议关键说明 ≥12pt（`.caption`/`.footnote`），控件沿用 regular。

**P2-2 术语/文案**：中英混排「Automation」沿用（系统中文本为「自动化」）；「屏保：未执行 / 锁屏：未执行」两行与磁贴副标题信息重复；建议状态行合并/精简。

**P2-4 键盘/VoiceOver 真机项**：disclosure 已提供 accessibilityLabel/Value；面板 Tab/VoiceOver 全路径仍待 M5。

**P2-5 深色/高对比/降低透明度**：dark 截图正常（card #222、panel #181818、callout #332A22），但"增加对比度""降低透明度"未验收。

**P2-6 文档数字漂移**：DESIGN §11/TECH §12 写展开高度 544→711，实测 512→744；更新数字与截图命令（`--dump-settings` 两态钩子已就绪）。

**P2-7 小屏/大字号滚动**：AppDelegate `min(size.height, max(480, screenLimit))` 只裁剪不滚动；1440×800/大字号下可能裁切底部按钮；建议 ScrollView 或 runtime 动态高度验证。

## 新出现（v0.3.7/0.3.8 交互策略相关）

**P1-N1 屏保磁贴副标题与行为矛盾（建议优先修）**：PanelView L259 仍写「确认后立即启动」，但 PanelModel.startScreenSaver（L307-315）已无 NSAlert，点击即执行。用户会以为还有确认步骤；改文案为「点击立即启动，移动鼠标或按 Esc 退出」/「立即启动（未确认时显示已请求）」。锁屏副标题「发送系统锁定快捷键」准确，可保留或改为「立即锁定屏幕」。
**P2-N2 去确认后缺少点击后可见反馈**：屏保/锁屏点击后屏幕状态立即改变，面板可能被遮挡；status 行虽会更新（「已请求启动（未确认）」/「已请求锁定，确认中…」），但需切回面板才可见。建议：执行后立即更新 status 并在 tile 上短暂高亮（不新增确认）；`help`/accessibilityHint 说明可逆方式（移动鼠标/密码解锁）。
**P2-N3 应用内重置的层级/样式**：该项位于「如何撤销授权」→「终端命令（高级）」内的 nested box（settings-expanded），属四层嵌套；建议将其移到独立「高级（不可逆）」分组标题下，按钮文案含"不可逆"，并确认 NSAlert 默认按钮为取消（当前已 destructive，保持）。
**P2-N4 图标资产残留**：S monogram 只在 1024/icns 层验证；缺 light/dark/tinted 变体（Icon Composer 不可用时可接受但要记录）；StatusIcon stroke `max(1.8, inner*0.18)≈2.2pt@18pt` 偏粗，1x 可能发糊；建议 1x/2x 像素对齐 + 16px 目视（M8 已做"简单测试"不等于菜单栏三态验收）。
**P2-N5 菜单栏 S 的歧义风险**：单字母 S 在菜单栏可能与其它字母类图标混淆；真机浅/深/选中三态、与相邻图标视觉重量对比列用户项，不阻塞当前发布。

## 确认策略变化评估（不反对策略，只看 UI 后果）

- 屏保/锁屏点击即执行符合 DESIGN §13 的"明确+常用动作不二次确认"；不可逆的应用内重置仍保留 warning + destructive 确认，符合 HIG destructive action 建议。
- 但"去确认"要求按钮文案必须描述**实际立即发生**的动作；当前屏保副标题是唯一明确冲突，属回归级文案 bug（P1-N1）。
- 次要风险：磁贴为大点击目标（bordered），桌面误触后屏保/锁屏即时生效；已通过系统 hover/pressed 反馈缓解，建议保留；若要进一步降风险，可只在 lock tile 上把动作改为"单击锁定、状态行显示已请求"，不恢复确认弹窗（尊重已确认策略）。

## 验收点（复评通过口径）

1. 屏保磁贴副标题不含"确认"字样，且与实际执行一致；点击后 status 行 1s 内出现"已请求/已启动（未确认）"。
2. guide 隐藏 + 未授权时，同一屏仅 1 个权限 callout、1 组按钮；guide 显示时不重复（现已有 `!guideVisible` 条件，补外观区对称处理）。
3. 设置成功态 512pt、展开 744pt 两态由 `--dump-settings` 复现且无裁切；disclosure 键盘 Space/Return、VoiceOver 读"已展开/已收起"。
4. app icon 16/32px 与菜单栏 18pt 三态截图可辨；icns 16–1024 完整、alpha 边距 100px；`verify-app` 的 icon 检查保持。
5. 小屏/大字号/高对比/降低透明度下无裁切、对比度达标（M5）；M2/M3 真机执行记录前不标 UI 通过。
6. 文档 544→711 更新为实测 512→744，且 DESIGN §10.4 的磁贴/对比度描述与代码一致（现已基本一致）。

## 限制

- 本次未重新运行 `--dump-*`，尺寸/颜色取自 lead 截图；真机 NSPopover 高度、菜单栏三态、TCC 提示图标仍需用户现场验证。
- 工作区可能被并发修改；以上行号对应 v0.3.8 快照（HEAD 227dc52）。旧清单中未提及的项不视为已修。
