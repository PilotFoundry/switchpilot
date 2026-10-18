# SwitchPilot（研究代号，非最终产品）

这个独立 Swift 原型验证公开 IOKit 显示器保活和 System Events 深色模式候选。使用 macOS 27 SDK 编译；无菜单栏 UI，不承诺完整 HIG/发布验收，不含 Night Shift 私有调用。

## 构建与自检

从仓库根目录执行：

```sh
scripts/build-pilot
swift run --package-path prototypes/SwitchPilot --build-system native PilotChecks
python3 scripts/verify-pilot.py
```

产物 `prototypes/SwitchPilot/.build/SwitchPilot.app`，独立 ID `local.research.SwitchPilot20261018`；ad-hoc Hardened Runtime 签名，仅个人本机试验。没有分发签名、公证或 Sandbox 适配声明。

CLT 缺少 XCTest；原始测试尝试保留在 Git 历史 6bf1ce7。当前使用标准库可执行自检，先看到 0/4 失败，再实现到 4/4 通过。`--build-system native` 是本机可用回退，Swift 6.4 已提示弃用；完整 Xcode 可用后需迁回默认构建/测试流程。

## 命令

```sh
prototypes/SwitchPilot/.build/SwitchPilot.app/Contents/MacOS/SwitchPilot awake 5
open -n -W prototypes/SwitchPilot/.build/SwitchPilot.app --args dark-probe
```

- `awake` 只允许 0 < 秒数 <= 60，保持显示器不因空闲休眠；正常返回主动释放，进程终止由系统回收。不阻止合盖或手动睡眠。
- `dark-probe` 只进行无弹窗授权探测，已有权限时读状态。System Events 尚未运行可能返回 -600；已运行但需授权时 -1744；被拒绝通常 -1743。当前实际测得前两项，未伪造拒绝授权测试。
- `dark-cycle` 代码包含三轮切换/读回/恢复，但本轮没有运行，因为身份尚无 Automation 授权。仅在明确获得授权、确认无其他工具/自动排程竞争且允许外观短暂切换的测试会话中使用。此命令无独立崩溃恢复日志，不用于日常自动化。

本原型不主动请求授权、不改 TCC 数据库。之后若需要授权流程，应显式设计用途说明、系统授权对话框和撤销测试；不能用更换 ID 逃避拒绝。`scripts/verify-pilot.py` 仅终止它自己启动的子进程，不杀原应用。

验收结果见 `evidence/runtime-cases.md`、`evidence/verification.md`；未测试项仍是缺口。
