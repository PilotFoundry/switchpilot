# 扩展开关/快捷键候选：本机只读 API 探测（2026-10-18）

- 环境：macOS 27.0.1 (26A434)，Apple Silicon；当前 SwitchPilot v0.3.9。
- 边界：本探测只读，未注册持久快捷键、未切换音频设备、未静音、未让显示器休眠、未修改 TCC/系统设置。临时 `RegisterEventHotKey` 在探测进程内注册后立即注销。

## 1. 全局快捷键（Carbon）

```swift
import Carbon
var ref: EventHotKeyRef?
let id = EventHotKeyID(signature: OSType(0x5350494C), id: 1)
let status = RegisterEventHotKey(UInt32(kVK_ANSI_K), UInt32(cmdKey | optionKey | controlKey), id, GetApplicationEventTarget(), 0, &ref)
// status = 0
UnregisterEventHotKey(ref) // status = 0
```

结论：`RegisterEventHotKey`/`UnregisterEventHotKey` 在本机返回 0；不需要 Accessibility 授权。仍需在实现时逐个组合做冲突检测（返回 `eventHotKeyExistsErr` 时显示冲突）。这是全局快捷键候选的可行性证据，不代表已批准实现。

## 2. CoreAudio 输出/输入设备能力（只读）

通过 `AudioObjectGetPropertyData` 读取默认输出与设备列表，并用 `AudioObjectHasProperty` 检查 `kAudioDevicePropertyMute` / `kAudioDevicePropertyVolumeScalar`（output/input scope）。

本机结果（sanitized）：

- 默认输出为外接显示器的音频设备；该设备 **不支持** mute/volume 属性（读取返回 unsupported）。
- 同一台机器上，内置扬声器、一个 USB 音频设备、一个外接麦克风等支持 mute/volume 属性。
- 输入侧同样存在设备差异：部分耳机麦克风不支持 mute/volume，内置/部分 USB 设备支持。
- 默认输出设备名与设备列表属于本机环境，不写入 Git 的原始日志；上面只保留能力分类。

结论：输出静音/音量、麦克风静音、输出设备切换都可用公开 CoreAudio API、无需 TCC；但**能力因设备而异**，必须做 capability detection、readback 和 unsupported 降级，不能承诺所有输出设备可静音。当前默认设备本身不支持 mute/volume，直接实现会在这台机器上先遇到 unsupported。

## 3. 显示器休眠（public CLI 文档）

`man pmset` 包含：

```
pmset [touch | sleepnow | displaysleepnow | boot]
displaysleepnow - causes display to go to sleep immediately.
```

结论：`pmset displaysleepnow` 是公开命令；但本轮**未执行**（会让显示器立即休眠）。若采用，应作为明确的快速动作并做失败/退出路径设计。

## 4. Night Shift（引用既有证据）

`evidence/features/night-shift.md` 已记录：原 app 依赖私有 `CoreBrightness` / `CBBlueLightClient`，macOS 27 公共 SDK 无 Night Shift 公开控制 API。结论仍是**不纳入**，除非用户接受私有接口维护风险另立目标。

## 5. 未评估/暂不纳入

- DND/Focus、Bluetooth/Wi-Fi、隐藏桌面图标、音量经由 System Events：依赖私有 API、额外 TCC 或 entitlement，未在本轮做实现评估。
- 场景组合/自动规则：超出“新开关或快捷键”的最小评估范围。
