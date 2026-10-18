# 原型动态验证记录

2026-10-18，macOS 27.0.1 (26A434)，Apple Silicon；CLT Swift 6.4 / SDK27.0。独立 ad-hoc app ID `local.research.SwitchPilot20261018`。原始结果在忽略目录 `evidence/raw/runtime/`。

## 前置状态与恢复

- 原 One Switch 的四个窄范围偏好读回：dark-mode-enable-auto-schedule=0、dark-mode-switch-type=1、kEnableKeepAwake=0、keep-awake-turn-off-date=0。它们不代表完整原版配置或系统自动外观状态。
- 开始前 pmset assertions 未发现本原型或 caffeinate/One Switch 的保活记录。原型 assertion 名称固定为 `SwitchPilot bounded research`，外部检查按自己启动的 PID 关联。
- 无修改 pmset 偏好；结束时确认本原型断言清空。未执行任何深色模式 setter，故无需恢复外观。
- 为消除 -600，启动了系统自带 System Events 后再次检查；未改其偏好或授权数据库。没有关闭该系统服务，避免干扰其他系统功能。

## 实测结果

| 用例 | 结果 | 证据 |
|---|---|---|
| 初版自检验证失败 | 预期失败 0/4 | checks-red.log：无功能的 stub 不能通过时长、权限、断言生命周期检查 |
| 非法时长 | 通过 | 0、负数、>60、NaN、infinity、非数字均拒绝；0.1 和 60 接受 |
| 权限 guard | 通过（合成输入） | -1743、-1744、-600 均抛原始状态；不是 TCC 实际拒绝测试 |
| 同进程开关/读回 | 3 轮通过 | IOPMAssertionCopyProperties 确认 type=PreventUserIdleDisplaySleep、level=255；停止后该 ID 消失 |
| 重复开/关、owner deinit | 通过 | 重复 start 保持同一 ID；stop 幂等；deinit 后 OS 不再有该 ID |
| 独立进程 2 秒定时 | 3 轮通过 | 输出 active=true；pmset 关联同 PID；主动 release 后 active=false，子进程退出 0、无残留 |
| SIGTERM | 通过 | 只终止本脚本启动的子进程；exit=-15，系统回收断言 |
| SIGKILL | 通过 | 只强退本脚本启动的子进程；exit=-9，系统回收断言 |
| 深色首次探测 | 被阻挡 -600 | System Events 当时不可用；不能解释为授权拒绝 |
| 启动 System Events 后探测 | 被阻挡 -1744 | askUserIfNeeded=false，表示需要授权，未弹窗/未切换 |
| 实际授权允许/拒绝/撤销 | 未验证 | 未请求或重置 TCC；合成状态测试不算替代 |
| 深色三轮切换与恢复 | 未验证 | 代码候选已构建，但身份无授权；0 次 setter 执行 |
| 睡眠/唤醒、合盖、重启 | 未验证 | 不打断当前工作；普通保活不承诺阻止这些睡眠原因 |
| Night Shift、硬件切换 | 未验证 / 不支持原型 | 没有公开控制接口候选，不执行私有 setter |

合计：4/4 可执行自检组通过（包含真实三轮断言），5/5 进程用例通过。它们不是 9 个完整产品功能，也不表示深色模式已通过。
