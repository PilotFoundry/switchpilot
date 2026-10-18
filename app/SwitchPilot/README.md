# SwitchPilot（个人自用 v0.5.0）

原 One Switch 1.35.4 的个人自用最小菜单栏替代。**不是分发产品**；SwitchPilot 是 2026-10-18 确定并经用户同意转正的正式名（候选比较见 `artifacts/20261018-1138-oneswitch-naming-ui-redesign.html`），中文描述「菜单栏开关」。目标、面板与验收见 `docs/PRD.md`、`docs/DESIGN.md`、`docs/TECH.md`、`docs/TESTPLAN.md`；最高层取舍见 `docs/CORE.md`。

## 当前状态

| 功能 | 实现状态 | 运行时验收 |
|---|---|---|
| 显示器保活（15/30/60 分钟、无限期） | 已完成，带进度/剩余时间 | ✅ 真实断言开关/读回/释放已验证（`evidence/app-runtime.md`） |
| 系统深色模式 | 已完成（权限门控，行内授权入口） | ✅ 用户现场 M1 通过（2026-10-18） |
| 启动屏保 | 已完成（点击即执行，无二次确认） | ✅ 用户现场自测通过（M2） |
| 锁定屏幕 | 已完成（权限门控，点击即执行，无二次确认） | ✅ 用户现场自测通过（M3） |
| 全局快捷键 | 已完成（固定组合，默认关闭） | ⏳ 注册逻辑已验；真实按键按用户要求并入**长期统一测试**（M9） |
| 关闭显示器 | 已完成（公开 pmset；点击即执行） | ✅ 用户现场自测通过（鼠标唤醒，M10） |
| 麦克风静音 | 已完成（CoreAudio 能力感知；状态显眼） | ⏳ 真实静音写入/读回与不支持设备待现场（M12） |
| 屏幕清洁 | 已完成（全屏遮罩；锁键盘、鼠标点击退出、60s 自动退出） | ⏳ 真实输入拦截/鼠标退出/多屏待现场（M13） |
| 登录时启动 | 已完成（SMAppService 状态机） | ✅ 注册/注销实测；注销/重启真实启动列为**长期待办**（收尾时验证） |

v0.5 面板：单一不透明表面、可读次级文字、状态胶囊、首启引导、保活进度、权限单卡、麦克风卡（能力感知、静音状态显眼）、三个快速动作（屏保/锁屏/关闭显示器，点击即执行、无二次确认）、全宽「清洁屏幕」按钮（锁键盘、鼠标点击退出、60s 自动退出）、设置窗口（权限/快捷键/登录/关于，诊断可折叠）、状态项右键菜单。输出音量已按“不重复系统控制”原则移除。默认不自动执行 tccutil reset；撤销授权默认走系统设置，高级区另有显式确认的「在应用内重置权限…」。设计见 `docs/DESIGN.md` 与核心指导 `docs/CORE.md`。

已知排除项/移出：Night Shift 直接控制（私有框架）、合盖不休眠/特权 helper、输出音量（系统已有）、低电量模式/电量控制（系统电池菜单已有）、音频输出/输入设备切换、私有 API、修改原应用、后台自动控制。

## 验收与诊断

- M1/M3/M8 现场验收前置/步骤：`evidence/onsite/M1-M3-M8-2026-10-18.md`。
- 只读探针：`scripts/onsite-probe [输出路径]`（通过运行中应用的 `switchpilot://diagnose` 收集版本、签名、权限、登录项、断言、TCC 摘要；不授权/不锁屏/不改外观）。
- `--diagnose-runtime` 写 `/tmp/switchpilot-runtime-diagnose.txt`；应用运行中也可执行 `open "switchpilot://diagnose"`。`--diagnose-permissions` 写权限简表。
- TCC/屏幕状态项必须用户在场；未执行项不标记通过。

## 构建与运行

```sh
scripts/build-app
open app/SwitchPilot/.build/SwitchPilot.app
python3 scripts/verify-app.py    # 自动化验收（11 项）
```

### 安装到 Finder / 开机启动

开发构建在隐藏的 `.build/` 目录里，Finder 不好找。安装一份到 `~/Applications`：

```sh
scripts/install-app              # 构建并复制到 ~/Applications/SwitchPilot.app
open ~/Applications              # 在 Finder 中打开，双击 SwitchPilot.app
open -R ~/Applications/SwitchPilot.app   # 或在 Finder 中定位
```

- 之后从 Finder/Launchpad 打开 `SwitchPilot.app` 即可；登录时启动也建议从这份安装副本开启（位置稳定）。
- 重新构建后重新执行 `scripts/install-app`。本机使用自签名代码签名身份 **SwitchPilot Local Signing**（`scripts/build-app` 自动优先使用；身份不存在时回退 ad-hoc），其 designated requirement 为 `identifier + certificate leaf`，所以重建后 TCC 授权不再因 cdhash 变化而失效。签名私钥只在 Keychain 中，不进入 Git。
- 卸载：`scripts/uninstall-app`（TCC/登录项请在系统设置中手动移除）。

CLT 无 XCTest，使用独立 `SwitchPilotChecks` 可执行文件做真实断言与进度自检（14 项）；构建使用 `--build-system native` 回退，Swift 6.4 已提示该构建系统 deprecated。CLT + native SwiftPM 缺少 SwiftUI 宏插件，因此面板状态放在 PanelModel 而不是 `@State`/`@AppStorage`。

## 权限

应用启动时不弹权限框，只有你点击相关动作才会请求：

- **Automation（System Events）**：深色模式读写、锁屏按键注入。系统弹出提示时选择允许，或在“系统设置 › 隐私与安全性 › 自动化”中管理。
- **辅助功能（Accessibility）**：仅锁屏按键注入需要。在“系统设置 › 隐私与安全性 › 辅助功能”中勾选 SwitchPilot。

撤销权限后相关功能会显示缺失原因且不发送操作；应用不会修改 TCC 数据库、不关闭 SIP、不重签原应用。本机使用自签名身份 `SwitchPilot Local Signing`，重建/重装保持 TCC 匹配；bundle id 未变。登录时启动使用 SMAppService，可在设置中开启；需要批准时打开系统设置登录项。设置/图标已由用户 M8 简单测试通过；图标目视与注销/重启真实登录启动在收尾测试复看。

## 行为边界

- 保活只阻止“用户空闲导致的显示器休眠”，不阻止合盖、手动睡眠、低电量睡眠。
- 深色模式是系统持久设置，不会在退出时自动恢复。
- 屏保/锁定屏幕/关闭显示器/麦克风静音/屏幕清洁这些动作都按清晰标签直接执行；只有不可逆的应用内权限重置需要确认。v0.5.0 增加麦克风静音与屏幕清洁，移除输出音量；快捷键默认关闭且测试并入长期统一测试。
- 无网络、无后台定时动作、不修改原 One Switch 的 app/数据/偏好。
- 普通重复启动由 `LSMultipleInstancesProhibited` + 启动守卫限制为一个菜单栏图标；`open -n` 仅用于开发诊断（不纳入普通用户路径）；自动化冒烟用 `SWITCHPILOT_SMOKE_TEST=1` 绕过。
- 首次引导只记录“是否已看过”，不做其他持久化；设置窗口不做持久化（登录项状态由系统保存）。

## 卸载

删除 `app/SwitchPilot/.build/SwitchPilot.app` 即可。TCC 中残留条目可在系统设置中手动删除；本应用不写其他全局配置。
