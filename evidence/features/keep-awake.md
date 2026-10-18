# 常规保活：原行为证据与独立实现候选

对象 One Switch 1.35.4 (440)，arm64 主程序 slice SHA-256 `0c3ba5c7a8f840d13114046283d2609e2bbd2762e69c359c85f5649c8f247528`。REA 6.5.0 + Ghidra 12.1.4；原始只读查询见 `evidence/raw/rea/main-awake-*.json`，其它自有进程 hash 见 `../slice-manifest.json`。

## 已证实的静态事实

| 位置 | 证据 | 限制 |
|---|---|---|
| ObjC metadata 0x1001cf140 | `KeepAwakeSwitch` 类；process 与 terminalCaffeinateTimer 成员 | 类名不单独证明行为 |
| 函数 0x1000366c8 | process 为空时获取 NSRunningApplication 的 processIdentifier，组装参数，调用 NSTask.launchedTaskWithLaunchPath:arguments: | Swift 伪代码的隐式 self 和 String 参数恢复有误，需结合汇编 |
| 0x100036758、0x100036768 | Swift small-string 常量分别是 `-d`、`-w `；后者追加 PID 字符串 | 不能将常量推断为已观测到的运行 argv |
| 0x1000367cc / 字符串 0x100208b80 | 路径为 `/usr/bin/caffeinate`，随后 0x1000367fc 启动 NSTask | 是外部命令创建断言，主程序未直接调用 IOPM create |
| 0x10003566c | 开关处理先调用 timer 清理函数，再 terminate 旧进程并清空引用；参数为 1 时重建 caffeinate 并调用 0x100035fe8 | 不是运行时捕获；不承诺所有异常路径都正确 |
| 0x100035f44、0x100035fe8 | 清理函数 invalidate timer、清空引用及持久化截止值；调度函数创建 NSTimer 并加入 NSRunLoopCommonModes、保存 fireDate | 完整异常/唤醒语义仍未验证 |
| 0x100035ce4 / 0x100035e40 | 读取持久化截止时间；未来截止值会重新调度 timer 并发布状态更新 | 回调最终动作另需确认 |

入口调用者包括 0x100034c28、0x1000351fc、0x10003566c、0x1000390b0；不把入口发现当成全调用图覆盖。

## 进程分工与退出

- 常规分支：主程序 → NSTask → `/usr/bin/caffeinate` → 电源断言。
- 本机 `man caffeinate` 明确 `-d` 阻止显示器空闲睡眠，`-w pid` 等待目标进程结束并释放断言。由此推断原实现有跟随主进程退出的设计意图；本轮未杀原 One Switch 验证此行为。
- 主程序额外分支 0x1000358e0 与偏好有关。PrivilegedHelper 的协议暴露 `disableSleepWhenClosingLidWithCompletion:` / `enableSleepWhenClosingLidWithCompletion:`。这属于“合盖也不睡眠”的另一能力，不能与普通保活混为一谈。
- 扫描了 main、LoginItem、OneSwitchXPC、PrivilegedHelper 自有二进制的 imports/strings；本轮只对普通分支追到 caffeinate，不声称所有 helper 路径都已反编译。Night Shift 另经 XPC。

## 独立原型规格

选择公开 IOKit power assertion，自主编写而非翻译以上伪代码：

1. 为匹配原版 `-d` 的普通表现，创建 `kIOPMAssertPreventUserIdleDisplaySleep`（保持屏幕常亮）。它不是阻止合盖/手动睡眠的能力。
2. 只有 Create 返回成功且按 ID 读回有效属性时显示开启；失败返回真实错误。
3. 关闭释放本进程持有的 ID；重复开/关不得叠加或重复释放。定时结束、主动退出均释放；强退依赖系统回收并实际检验。
4. 不改 pmset 全局偏好，不装特权 helper，不阻止合盖。若产品只要系统空闲保活而允许屏幕休眠，应另选 `kIOPMAssertPreventUserIdleSystemSleep`，不要混用名称。
5. 最小原型先限定短时运行，三次开/关/状态读回；额外检查超时、正常退出、SIGTERM、SIGKILL 后无本原型断言残留。

## 公共接口依据

本机 macOS 27.0 公共 SDK `IOKit.framework/Headers/pwr_mgt/IOPMLib.h`：275–314（system/display 断言和合盖边界）、648–681（Release/CopyProperties）、757–781（CreateWithName 不要求特殊权限）。[Apple IOPM assertion keys](https://developer.apple.com/documentation/iokit/iopmlib_h/iopmassertiondictionarykeys)。

结论：**可用公开 API 独立实现普通保活；原程序的完整定时/异常行为不视为已动态复现。** 运行证据将在步骤 5 单列。原版合盖功能不纳入原型。

批查询补证：`tooling/main-queries.json` 经同一本地 MCP 进程复用导入，6/6 指定函数得到伪代码，主程序 list_procedures 返回 12,543 项（含 external/thunk）。初次 timer 查询地址 0x100035cf0 被工具解析为所属函数入口 0x100035ce4，重现清单改用明确入口。未知项：原版强退恢复未动态测试、定时参数全部枚举及跨睡眠行为未验证。

补齐 timer 回调：调度闭包 0x100039778 转入 0x1000365ac；REA 反编译显示 terminate process、清空引用、state=0、发送 needsStateUpdateSubject、将 kEnableKeepAwakeKey 写 false。至此定时结束的静态路径已追到关闭动作；这不替代跨睡眠/崩溃运行测试。
