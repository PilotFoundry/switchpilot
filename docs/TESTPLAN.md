# TESTPLAN：SwitchPilot 个人自用菜单栏应用 v0.3

日期：2026-10-18；对象：`app/SwitchPilot`；规格：`docs/PRD.md`、`docs/DESIGN.md`、`docs/TECH.md`。

## 1. 测试环境与身份

- macOS 27.0.1 (26A434)，Apple Silicon arm64。
- CLT Swift 6.4 / macOS 27.0 SDK；无完整 Xcode、无 XCTest。
- 被测应用：`app/SwitchPilot/.build/SwitchPilot.app` v0.3.4，bundle id `local.personal.SwitchPilot`，ad-hoc Hardened Runtime 签名。
- 原应用：`/Applications/One Switch.app` 1.35.4 (440)，测试前后版本/hash/签名不变；不启动、不修改其数据。
- 权限前提：未预先授予 Automation/Accessibility；不修改 TCC 数据库、不关闭 SIP、不重签原应用。

## 2. 自动化检查（本轮可执行）

| 编号 | 检查 | 方法 | 通过标准 |
|---|---|---|---|
| A1 | 构建 | `scripts/build-app` | 退出 0，输出 `.app` 路径 |
| A2 | Bundle/plist | `plutil -lint`、`plutil -p` | Info.plist/Entitlements 合法；LSUIElement=true；bundle id/usage description 存在 |
| A3 | 签名 | `codesign --verify --strict` | 退出 0；ad-hoc + runtime |
| A4 | 时长解析 | `SwitchPilotChecks` | 拒绝 0/负数/NaN/inf/非数字；接受合法值 |
| A5 | 真实断言生命周期 | `SwitchPilotChecks` | 三轮 Create/读回/Release；重复 start 幂等；stop 后可读回不存在；deinit 释放 |
| A6 | 定时释放 | `SwitchPilotChecks` | 短时长会话到时自动释放，OS 断言消失 |
| A6b | 进度模型 | `SwitchPilotChecks` | 限时会话暴露 0–1 进度；无限期会话不显示进度 |
| A7 | 权限映射 | `SwitchPilotChecks` | 0/-1743/-1744/-600 映射到正确状态且不崩溃 |
| A8 | 屏保引擎解析 | `SwitchPilotChecks` | 可解析 `com.apple.ScreenSaver.Engine` 路径；不存在时状态为 unavailable |
| A9 | 锁屏权限快照 | `SwitchPilotChecks` | 只读返回 Automation/Accessibility 状态；未授权时不发送按键 |
| A10 | 深色模式只读外观 | `SwitchPilotChecks` | 全局 `AppleInterfaceStyle` 读出深/浅色，不修改系统 |
| A11 | 启动冒烟 | `scripts/verify-app.py` | 应用进程存活 ≥2s，`LSUIElement` 生效（无 Dock 图标不强制自动验证） |
| A12 | 退出清理 | `scripts/verify-app.py` | 终止应用后无 `SwitchPilot` 电源断言残留 |
| A13 | 原应用不变 | `scripts/verify-app.py` | 版本/hash 与基线一致；`codesign --verify --strict` 通过 |
| A15 | 应用图标 | `verify-app.py` | Info.plist `CFBundleIconFile=AppIcon`；bundle 内 `AppIcon.icns` >10KB；`NSWorkspace` 可解析 |
| A16 | 对比度 token | `scripts/check-contrast.py` | `secondaryInk/warningInk/successInk/errorInk` 在 light/dark panel/card/tile ≥4.5:1 |
| A17 | 面板尺寸 | `--panel-size` | 宽 380；无 guide ≤680pt、有 guide ≤760pt（逻辑尺寸） |
| A18 | 语义色静态检查 | `verify-app.py` | PanelView/SettingsView 中 `.foregroundStyle(.green/.orange/.red)` = 0 |
| A19 | 单实例 | 启动冒烟/人工 | 第二个实例提示后退出；`SWITCHPILOT_SMOKE_TEST=1` 仅供测试 |
| A14 | 静态质量 | `python3 -m py_compile`、`sh -n`、`git diff --check` | 退出 0；不声称运行不存在的 linter |

记录：`evidence/app-runtime.md` + `evidence/raw/app/`（原始日志不入 Git）。v0.3 核心自检 12 项、自动化验收 11 项；独立评审见 `evidence/reviews/`。

## 3. 现场手动验收（需用户在场）

以下项目**不在自动化中执行**，因为会改变屏幕状态、触发 TCC 系统弹窗或需要用户授权；必须在用户知情且可解锁屏幕时进行。

### M1 深色模式

1. 打开面板 → 深色模式行应显示"需要授权"与入口，点击开关不改变系统外观。
2. 点击"请求授权…" → 系统 Automation 提示出现；选择"允许"后重试开关。
3. 开关到深色/浅色各 3 次，每次确认面板状态与系统外观一致（读回）。
4. 在系统设置撤销授权 → 再次操作应显示被拒绝/需要授权，且不显示成功。
5. 结束：把系统外观恢复为测试前状态并确认。

### M2 启动屏保

1. 点击"启动屏保" → 确认对话框出现，文案说明可能的密码解锁影响。
2. 确认后屏保应启动；移动鼠标/按键退出屏保。
3. 记录是否出现密码提示；退出后界面显示"已请求启动"或真实错误。
4. 失败/行为不符时记录系统版本与具体现象，不把静态线索算作通过。

