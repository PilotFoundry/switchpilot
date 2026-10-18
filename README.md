# SwitchPilot / One Switch 个人自用替代

本仓库保留调研、可复现分析、独立原型与个人自用应用的 Git 历史。前一轮 REA/Ghidra 可行性试验已完成（结论：缩范围继续）；当前是**个人自用 SwitchPilot v0.3**：正式名经用户同意转正；面板按 macOS 27 方向重设计，加入首启全部授权、设置窗口、登录时启动、应用/菜单栏图标与对比度修复；并引入独立 UI/UX/QA 评审。

- 应用：[app/SwitchPilot](app/SwitchPilot/README.md)（菜单栏面板；保活已验证，深色模式/屏保/锁屏权限门控与现场验收状态见文档）
- v0.3 反馈修复与独立评审：[artifacts/20261018-1210-oneswitch-v03-feedback-review.html](artifacts/20261018-1210-oneswitch-v03-feedback-review.html)
- 命名与 UI/UX 设计（v0.2）：[artifacts/20261018-1138-oneswitch-naming-ui-redesign.html](artifacts/20261018-1138-oneswitch-naming-ui-redesign.html)
- 独立评审：[UI](evidence/reviews/ui-review.md) · [UX](evidence/reviews/ux-review.md) · [QA 基线](evidence/reviews/qa-baseline.md)
- 规格：[docs/PRD.md](docs/PRD.md) · [docs/DESIGN.md](docs/DESIGN.md) · [docs/TECH.md](docs/TECH.md) · [docs/TESTPLAN.md](docs/TESTPLAN.md)
- 运行验收：[evidence/app-runtime.md](evidence/app-runtime.md)
- 能力矩阵：[evidence/capability-matrix.md](evidence/capability-matrix.md) · 验证与缺口：[evidence/verification.md](evidence/verification.md)
- 交接核验：[artifacts/20261018-1110-oneswitch-codex-handoff.html](artifacts/20261018-1110-oneswitch-codex-handoff.html)
- 可行性试验结果：[artifacts/20261018-1034-oneswitch-pilot-results.html](artifacts/20261018-1034-oneswitch-pilot-results.html)
- 执行计划（已完成）：[.omx/plans/2026-10-18-oneswitch-pilot.md](.omx/plans/2026-10-18-oneswitch-pilot.md) · [HTML 读者版](artifacts/20261018-0941-oneswitch-execution-plan.html)
- 工具复现：[evidence/toolchain.md](evidence/toolchain.md) · 研究原型：[prototypes/SwitchPilot/README.md](prototypes/SwitchPilot/README.md)

构建与验收：

```sh
scripts/build-app
python3 scripts/verify-app.py
scripts/install-app        # 复制到 ~/Applications/SwitchPilot.app，便于 Finder 启动
open ~/Applications
```

当前状态（v0.3.1）：保活已通过自动化验收；首启/设置权限流程、登录时启动、应用/菜单栏图标、对比度与按钮可见性已实现并自动验收（11/11）。TCC 允许/拒绝/撤销、真实登录启动、系统 UI 图标显示、睡眠唤醒、VoiceOver 与真机布局仍需用户现场（`docs/TESTPLAN.md` M1–M3、M5、M7、M8）。用户 2026-10-18 同意 SwitchPilot 转正，并口头确认 v0.1 初步验收可行（未逐项记录）。Night Shift 直接控制、合盖保活、显示器休眠等首版排除。

命名：正式名 **SwitchPilot**，中文描述「菜单栏开关」；bundle id 保持 `local.personal.SwitchPilot` 以减少迁移；ad-hoc 重建后 TCC 仍可能要求重新授权。分发前的商标/域名检索未做。

原应用、分析数据库、工具和原始日志不入库。已安装工具与样本在保留的独立工作区 `/Users/pengxianghao/.codex/worktrees/97ec/oneswitch-rea`；应用构建只需要 CLT，不依赖该工作区。仅本地 Git，尚未配置远端备份。
