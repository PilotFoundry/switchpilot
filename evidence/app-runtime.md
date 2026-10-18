# 个人自用 v0.1 应用运行验收

日期：2026-10-18。对象：`app/SwitchPilot/.build/SwitchPilot.app`（bundle id `local.personal.SwitchPilot`，ad-hoc Hardened Runtime）。规格：`docs/PRD.md`、`docs/TECH.md`、`docs/TESTPLAN.md`。原始日志：`evidence/raw/app/`（不入 Git）。

## 构建产物

| 项目 | 值 |
|---|---|
| 应用可执行文件 SHA-256 | `238524889cbe3f1949b05bb0191935618b340c7da178cd6757bd90de6e7fa5b3` |
| CDHash | `19e82d8cfb38560c9d88c19297356363ef98baa3` |
| 签名 | ad-hoc，CodeDirectory flags `0x10002(adhoc,runtime)`，Info.plist entries=10 |
| Runtime | 27.0.0；目标 arm64-apple-macosx27.0.0 |
| 构建工具 | CLT Swift 6.4（swift-driver 1.168.6），`--build-system native`；无完整 Xcode |

## 自动化验收结果

`python3 scripts/verify-app.py`：**8/8 通过**（2026-10-18 11:23 CST）。

| 检查 | 结果 |
|---|---|
| 构建（`scripts/build-app`） | 通过；输出 `.app` 路径 |
| plist（LSUIElement / usage description / automation entitlement / plutil） | 通过 |
| ad-hoc Hardened Runtime 签名（`codesign --verify --strict`） | 通过 |
| 核心自检 `SwitchPilotChecks` | **9/9 通过** |
| 启动冒烟（进程存活 ≥2s，SIGTERM 退出） | 通过 |
| 退出后无 `SwitchPilot` 电源断言 / 无残留进程 | 通过 |
| 原应用版本/hash/签名不变 | 通过（1.35.4，主程序 `ee4551f9…`，`codesign --verify --strict`） |
| Python/shell 语法检查 | 通过 |

`SwitchPilotChecks` 的 9 项：

1. 预设时长映射（15/30/60/无限期）；
2. 非正数/NaN/∞ 时长拒绝；
3. Automation 状态码映射（0/−1743/−1744/−600/未知）；
4. 三轮真实 IOPM 断言创建、读回、幂等 start、释放；
5. owner deinit 释放真实断言；
6. 定时会话到时自动释放（真实 OS 断言消失）；
7. 深色模式全局外观只读（当前 light）；
8. 屏保引擎可解析（`/System/Library/CoreServices/ScreenSaverEngine.app`）；
9. 未授予 Automation + Accessibility 时 `LockScreen.lock()` 抛权限错误且**未发送按键**。

## 权限预检与未执行动作

- 应用身份下预检：Automation `-600`（System Events 未运行，不能解释为拒绝）；Accessibility 未授权。
- 本轮自动化**没有**发送锁屏按键、没有启动屏保、没有切换深色模式、没有请求 TCC 授权、没有修改 TCC 数据库/系统设置。
- 启动冒烟未观察到本应用创建保活断言；退出后 `pmset -g assertions` 无本应用记录。

## 仍未验证（需用户在场，见 `docs/TESTPLAN.md` M1–M6）

- M1 深色模式真实授权、切换、读回、拒绝/撤销；
- M2 屏保真实启动与退出；
- M3 锁屏权限授予、锁定与解锁、读回；
- M4 睡眠/唤醒、合盖、长时间稳定性；强退清理仅自动化到 SIGTERM 冒烟，未做真实开关后强退的完整组合；
- M5 菜单栏图标/面板视觉、键盘、VoiceOver、深浅外观；
- M6 多实例、权限撤销后行为、卸载残留。

这些项目不得在 README/能力矩阵中记为通过。

## 成本记录

- 从 2026-10-18 11:14:46 开始读到 11:23:43 完成自动化验收，墙钟约 **8 分 57 秒**（含重复构建/启动冒烟；不含文档写作与最终审阅）。
- token、缓存、计费与人工工时：未知（无权威计量），不以估算冒充实测。
- 本轮未触发 GPT 限额；未使用新的重置卡/额度。
