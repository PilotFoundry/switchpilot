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

## v0.2 正式命名与面板重设计验收（2026-10-18）

- 正式名 SwitchPilot 确定；bundle id 保持 `local.personal.SwitchPilot` 以减少迁移；ad-hoc 重建后 TCC 仍可能要求重新授权。命名依据见 `artifacts/20261018-1138-oneswitch-naming-ui-redesign.html`。
- 面板重写：状态胶囊、首次引导卡（`UserDefaults("switchpilot.hasSeenWelcome")`）、保活进度条、外观/锁屏权限行内入口、动作磁贴、权限摘要 footer。
- `SwitchPilotChecks` 扩为 **10/10**：新增“限时进度 / 无限期无进度”检查。
- `python3 scripts/verify-app.py`：**8/8 通过**（构建、plists、ad-hoc Hardened Runtime 签名、自检 10/10、启动冒烟、无新增残留进程、原应用不变、脚本语法）。
- v0.2.0 可执行文件 SHA-256 `f3185f00fc8185aad1008a60c809028df10f4832677c1a6d05da3f7685ea76a7`，CDHash `01e7ecb48834f4b7981a44800bfcae413ce94f9d`。
- 用户 2026-10-18 口头确认 v0.1 初步验收可行（未提供逐项清单；不据此把 M1–M3 记为已通过）。v0.2 的新面板/引导交互验收（TESTPLAN M7）仍待用户手动确认。
- 本轮自动化同样未请求 TCC、未启动屏保、未发送锁屏按键、未切换系统外观。

## v0.3 反馈修复与独立评审验收（2026-10-18）

- 版本 **0.3.0**；应用图标 `Contents/Resources/AppIcon.icns`（1024 画布/824 内容/16–1024 全套）+ `CFBundleIconFile=AppIcon`；菜单栏为自绘 S monogram template 图标。
- 面板：单一不透明表面；新增 `secondaryInk`；权限 CTA 按缺失项分支；首启引导可"申请全部权限"；引导可见时隐藏重复 callout；面板逻辑尺寸 **380×672（无 guide）/380×710（guide）**。
- 设置窗口：权限（申请全部/重新检查/辅助功能提示/系统设置深链/撤销说明）、登录时启动（SMAppService）、关于；状态项右键菜单（设置/使用说明/退出）。应用内**不调用** tccutil reset（研究结论见报告 §05）。
- 登录项实测（`evidence/raw/app/login-item-test.log`）：初始 `notFound` → `register()` 后 `enabled` → `unregister()` 后 `notRegistered`；未验证登录后真实启动。
- `SwitchPilotChecks`：**12/12**；`scripts/verify-app.py`：**11/11**（新增对比度、面板尺寸、语义色静态检查；应用图标检查）。
- 对比度（`scripts/check-contrast.py`）：secondaryInk 浅色最差 5.15:1、深色最差 6.04:1；warning/success/error ink 浅色最差 5.50/5.99/6.03:1；全部 ≥4.5:1。
- 应用身份：可执行 SHA-256 `71a3db8f22117729cf5a6a022e808a161e12ee7cc9b7615834474a32da0e9b1d`，CDHash `322f452f00381553ef09afa69edfe7f2262f8ddc`。
- 独立评审（`evidence/reviews/`）：UI P0×1/P1×6、UX P0×4/P1×8、QA 基线 8/8+10/10；v0.3 已修主要 P0/P1，评审报告注明"修复后未复评"，真机 TCC/登录/图标/菜单栏三态仍未验证。
- 用户 2026-10-18 同意 SwitchPilot 转正；此前 v0.1 初步验收为口头确认，未逐项记录。

## v0.3.1 修复（2026-10-18）

- 修复：从设置页打开系统设置（自动化/辅助功能）后，返回或关闭系统设置窗口时，SwitchPilot 设置窗口会重新前置/保持可用；`SettingsWindowController` 设置 `hidesOnDeactivate=false` 并在应用重新激活时按标记重新 present；设置页打开系统设置前登记回调。权限仍需在系统设置中手动授予/确认，应用不代授。
- 新增 `scripts/install-app` / `scripts/uninstall-app`：构建后复制到 `~/Applications/SwitchPilot.app` 并注册 LaunchServices，便于 Finder/Launchpad 启动与稳定路径下的登录项；不修改 TCC/登录项。
- 版本 0.3.1；自动化 11/11、自检 12/12 复跑通过。
