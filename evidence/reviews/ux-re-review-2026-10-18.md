# SwitchPilot v0.3.8 UX 复评（delta）

- 评审人：ux-reviewer｜2026-10-18｜核对基线：commit `227dc52`（v0.3.8，工作树干净）；输入：/tmp/review-v038 截图、`PanelView/SettingsView/PanelModel/SettingsModel`、DESIGN §10-13、TECH §11-13
- 对照：`evidence/reviews/ux-review.md`（v0.2/v0.3 WIP 清单）、`revoke-disclosure-ux.md`；只读评审，未运行应用、未触发 TCC/系统设置/登录项。

## 结论

- 上一轮 P0 已全部闭环，**无新 P0**；本轮 **P1 4 项（3 新 / 1 残留）+ P2 7 项**。整体已达"可日常使用"，剩余问题集中在**文案与实际行为不一致**（v0.3.7/8 确认策略未同步到引导/磁贴）与少数权限状态文案。
- 不重做已通过部分：首启流程、三态 CTA、成功态去主按钮、撤销 disclosure、tccutil 仅高级显式确认、右键菜单、面板高度、状态行拆分、ink 对比均已达标。
- 唯一需要立即修的是 P1-1（屏保/锁屏"会先确认"与实际点击即执行矛盾）与 P1-2（锁屏 callout 缺项信息不完整）；其余为打磨。

## 已闭环（对照原清单）

| 原项 | 现状证据 | 判定 |
|---|---|---|
| P0-1 锁屏"点哪里授权" | `PanelView.swift:276-300` 按缺失权限分支，CTA 点名权限，guide 可见时隐藏重复 callout | 闭环（残留 P1-2） |
| P0-2 首启全部申请 | guide「申请全部权限/重新检查/稍后」；`PanelModel` 后台请求 + AX prompt；按钮"请求中…"；不显示假成功 | 闭环（P1-1 文案） |
| P0-3 应用内 tccutil 不发布 | 策略变更（用户确认）：v0.3.5 仅高级+显式确认+destructive+固定两项+无 sudo/All，docs §12 | 闭环（风险接受；UI 见 P1-3） |
| P0-4 权限动作 scope | 外观仅申请 Automation；锁屏按缺失项；设置三态 CTA（denied→打开设置） | 闭环 |
| P1-2 主线程 AEDetermine | PanelModel/SettingsModel 改后台队列 + 主线程回写；"请求中…" | 闭环 |
| P1-3 设置可发现性 | footer「设置…」+ 状态项右键菜单（设置/说明/退出，Cmd+,） | 闭环 |
| P1-4 撤销后刷新 | 外部设置监听 + `refreshAsync`；v0.3.2 起回前台自动刷新 | 闭环 |
| P1-5 AX 系统提示 | `requestAccessibilityPrompt()` 走 `Permissions.accessibilityPrompt()` | 闭环 |
| P1-7 小字对比/无障碍 | `secondaryInk` + warning/success/error 仅图标填充；截图浅/深可读；docs §10.4 断言 ≥4.5:1 | 闭环（现场 VO 待） |
| P2-1/2/3/4 | "发送系统锁定快捷键"、"保活关闭"胶囊、状态行拆分、面板高度按屏幕约束 | 闭环 |
| revoke 建议 | 默认折叠、成功态去主按钮、推荐/高级分离、复制反馈"已复制"、三态 | 闭环；标签未采用"管理权限…"（P2-3） |

## 仍存在 / 回归

- **P1-1（新）确认文案与实际行为不一致（v0.3.7/8 回归）**
  - 证据：guide 第 3 条仍写"「屏保 / 锁屏」会先确认"（`PanelView.swift:87`）；屏保磁贴副标题"确认后立即启动"（`PanelView.swift:259`）；代码已无确认（`PanelModel.startScreenSaver` 直接执行）。锁屏同样即时锁定。
  - 建议：guide 改"屏保/锁屏点击即执行；屏保移鼠标退出、锁屏需密码解锁；锁屏还需辅助功能授权"；副标题改"立即启动（移动鼠标退出）"/"立即锁定（需密码解锁）"；grep 清零"确认后/会先确认"。验收：新截图 + grep + M7 走查。
