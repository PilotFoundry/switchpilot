# SwitchPilot（个人自用 v0.1，研究代号）

原 One Switch 1.35.4 的个人自用最小菜单栏替代。**不是分发产品**，沿用研究代号 SwitchPilot；正式名称未决定。目标、面板与验收见 `docs/PRD.md`、`docs/DESIGN.md`、`docs/TECH.md`、`docs/TESTPLAN.md`。

## 当前状态

| 功能 | 实现状态 | 运行时验收 |
|---|---|---|
| 显示器保活（15/30/60 分钟、无限期） | 已完成 | ✅ 真实断言开关/读回/释放已验证（`evidence/app-runtime.md`） |
| 系统深色模式 | 已完成（权限门控） | ⏳ 需用户授予 Automation 后现场验证（`docs/TESTPLAN.md` M1） |
| 启动屏保 | 已完成（确认后执行） | ⏳ 静态验证；运行时需用户在场（M2） |
| 锁定屏幕 | 已完成（权限门控 + 确认） | ⏳ 需 Automation + Accessibility；未发送过按键（M3） |

已知排除项：Night Shift 直接控制、合盖不休眠、显示器休眠、输出/麦克风/音量类开关、私有 API、修改原应用、Terminal/后台自动控制。

## 构建与运行

```sh
scripts/build-app
open app/SwitchPilot/.build/SwitchPilot.app
python3 scripts/verify-app.py    # 自动化验收（8 项）
```

CLT 无 XCTest，使用独立 `SwitchPilotChecks` 可执行文件做真实断言自检；构建使用 `--build-system native` 回退，Swift 6.4 已提示该构建系统 deprecated。

## 权限

应用启动时不弹权限框，只有你点击相关动作才会请求：

- **Automation（System Events）**：深色模式读写、锁屏按键注入。系统弹出提示时选择允许，或在“系统设置 › 隐私与安全性 › 自动化”中管理。
- **辅助功能（Accessibility）**：仅锁屏按键注入需要。在“系统设置 › 隐私与安全性 › 辅助功能”中勾选 SwitchPilot。

撤销权限后相关功能会显示缺失原因且不发送操作；应用不会修改 TCC 数据库、不关闭 SIP、不重签原应用。ad-hoc 签名在重新构建后可能被系统视为新应用，需要重新授权（个人使用可接受）。

## 行为边界

- 保活只阻止“用户空闲导致的显示器休眠”，不阻止合盖、手动睡眠、低电量睡眠。
- 深色模式是系统持久设置，不会在退出时自动恢复。
- 屏保/锁屏会立即改变屏幕状态，执行前有确认对话框；可读回状态读不到时显示“未确认”。
- 无网络、无后台定时动作、不修改原 One Switch 的 app/数据/偏好。
- 单实例未强制：重复启动会出现多个菜单栏图标。

## 卸载

删除 `app/SwitchPilot/.build/SwitchPilot.app` 即可。TCC 中残留条目可在系统设置中手动删除；本应用不写其他全局配置。
