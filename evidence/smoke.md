# REA/Ghidra 冒烟验证

2026-10-18；REA 6.5.0 / Ghidra 12.1.4 / arm64 JDK 21.0.12.1；输入 slice SHA-256 `8c322a725b0c1838fc1f4fba9defc9a0d6cf5c1661fb403e1c8ca90ee5dec666`，映射见 `slice-manifest.json`。

## 已验证

- `scripts/rea doctor --provider ghidra --format json`：所选 provider healthy=true，全部 9 项 scope checks 通过。
- `scripts/rea inspect analysis/slices/OneSwitchXPC.arm64 --provider ghidra --format json`：image base 0x100000000，38 segments，123 procedures，600 strings。
- `scripts/rea function analysis/slices/OneSwitchXPC.arm64 --procedure=0x1000014e0 --provider ghidra --format json`：函数名 `_TtC12OneSwitchXPC12OneSwitchXPC::setNightShiftEnabled:`；body 0x1000014e0–0x100001527，72 bytes；汇编与伪代码均非空。
- 调用目标列表包括 0x1000012c4、0x1000025c0 `objc_stub::setEnabled:`，及 objc retain/release thunks；XPC nm 导入列表确认 CBBlueLightClient 来源 CoreBrightness。完整原始结果仅在 `evidence/raw/rea/`。
- 退出后独立第二次导入：函数地址、全部汇编行、伪代码文本均完全一致（assert 验证）。REA 临时项目自动删除，不能宣称已经完成持久 .gpr reopen。
- 首次 XPC function 实测 wall 48.80 秒；主程序保活 function 实测 wall 135.10 秒。两者均包含导入/分析/启动，不等于纯反编译耗时。

## 质量边界

伪代码对 Swift 隐式 self、寄存器传参和 ObjC receiver 的恢复不完全。XPC setter 的伪代码会把接收者显示成 param_1；必须连看 helper 与汇编，不能当成可编译源码。REA 提供可定位证据，不提供原工程恢复。

初次摘要脚本误取 inspect.raw_result.value（此操作 raw_result=null），出现 TypeError；改读取 normalized_result 后计数检查通过。不是 Ghidra 导入或反编译失败。
