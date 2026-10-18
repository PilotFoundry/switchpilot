# 能力矩阵与本轮决定

决定：**缩范围继续**。原版能够被 REA/Ghidra 分析；公开 API 的普通保活已独立实现并验证，深色模式还缺真实授权验证，Night Shift 暂不作为直接开关纳入首版。

| 能力 | 原行为证据 | 新实现 | 动态验证 | 结论 |
|---|---|---|---|---|
| 显示器保活 | 主程序 caffeinate -d、PID 等待、timer/terminate 调用链 | IOKit 公共 assertion | 4/4 自检组、5/5 进程用例；其中三轮真实开关 | 可进入产品候选 |
| 系统深色模式 | 编译脚本映射到 System Events；状态读取/通用脚本执行器 | 自写 AppleScript + 权限门控 | -600 后 -1744；未授权，读写/恢复未测 | 待授权闸门，不承诺通过 |
| Night Shift | XPC CoreBrightness / CBBlueLightClient | 未找到受支持公共控制 API | 未执行私有 setter | 首版不直接控制 |
| 合盖保活 | 单独的 PrivilegedHelper 协议线索 | 不实现 | 未测 | 与普通保活分开，首版排除 |

## 个人自用 v0.1 范围（2026-10-18 用户已确认）

目标：个人自用最小原生菜单栏面板；规格见 `docs/PRD.md`；实现 `app/SwitchPilot/`；运行验收 `evidence/app-runtime.md`。

| 功能 | v0.1 决策 | 原行为/系统证据 | 运行时状态 |
|---|---|---|---|
| 显示器保活 | 进入（P0） | 前轮 caffeinate 调用链 + 公开 IOKit 断言验证 | **已验证**：三层真实断言、定时释放、deinit/进程退出清理 |
| 系统深色模式 | 进入（P1，权限门控） | System Events `dark mode` 属性；前轮 −1744 闸门 | 应用完成门控；**待用户授予 Automation 后现场验收** |
| 启动屏保 | 进入（P2，动作 + 二次确认） | `EnableScreensaveSwitch` + `ScreenSaverEngine` 字符串；系统引擎存在（`evidence/features/screen-saver.md`） | 静态验证；**运行时未执行，待现场验收** |
| 锁定屏幕 | 进入（P3，权限门控 + 二次确认） | `LockScreenSwitch` + System Events Ctrl+Cmd+Q 脚本字符串（`evidence/features/lock-screen.md`） | 权限预检/拒绝路径已验证，**未发送按键，待现场验收** |

首版排除：Night Shift 直接控制、合盖保活、显示器休眠、输出/麦克风/音量/音频设备开关、快捷键/自启/场景组合、分发签名/公证/Sandbox。

## 工具选择

保留 REA + Ghidra。CLI/MCP 本地均已可用；MCP 的复用会话能避免逐命令重复导入。没有必要增加 Hopper：阻塞是权限和公开接口范围，而非当前伪代码不足。Cutter/RzGhidra 不作为独立反编译引擎复核。

## 下一轮候选，不是已批准的需求

供个人版筛选的 8 项：显示器保活、系统深色模式、输出静音、麦克风静音、音量调节、音频输出设备切换、启动屏幕保护程序、锁屏。2026-10-18 用户确认个人自用方向，选择其中四项（保活、深色模式、屏保、锁屏）作为 v0.1 候选并进入实现；其余四项仍在候选池、未批准，进入范围前需逐项核对公开入口、权限、设备与恢复。

四份文档已产出：`docs/PRD.md`、`docs/DESIGN.md`、`docs/TECH.md`、`docs/TESTPLAN.md`。保活已验证；深色模式仍以真实授权为验收门槛；屏保/锁屏已实现但运行时验收需要用户在场（见 TESTPLAN M1–M3）。

本轮不需要新增功能才能成立。场景组合、快捷键、自动规则可在核心能力可靠后再讨论。SwitchPilot 只是研究代号；独立产品可取新名，正式名称及商标/域名可用性本轮未决定或核验。

## 成本口径

本轮从样本清单时间到结果初稿的墙钟约 41.1 分钟（包含下载/编译/分析等待，不是人工工时，尚不含最终审阅）。这比原先预留的 10.5–22 工时少，是有界试验和部分动态验收未覆盖的结果，不能据此线性外推全量重写速度。

模型输入/输出/缓存 token、计费和人工时间均未知。会话记录显示两次 `usage_limit_exceeded` 中断（10:02、10:38 CST）；第二次中断发生在最终提交前，故结果报告初稿已生成而未提交，收尾由接手会话完成。用户授权“现有 Codex 重置卡用完为止”已记录为条件性偏好；重置卡是否被消耗本地无记录，本轮未新购额度。

前次个人版 6–8 项的 2–4 周 / 60–180 万累计 token 仅保留为低置信度规划区间，未被本轮计量校准。不能把它称为实际消耗或保证；正式范围明确后再按逐项验收拆估。近等价/分发版本不在当前承诺范围。

## 正式命名与 v0.2 UI/UX（2026-10-18）

- 正式名：**SwitchPilot**；候选冲突调研（Tack / Perch / Sill / Tact / Switchbar / Barkeep / MenuSwitch / OneBar / Flick / Switchlet 等已被占用）与设计依据见 `artifacts/20261018-1138-oneswitch-naming-ui-redesign.html`。
- 命名决定不更换 bundle id（`local.personal.SwitchPilot`），避免重置用户已授予的 TCC 授权；分发前的商标/域名检索未做。
- UI/UX v0.2：首次引导、状态胶囊、保活进度、权限行内化、动作磁贴、权限摘要；实现与自动验收见 `evidence/app-runtime.md`。运行时/TCC/视觉手测仍待用户（TESTPLAN M1–M3、M5、M7）。