- **P1-2（新）锁屏 callout 缺项不完整**：`PanelView.swift:279` 硬编码"当前缺少 Automation"；截图实际两项皆缺，会漏掉辅助功能。建议按 `lockPermissions` 生成缺失列表（"当前缺少：Automation、辅助功能"），两项都缺时 CTA 仍分两步或给"申请全部权限"。验收：双缺 / 仅缺 AX / 双授权三态截图。
- **P1-3（新，v0.3.5 引入）应用内重置按钮的误触与可恢复性提示**：按钮位于"终端命令（高级）"内、紧邻[复制命令]，灰色 `.bordered`，标签不含"不可撤销"（`SettingsView.swift:175-181`），destructive 只在确认框内；确认框本身正确（取消默认、范围两项、无 sudo/All）。建议独立"不可逆操作"区块 + ⚠ 标题、按钮红色/`role: .destructive`、文案"在应用内重置两项权限（不可撤销）…"，重置后引导重新申请。验收：M8 手测确认框默认键与取消路径。
- **P1-4（残留，旧 P1-8）单实例未强制**：`Info.plist` 无 `LSMultipleInstancesProhibited`；登录项 + 手动启动可多图标。建议加键或启动时激活已有实例；验收：两次启动仅一个状态项。
- **P2-1 登录项残留**：`setLoginItem` 先写"已开启登录时启动"，`requiresApproval` 覆盖判断读旧 `loginState`（`SettingsModel.swift:122-140`）；错误直接显示英文 `localizedDescription`。建议以读回状态生成文案 + 中文错误映射，`requiresApproval` 给[打开登录项]。验收：在系统设置关闭后回应用。
- **P2-2 成功态重复**：设置中"全部权限已授权"（`SettingsView.swift:45-49`）是第三行绿勾，与两行 detail 重复；版本在"关于"+footer 各出现一次。删一行总结或上移为区标题；版本只留一处。
- **P2-3 disclosure 语义/可达性**：一级"如何撤销授权…"+自绘 chevron 非原生 `DisclosureGroup`，省略号像动作；建议改"管理权限…"或去省略号并用原生控件，chevron `.accessibilityHidden(true)`。验收：Tab/Space、VO 读"已展开/已收起"。
- **P2-4 未就绪诊断块**：等宽原始状态+应用路径常驻权限卡（`SettingsView.swift:55-67`），占主视觉；建议收进"诊断详情"折叠，常态只留一句人话。验收：未授权截图。
- **P2-5 术语统一**：面板 badge"需授权"、行内"待授权"、footer"未授权"并存；统一为 已授权/未授权/已拒绝/检查中。验收：grep + 截图。
- **P2-6 成功态 guide 冗余**：`allPermissionsReady` 时按钮 label"权限已就绪"仍 disabled 显示且旁边另有[重新检查]；建议只留一个状态/一个按钮。验收：全授权首启截图。
- **P2-7 缺权限点击磁贴直接触发系统 UI**：`presentLockFlow` 在缺权限时直接 `requestLockAutomation()`/`requestAccessibilityPrompt()`，而行内 callout 同时存在；用户误点磁贴会被弹 TCC/打开设置。建议缺权限态点击磁贴只聚焦/展开 callout，只有显式点 callout CTA 才请求。验收：缺权限点锁屏磁贴不弹系统 UI、焦点落到 callout。

## 验收点（建议新增/保留）

1. 文案一致性：`grep -n "确认" PanelView` 无非系统权限确认语义；guide/磁贴与即时执行一致。
2. 锁屏三态 callout 正确；双缺不再只说 Automation。
3. 设置成功态：无"申请全部权限"、仅[重新检查]+折叠撤销；展开后推荐/高级分层，复制反馈可见。
4. 应用内重置：按钮含不可撤销字样、确认框取消为默认、范围仅两项、无 sudo/All；重置后消息引导重新授权（M8）。
5. 登录项：未开启/已开启/需批准/未找到四态 mocks + 中文错误；注销/重启按用户要求挂长期待办、不阻塞。
6. 键盘/VoiceOver：设置 Tab 顺序、Space/Return 展开、VO 标签与 chevron、浅/深对比（与 ui-reviewer 复核）。
7. 单实例：两次启动一个图标。

## 限制

- 静态评审 + 离屏截图；未运行应用/未触发 TCC、系统设置、登录项；M2/M3 真实执行、登录项注销/重启仍未验，结论不外推到运行时。
- 截图未覆盖：denied 态、requiresApproval 态、guide 全授权态、重置后状态；建议补离屏渲染或现场截图。
