# SwitchPilot v0.5.1 防回归自动化方案

- 对象：v0.5.1 评估，v0.5.2 集成（`dac2aac` 基线）；范围依据 `docs/CORE.md`：个人自用、低权限、少而可靠，不重复系统顶栏/控制中心控制，状态可见/可恢复/诚实降级。
- 现有自动验收（由 Lead 全量跑）：`scripts/verify-app.py` 12/12、`SwitchPilotChecks` 14/14、`scripts/check-contrast.py`、`--panel-size`。
- 本文新增：`scripts/qa-regression.py`（只读、零外部依赖、可重复、不触发 TCC/屏幕/麦克风/登录项/清洁模式）+ 回归矩阵与集成建议。本方案不替代现场人工项（TESTPLAN §3.1 未执行项不得写通过）。

## 1. 回归风险矩阵

| # | 回归点（CORE 边界/功能） | 自动断言（本脚本 / 现有资产） | 人工边界（用户在场） |
|---|---|---|---|
| R1 | CORE 边界文档存在且被 AGENTS/README 引用 | 本脚本：存在/关键词/引用 | 文档语义评审 |
| R2 | 输出音量已移除（不重复系统控制） | 本脚本：源码+UI 无 `AudioOutput/outputVolume/音量` | 面板目视确认无音量卡 |
| R3 | 无私有 CoreBrightness/NightShift/私有输入 API | 本脚本：禁用符号扫描 | — |
| R4 | `tccutil` 不得自动执行（仅设置页显式确认） | 本脚本：允许文件白名单、唯一调用点、启动路径无引用、有破坏性确认、无 sudo/reset All | M13-4/应用内重置真实执行 |
| R5 | 启动/刷新不主动请求权限、不自动静音/清洁 | 本脚本：启动路径禁用符号、麦克风只读+唯一 toggle、清洁仅显式入口 | 首启/权限引导交互复现 |
| R6 | 麦克风静音：能力感知 + 状态可见（含状态项）+ 不支持降级 | 本脚本：`kAudioDevicePropertyMute`、`setMuted/toggle`、不支持文案、面板状态/标签；Checks：`microphone state readable` | M12 支持/不支持设备真实写入 |
| R7 | 屏幕清洁：普通模式无倒计时/自动退出 | 本脚本：`duration: Int? = nil`、`showsCountdown = duration != nil`、Timer 仅测试分支、env 变量门控、文案 | M13 步骤 4：普通模式不自动退出 |
| R8 | 屏幕清洁：键盘锁定 + 鼠标点击退出 | 本脚本：keyDown/keyUp/flagsChanged 事件掩码、无鼠标事件拦截、退出文案 | M13 键盘拦截/鼠标退出真实事件 |
| R9 | 清洁无权限降级 | 本脚本：`accessibilityRequired` 错误路径存在（静态） | M13-4 无权限真实降级 |
| R10 | 快捷键默认关闭，仅显式开启后注册 | 本脚本：`hotKeysEnabled` 缺省 false、`startIfEnabled` guard、启动路径不 set(true)、文档声明 | M9 后台触发/停用/重启保持（长期） |
| R11 | 单实例：plist key + 启动守卫 | 本脚本：`LSMultipleInstancesProhibited`、`enforceSingleInstance`、SMOKE_TEST 旁路 | 双开/图标冲突目视 |
| R12 | Bundle 边界：0.5.1、LSUIElement、图标、`switchpilot://`、仅 Automation 权限面 | 本脚本：Info.plist/Entitlements/图标/plutil 断言；verify-app 同步 | M8-4 系统 UI 图标目视 |
| R13 | 面板尺寸不回归 | 本脚本调用 `--panel-size`：380x<=840 / 380x<=900 | 小屏/放大字体真机布局（M5） |
| R14 | 对比度 token ≥ 4.5:1 | 本脚本复用 `check-contrast.py`；verify-app 同步 | 浅/深/高对比度目视 |
| R15 | 测试资产不缩水（防误删检查） | 本脚本：verify-app≥12、Checks≥14、脚本存在 | — |
| R16 | TCC 允许/拒绝/撤销、登录项、注销/重启、锁屏/屏保/关闭显示器、睡眠唤醒 | 不做自动；只允许只读诊断（日志/plist/状态） | M1/M2/M3/M8-3/M8-4/M10/M4/M7 现场 |

## 2. 可运行脚本草案与试跑

命令：`/usr/bin/python3 scripts/qa-regression.py`（可重复；FAIL 退出码 1，SKIP 不判失败）。

试跑结果（2026-10-18，本机）：**13/13 PASS, exit 0**；已接入 `verify-app.py` 作为第 12 步，全量 **12/12**。v0.5.2 面板压缩后实测无引导 **380x730**、带引导 **380x803**（阈值 380x≤760/≤840）。脚本只读源码与构建产物；`--panel-size` 为离屏诊断（prohibited 激活策略、不显示 UI、不请求权限、不录音；仅只读麦克风 muted 属性），未触发 TCC/屏幕/麦克风/登录项/清洁模式。

脚本包含 13 组断言（已重命名为 `scripts/qa-regression.py`，版本号断言改为语义化版本检查）：CORE 引用、输出音量移除、私有依赖、tccutil 非自动、启动路径无自动状态变更、麦克风能力、清洁边界、快捷键默认关闭、bundle/权限边界、单实例守卫、测试资产完整、对比度 token、面板尺寸阈值。

## 3. 集成建议

- **并入 `verify-app.py`（作为一步）**：R1–R5、R10–R12、R15 以及 R13/R14 可直接调用本脚本或复制断言——它们快速、无副作用，适合每次全量验收硬门禁；`verify-app.py` 已有 plist/尺寸/对比度检查，与脚本重复处保留一处即可（建议 verify-app 只保留“产物级”断言，政策级静态断言归独立脚本）。
- **并入 `SwitchPilotChecks`（纯逻辑/读回）**：麦克风 `read()/supportsMute` 降级路径、清洁模式 `duration` 解析与测试 env 语义、快捷键默认值读取；不要放入需要 Accessibility/真实事件的清洁事件 tap 测试。
- **保留独立回归脚本**：跨文件/文档一致性（CORE、AGENTS、README、TESTPLAN §3.1）、红线 grep（tccutil/私有 API/输出音量）、harness 计数；这类断言随政策演进，放独立脚本避免污染产品验收。
- **流程**：日常改动 → `qa-regression-v051.py`（秒级）→ `verify-app.py` → `SwitchPilotChecks`；本地 CI/脚本串行执行、任一步失败即停；现场人工按 TESTPLAN §3.1 勾选，未执行保持待办。
- 本脚本应在 `verify-app.py` 之前跑（快速反馈）；`--panel-size` 需要已有构建产物，未构建时输出 SKIP 而非 FAIL。

## 4. 已知缺口（脚本不能替代现场）

- 屏幕清洁的键盘拦截/鼠标退出、普通模式不自动退出：需要真实事件与 Accessibility 授权；脚本只验证代码边界。
- 麦克风静音真实写入/读回：需要支持 `kAudioDevicePropertyMute` 的输入设备；不支持设备的降级行为需人工。
- TCC 允许/拒绝/撤销、应用内重置真实执行、登录项真实注册/注销/重启、图标在系统 UI 的显示、锁屏/屏保/关闭显示器/睡眠唤醒、快捷键真实触发：仍需用户在场按 TESTPLAN 执行。
- 脚本是“边界护栏”，不能证明功能行为正确；任何自动 PASS 都不能替代人工验收或把未执行项写成通过。
