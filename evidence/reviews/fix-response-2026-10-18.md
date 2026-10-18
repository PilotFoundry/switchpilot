# SwitchPilot v0.3.9：UI/UX 复评修复响应

- 输入评审：`ui-re-review-2026-10-18.md`（P1×2）、`ux-re-review-2026-10-18.md`（P1×4、P2×7）；基线 v0.3.8，实现响应版本 v0.3.9。
- 结论：无 P0；复评提出的 P1 均有对应处理，除明确延后的真机/无障碍项外不遗留可静态修复项。

## 已修复

| 评审项 | 处理 |
|---|---|
| UI P1-A 两个权限 callout | 合并为单一「需要授权」卡片，缺失项动态列出、CTA 按缺失/拒绝分流 |
| UI P1-N1 / UX P1-1 文案与即时执行矛盾 | guide 第 3 条、屏保/锁屏磁贴副标题全部改为点击即执行 + 退出/解锁说明；verify 增加 stale copy 检查 |
| UX P1-2 锁屏缺项硬编码 | 统一权限卡动态列出 Automation/辅助功能，双缺不再漏项 |
| UX P1-3 应用内重置误触 | 独立「不可逆操作」区块、按钮含"不可撤销"、`.tint(.red)`，确认框仍为取消默认 |
| UX P1-4 单实例 | Info.plist `LSMultipleInstancesProhibited` + 启动守卫；普通重复启动实测 1 个实例；`open -n` 仅诊断，运行中诊断改用 `switchpilot://diagnose` |
| P2 登录项消息竞争 | 注册/注销后等 `refreshAsync` 完成，再按真实状态生成中文消息 |
| P2 成功态重复/版本重复 | 删除第三行"全部权限已授权"；版本只保留在「关于」 |
| P2 诊断块常驻 | 收进默认收起的「诊断详情」 |
| P2 disclosure 语义/chevron VO | 去掉省略号；chevron `.accessibilityHidden(true)`，保留 label/value/hint |
| UI P2 成功 guide 冗余 | 权限已就绪时不再显示禁用的"申请全部权限"按钮 |

## 接受但延后/不改

- 小屏 ScrollView、高对比/降低透明度/VoiceOver：M5 现场/后续布局项，v0.3.9 仅记录。
- S monogram 描边/变体、菜单栏三态、AppIcon 真机显示：需 M5/M8 现场，资产不做无证据改动。
- 术语统一（待授权/未授权/需授权）：保留按状态区分的现有文案，避免本轮引入语义回归。
- disclosure 一级标签：保留用户已确认的「如何撤销授权」，未改为「管理权限…」。

## 验证

- `verify-app.py` 11/11、`SwitchPilotChecks` 12/12；stale copy 与 plist key/URL scheme 已纳入自动检查。
- 面板 380×637（无 guide）/380×710（guide）；设置窗口 523（折叠）/774（展开）pt。
- 普通第二次 `open` 保持 1 个实例；`open "switchpilot://diagnose"` 正常写只读诊断；`scripts/onsite-probe` 正常完成（已移除会挂起的 sfltool 步骤）。
- 未执行：M2/M3 真实动作、M8-3 注销/重启、M8-4 图标目视、M5 无障碍/小屏；不记为通过。
