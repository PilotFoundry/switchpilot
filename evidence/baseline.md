# 样本与环境基线

2026-10-18，步骤 1 完成。来源为本机已安装应用，指定 ZIP 仍不存在。研究对象：One Switch 1.35.4 (440)，bundle ID `studio.fireball.OneSwitch`。

## 样本完整性

- 原包 `/Applications/One Switch.app`；通过 `ditto` 建立 `samples/One Switch.app`。
- 递归清点 305 条：293 个普通文件、12 个符号链接；11 个 Mach-O 文件，均为 x86_64 + arm64。
- 每个普通文件 SHA-256、大小及符号链接目标见 [binary-manifest.json](binary-manifest.json)。不是原始程序或反编译源码。
- 复制前、复制后原包及副本逐条相等；两份 `codesign --verify --deep --strict --verbose=2` 均退出 0。
- 清单是文件内容及链接层面的相等，不声称逐项比较全部扩展属性；签名验证另行通过。

| 自有可执行文件 | SHA-256（完整通用文件） | 架构 |
|---|---|---|
| `Contents/Library/LaunchServices/studio.fireball.OneSwitch.PrivilegedHelper` | `05eec224f475c47b5d7660af7258c963edef9c8ab344c06f72579aa605f0deab` | x86_64 arm64 |
| `Contents/Library/LoginItems/OneSwitchHelper.app/Contents/MacOS/OneSwitchHelper` | `7bc5b2002aad142fc7fa19ae0136dcba5adc6287323cf8cfda1385c7e06bdeec` | x86_64 arm64 |
| `Contents/MacOS/One Switch` | `ee4551f90014801f0252abea9787911a8ce04e9e6bae1207589eebf1584208fa` | x86_64 arm64 |
| `Contents/XPCServices/OneSwitchXPC.xpc/Contents/MacOS/OneSwitchXPC` | `e561f0902dd28ac8c6bc5577905a9d8e736d7d49b117841ced8314b6bb49a646` | x86_64 arm64 |

## 环境实测

| 项目 | 结果 |
|---|---|
| 系统 | macOS 27.0.1 (26A434)，arm64 |
| Node | 24.12.0 |
| Java | 实际启动 OpenJDK 19.0.2；另注册 JDK 11、8；不满足现代 Ghidra 所需版本时局部安装 |
| Xcode | 27.0 (27A266a)；单次 DEVELOPER_DIR 的 SDK 查询退出 69：许可未接受 |
| CLT | 全局选择 `/Library/Developer/CommandLineTools`，保持原样 |
| Swift | 命令行可启动 Swift 6.4，目标 arm64-apple-macosx27.0.0；尚未据此声称应用构建成功 |
| REA / Ghidra | 开始时 PATH 未发现；未做全盘安装审计 |

## 复核命令与边界

```sh
sw_vers
node --version
java -version
/usr/libexec/java_home -V
xcode-select -p
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -version
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun --show-sdk-version
swift --version
codesign --verify --deep --strict '/Applications/One Switch.app'
codesign --verify --deep --strict 'samples/One Switch.app'
shasum -a 256 '/Applications/One Switch.app/Contents/MacOS/One Switch'
lipo -archs 'samples/One Switch.app/Contents/MacOS/One Switch'
```

原始命令结果在忽略目录 `evidence/raw/baseline/`。未启动研究副本、未改原包/许可证/用户数据，未改变全局 Xcode 选择，未代为接受许可。后续仅分析 arm64 切片，记录切片自己的 hash；不能与本表通用文件 hash 混用。

校正记录：初稿将前次文件数误当作本轮计数；提交前数量断言失败，但 shell 未启用 errexit 导致提交继续。当前依本轮清单重新计数修正，后续命令显式启用 set -e。内容相等和签名检查不受此计数错误影响。