### M3 锁定屏幕

1. 未授予 Accessibility 时点击"锁定屏幕" → 显示缺少辅助功能（及 Automation 状态），不发送按键、不锁屏。
2. 按引导授予 Accessibility 与 Automation 后重试 → 确认后应锁定屏幕。
3. 解锁后检查面板读回：显示已锁定（若可读回）或"已请求，未确认"。
4. 撤销权限后重试 → 应回到权限引导，不崩溃。

### M4 保活扩展

1. 15/30/60 分钟与无限期各验证一次开启/读回/关闭；到时自动释放。
2. 面板最小化/重新打开后状态保持正确。
3. 正常退出、强退（`kill`）后 `pmset -g assertions` 无本应用断言。
4. 有条件时做一次睡眠/唤醒后状态检查；无法安全完成的标成未验证。

### M5 UI/无障碍

1. 菜单栏图标点击开合面板；点击面板外关闭。
2. 键盘 Tab 聚焦全部控件，Space/Return 可操作；无鼠标歧义。
3. VoiceOver 读数：控件名称、状态、错误可理解（不要求全路径完美）。
4. 浅色/深色外观下文字对比度可读。

### M7 首次引导与新面板（v0.2）

1. 首次打开面板应出现“开始使用”三条规则；点“知道了”后关闭，重启应用不再自动出现。
2. 点 footer“使用说明”可重新打开引导卡；“收起说明”可关闭。
3. 保活开启后显示进度条与剩余时间；无限期不显示进度条。
4. 深色模式未授权时点开关应回弹并显示行内授权入口，不弹系统设置或改变外观。
5. 锁屏缺权限时磁贴显示“需授权”，点它只显示行内说明，不锁屏、不发按键。
6. 浅色/深色系统外观下检查对比度与文字可读性；缩放窗口/不同分辨率下不截断。

### M8 设置、登录启动与图标（v0.3）

1. 面板 footer「设置…」与状态项右键「设置…」都能打开设置窗口；关闭后再次打开状态已刷新。
2. 设置 › 权限：申请全部权限（允许/拒绝各一遍）状态真实；重新检查可用；撤销说明指向系统设置，不自动 reset。
3. 设置 › 登录：开启后系统设置 › 通用 › 登录项出现 SwitchPilot；注销/重启验证自动启动；需要批准时按钮可打开登录项设置；关闭后登录项消失。
4. 状态项右键菜单：设置… / 使用说明 / 退出均可用；左键仍打开面板。
5. Finder Get Info / 系统设置隐私列表 / 登录项 / TCC 提示显示自定义图标（非通用图标）；菜单栏图标为 S monogram 且浅/深/选中状态可辨。
6. 小屏（1280×800）/放大字体下，首启 guide 面板完整可见、底部按钮不裁切；`--panel-size` 已做逻辑尺寸断言，但真机 popover 需目视。
7. v0.3.4 权限区：已授权时无「申请全部权限」；「如何撤销授权…」默认收起，展开含系统设置深链与「终端命令（高级）」；展开后窗口自动增高（实测 544→711），键盘 Space/Return 可切换、VoiceOver 读展开状态；复制命令不改变系统。
8. 稳定签名身份：重建/重签/重装后，已授予的 Automation/Accessibility 不应失效；用 `--diagnose-permissions` 复核。

### M6 边界/恢复

1. 重复启动应用的行为（多实例/多图标）记录为已知限制。
2. 系统设置中撤销自动化/辅助功能后，应用不崩溃、不假成功。
3. 卸载：删除 `.app` 即可；TCC 中残留条目可手动删除（记录步骤，不自动改 TCC）。

## 4. 验收判定

- **通过**：自动化 A1–A14 全绿，且该功能对应的现场手动项按预期执行并有记录。
- **部分/未验证**：代码与静态证据存在，但现场项未执行；文档与 UI 必须明确标注，不得写"完成"。
- **失败**：动作返回错误或与实际系统状态不符；记录真实错误码并回退界面状态。

v0.1 收口标准：A1–A14 通过；M1–M3 由用户在场执行并记录（未执行则保持"待授权/待现场验证"）；M4 至少完成正常退出与强退后的无残留检查，睡眠/唤醒可留缺口。

## 5. 恢复与回退

- 原应用、其偏好与签名不做任何修改；测试前后比较 hash。
- 深色模式：测试前记录当前外观，测试结束恢复并读回。
- 屏保/锁屏：现场确认后执行；锁屏需用户可立即解锁。
- 权限：仅在用户主动操作时申请；撤销入口写在 README；不直接编辑 TCC 数据库。
- 删除应用 = 删除 `app/SwitchPilot/.build/SwitchPilot.app`；不新增全局配置文件。

## 6. 记录模板

每次验收记录：日期/时间、应用构建哈希（`codesign -dv` 或 `shasum`）、功能、操作、期望、实际、OSStatus/错误、是否恢复、截图/日志路径（原始日志放 `evidence/raw/`，不入 Git）。

## 7. 本轮明确未执行项

深色模式真实授权与切换、屏保真实启动、锁屏真实锁定、睡眠/唤醒、VoiceOver、多实例、首次引导交互手测、设置/登录项/图标现场项、长时间稳定性、分发签名/公证/Sandbox。以上不得在 README 或能力矩阵中记为通过。
