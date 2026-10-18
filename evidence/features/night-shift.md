# Night Shift：私有 XPC 实现，首版暂不直接控制

One Switch 1.35.4 (440) 的 OneSwitchXPC arm64 slice SHA-256 `8c322a725b0c1838fc1f4fba9defc9a0d6cf5c1661fb403e1c8ca90ee5dec666`。REA 6.5.0 / Ghidra 12.1.4。所有地址是 XPC slice 的虚拟地址，不是主程序地址。

## 原实现事实

| 位置 | 证据 |
|---|---|
| Mach-O load command / otool -L | 链接 `/System/Library/PrivateFrameworks/CoreBrightness.framework/Versions/A/CoreBrightness` |
| nm undefined imports | `_OBJC_CLASS_$_CBBlueLightClient`、`_OBJC_CLASS_$_CBTrueToneClient` 来自 CoreBrightness |
| 0x1000012c4 → 0x1000012ec | 懒加载客户端路径，类引用与 ivar 指针经寄存器传递 |
| 0x100001350 | getNightShiftEnabledWithReply:；调用 getBlueLightStatus:，从结构偏移 1 读字节，与 1 比较再回调 |
| 0x1000014e0 | setNightShiftEnabled:；调用 client getter 后在 0x100001508 调用 setEnabled: stub (0x1000025c0) |
| 主程序 imports/selectors | 存在 nightShiftXPCConnection、getNightShiftEnabledWithReply:、setNightShiftEnabled:，功能与 XPC 边界相符 |

这是具体二进制调用证据，而非只根据功能名猜测。伪代码 receiver 恢复存在误差，需配合汇编及 class relocation 理解。结构布局属于此版本私有协议，不移植为公开产品约定。

## macOS 27 可支持性

本轮检索 Apple Developer Documentation 与本机 macOS 27.0 公共 SDK headers/Swift interfaces 的 Night Shift、nightShift、CBBlueLight：未找到公开控制 API。SDK 中 CoreBrightness 位于 PrivateFrameworks。该负面结论限定在上述检索面，不声称不存在任何内部机制。

因此不能以“已经能反编译”为由认定可稳定重写。私有接口也许在此机可调用，但系统升级、硬件适配与分发规则没有稳定保障；本轮不执行其 setter。

## 选择与后续

- **首版暂不支持直接开关 Night Shift**；可评估引导用户打开系统显示设置，但该入口及体验尚未实测。
- 不为此安装第二反编译器：现有证据已回答“依赖哪类机制”，更好的伪代码不会创造公开 API。
- 未测试此显示器的支持性、定时与日落日出策略、硬件切换，也未改当前 Night Shift 状态。
- 若后续把此功能定为必须项，需要另立目标：接受私有接口维护成本，或接受功能降级；不能默认纳入首版等价承诺。

官方文档入口：[Apple Developer macOS](https://developer.apple.com/macos/)。实际 SDK 与 Mach-O 路径是本轮私有/公开分类的主要可复核证据。

复核完成：0x1000012c4 的反编译直接指向 `___lazy_storage___blueLight` 与 `CBBlueLightClient` class relocation；0x1000012ec 在缺少对象时 alloc/init 并缓存。4/4 XPC 批查询成功。因此 setter 的真实接收者可通过 helper/汇编关联到 blueLight client，而非盲信 setter 伪代码的 param_1。
