# 验证与已知缺口

## 已完成的检查

- 工具包发布 SHA-256 匹配，REA provider scoped doctor healthy；复导入同函数的地址/汇编/伪代码相同。
- Main 6/6 + 3/3、XPC 4/4 批反编译有结果；检查失败计数，不以 RPC 无错误替代功能成功。
- Swift 自检先以 stub 得到 0/4，再实现到 4/4；真实 OS assertion 类型、级别、释放与 deinit 都检查。
- `scripts/build-pilot` 构建成功；独立 ad-hoc app codesign --verify --strict 通过；两份 plist 通过 plutil -lint。
- `python3 scripts/verify-pilot.py`：5/5 真实进程用例通过。结束时 pmset 未发现本原型断言。
- Python py_compile、shell sh -n、git diff --check 通过；没有独立 lint 配置，不声称跑过不存在的静态分析器。
- 原应用与研究副本的 293 个已记录文件 SHA-256、12 个链接目标仍匹配基线；两份 deep/strict 签名仍通过。四个所读原版偏好前后相同。

## 明确保留的缺口

- 完整 Xcode SDK 使用仍需要许可；没有代为接受。XCTest 模块在当前 CLT 不可用。
- Native SwiftPM 回退提示 deprecated；未来 SDK 需切换受支持构建流程。不是零警告构建。
- 深色模式只有未运行目标 -600 / 需授权 -1744 的真实门控结果；未验证授权后的读写、恢复、拒绝与撤销。
- 研究代号和 app bundle 不等于产品 UI；没有菜单栏设计、VoiceOver/键盘/对比度、Liquid Glass、分发签名、公证、Sandbox 适配测试。
- 未对原版运行调试、杀进程或做行为等价对照。原始源码未恢复；Swift 伪代码存在参数/receiver 恢复误差。
- 未做跨睡眠、合盖、设备切换、重启、长时间稳定性测试。合盖保活和 Night Shift 不在候选原型能力内。
- Token 输入/输出/缓存及人工工时没有可信计量来源，均未知。未遇到模型限额，没有使用重置卡。
