# One Switch / REA 个人自用替代

本仓库保留调研、可复现分析、独立原型与个人自用应用的 Git 历史。前一轮 REA/Ghidra 可行性试验已完成（结论：缩范围继续）；当前里程碑是**个人自用 v0.1 菜单栏应用**（研究代号 SwitchPilot，正式名称未决定）。

- 应用：[app/SwitchPilot](app/SwitchPilot/README.md)（菜单栏面板；保活已验证，深色模式/屏保/锁屏权限门控与现场验收状态见文档）
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
open app/SwitchPilot/.build/SwitchPilot.app
python3 scripts/verify-app.py
```

当前状态：保活已通过自动化验收；深色模式、屏保、锁屏已完成实现但需要用户在场完成 TCC 授权/屏幕状态相关的手动验收（`docs/TESTPLAN.md` M1–M3），未执行项不记为通过。Night Shift 直接控制、合盖保活、显示器休眠等首版排除。

原应用、分析数据库、工具和原始日志不入库。已安装工具与样本在保留的独立工作区 `/Users/pengxianghao/.codex/worktrees/97ec/oneswitch-rea`；应用构建只需要 CLT，不依赖该工作区。仅本地 Git，尚未配置远端备份。
