#!/usr/bin/env python3
"""SwitchPilot 独立防回归检查（只读、零外部依赖、可重复运行）。

设计约束（见 docs/en/CORE.md 与 TESTPLAN）：
- 只读源码与构建产物；不写仓库文件、不改 defaults/TCC/系统设置，不注册登录项，
  不锁屏/启动屏保/清洁模式/录音，不请求任何权限。
- 不构建、不启动常驻菜单栏应用；仅当已存在构建产物时，以 `--panel-size` 做一次
  离屏尺寸诊断（activation policy=prohibited，不显示 UI、不请求权限）。
- 不重复执行重测试：verify-app.py / SwitchPilotChecks 由执行者全量运行，本脚本只做
  静态护栏与跨脚本一致性断言，输出 PASS/FAIL/SKIP 摘要；有 FAIL 时退出码 1。
"""
import os
import plistlib
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PKG = ROOT / "app/SwitchPilot"
SOURCES = PKG / "Sources"
APP_BIN = PKG / ".build/SwitchPilot.app/Contents/MacOS/SwitchPilot"
FAILS = []
SKIPS = []


class Skip(Exception):
    """非失败：当前环境缺少前置条件（如未构建）。"""


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def read(relative):
    path = ROOT / relative
    require(path.is_file(), f"缺少文件：{relative}")
    return path.read_text(encoding="utf-8")


def read_bytes(relative):
    path = ROOT / relative
    require(path.is_file(), f"缺少文件：{relative}")
    return path.read_bytes()


def source_files():
    files = sorted(SOURCES.rglob("*.swift"))
    require(bool(files), "app/SwitchPilot/Sources 下没有 Swift 源码")
    return files


def find(pattern, files=None, flags=0):
    """返回 [相对路径:行号: 行内容]，只读匹配。"""
    regex = re.compile(pattern, flags)
    hits = []
    for path in files if files is not None else source_files():
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if regex.search(line):
                hits.append(f"{path.relative_to(ROOT)}:{number}: {line.strip()}")
    return hits


def check(name, function):
    try:
        detail = function() or ""
    except Skip as error:
        SKIPS.append(name)
        print(f"SKIP: {name} — {error}", flush=True)
    except Exception as error:  # noqa: BLE001 - 报告每一项失败
        FAILS.append(name)
        print(f"FAIL: {name} — {error}", flush=True)
    else:
        print(f"PASS: {name}" + (f" — {detail}" if detail else ""), flush=True)


# 1. CORE 边界文档存在且被项目约定引用（AGENTS/README）。
def core_doc():
    core = read("docs/en/CORE.md")
    for needle in ("open-source", "low-permission", "not planned", "Manual acceptance"):
        require(needle in core, f"docs/en/CORE.md is missing boundary text: {needle}")
    for ref in ("AGENTS.md", "README.md"):
        require("docs/en/CORE.md" in read(ref), f"{ref} does not reference docs/en/CORE.md")
    return "docs/en/CORE.md exists and is referenced by AGENTS/README"


# 2. 输出音量已移除（源码实现与 UI 文案都不得残留）。
def output_volume_removed():
    patterns = (
        r"AudioOutput", r"outputVolume", r"kAudioHardwarePropertyDefaultOutputDevice",
        r"kAudioDevicePropertyVolumeScalar", r"setOutputVolume", r"输出音量", r"音量",
    )
    hits = []
    for pattern in patterns:
        hits.extend(find(pattern, flags=re.IGNORECASE))
    require(not hits, "源码仍含输出音量实现/文案：" + "; ".join(hits[:3]))
    ui = read("app/SwitchPilot/Sources/SwitchPilot/PanelView.swift") + \
        read("app/SwitchPilot/Sources/SwitchPilot/SettingsView.swift")
    require("音量" not in ui, "面板/设置 UI 仍出现音量文案")
    return "源码与 UI 无输出音量残留"


# 3. 不引入私有框架/CoreBrightness/Night Shift 或高危私有 API。
def no_private_dependencies():
    patterns = (
        r"CoreBrightness", r"CBBlueLightClient", r"NightShift", r"night\s*shift",
        r"IOHIDEventSystemClient", r"SACLockScreenImmediate",
    )
    hits = []
    for pattern in patterns:
        hits.extend(find(pattern, flags=re.IGNORECASE))
    require(not hits, "出现私有 API 依赖：" + "; ".join(hits[:3]))
    return "无 CoreBrightness/NightShift/私有输入 API"


# 4. tccutil 只能是用户显式确认的高级路径，运行时不自动执行。
def tccutil_not_automatic():
    hits = find(r"tccutil")
    allowed = {"Permissions.swift", "SettingsView.swift", "SettingsModel.swift"}
    bad = [hit for hit in hits if Path(hit.split(":")[0]).name not in allowed]
    require(not bad, "tccutil 出现在非设置路径：" + "; ".join(bad[:3]))
    require(any("Permissions.swift" in hit for hit in hits), "缺少 Permissions 中的重置实现")
    for relative in ("app/SwitchPilot/Sources/SwitchPilot/main.swift",
                     "app/SwitchPilot/Sources/SwitchPilot/AppDelegate.swift"):
        text = read(relative)
        for needle in ("tccutil", "resetInAppPermissions", "requestAllPermissions",
                       "requestDarkModeAuthorization"):
            require(needle not in text, f"启动路径 {Path(relative).name} 出现 {needle}")
    call_sites = find(r"Permissions\.resetInAppPermissions\(\)")
    require(len(call_sites) == 1 and "SettingsModel.swift" in call_sites[0],
            f"重置调用点必须唯一且在 SettingsModel，实际：{call_sites}")
    permission_source = read("app/SwitchPilot/Sources/SwitchPilotCore/Permissions.swift")
    require("AppleEvents" in permission_source and "Accessibility" in permission_source,
            "应用内重置必须限定 AppleEvents + Accessibility 两项")
    all_source = "\n".join(path.read_text(encoding="utf-8") for path in source_files())
    require('"reset", "All"' not in all_source and '"reset", "all"' not in all_source,
            "禁止 reset All")
    require("/usr/bin/sudo" not in all_source, "禁止 sudo 提权")
    settings = read("app/SwitchPilot/Sources/SwitchPilot/SettingsView.swift")
    require("不可撤销" in settings and "hasDestructiveAction" in settings,
            "应用内重置缺少破坏性确认文案/样式")
    return "tccutil 仅用户确认路径，启动路径无自动重置"


# 5. 启动/刷新路径不主动请求权限、不自动写麦克风静音/清洁模式。
def no_automatic_state_changes():
    launch_files = ("app/SwitchPilot/Sources/SwitchPilot/main.swift",
                    "app/SwitchPilot/Sources/SwitchPilot/AppDelegate.swift")
    for relative in launch_files:
        text = read(relative)
        for needle in ("requestAllPermissions", "requestDarkModeAuthorization",
                       "requestAutomation", "resetInAppPermissions",
                       "startScreenCleaning"):
            require(needle not in text, f"启动路径 {Path(relative).name} 出现 {needle}")
    # 麦克风状态项/菜单动作允许在 AppDelegate 中出现，但只能作为用户点击入口；
    # 启动路径本身不得调用写入。
    require("@objc private func menuToggleMicrophone()" in app_delegate_text if (app_delegate_text := read("app/SwitchPilot/Sources/SwitchPilot/AppDelegate.swift")) else True,
            "麦克风菜单动作入口变化，请同步更新断言")
    # 快捷键回调只做接线，真正触发需用户按键（默认关闭由 hotkeys 检查覆盖）。
    app_delegate = read("app/SwitchPilot/Sources/SwitchPilot/AppDelegate.swift")
    require("hotKeys.onScreenSaver = { [weak model] in model?.startScreenSaver() }"
            in app_delegate, "快捷键回调接线变化，请同步更新本断言")
    model = read("app/SwitchPilot/Sources/SwitchPilot/PanelModel.swift")
    require("Microphone.read()" in model, "面板刷新应只读取麦克风状态")
    require("Microphone.setMuted(" not in model or (
        model.count("Microphone.setMuted(") == 1
        and "guard microphoneState.supportsMute" in model),
        "setMuted 只允许出现在显式 toggle 且先做能力判断")
    require("func toggleMicrophoneMute()" in model, "麦克风静音缺少显式 toggle 入口")
    require("Microphone.setMuted(target)" in model, "toggle 应基于读回状态写入")
    return "启动路径无主动权限请求/自动状态写入"


# 6. 麦克风静音：能力感知 + 状态可见 + 不支持时诚实降级。
def microphone_feature():
    microphone = read("app/SwitchPilot/Sources/SwitchPilotCore/Microphone.swift")
    for needle in ("kAudioDevicePropertyMute", "setMuted", "toggleMuted",
                   "当前输入设备不支持系统静音控制", "未找到默认输入设备"):
        require(needle in microphone, f"Microphone.swift 缺少：{needle}")
    panel = read("app/SwitchPilot/Sources/SwitchPilot/PanelView.swift")
    for needle in ("麦克风", "静音麦克风", "取消静音", "麦克风已静音", "accessibilityLabel"):
        require(needle in panel, f"面板缺少麦克风 UI：{needle}")
    return "能力感知/静音状态/不支持降级 UI 均在位"


# 7. 屏幕清洁：普通模式无倒计时/自动退出；键盘拦截、鼠标退出、测试门控。
def screen_cleaning_feature():
    manager = read("app/SwitchPilot/Sources/SwitchPilot/ScreenCleaningManager.swift")
    for needle in ("CGEventType.keyDown", "CGEventType.keyUp", "CGEventType.flagsChanged",
                   "屏幕清洁模式", "退出清洁模式", "键盘输入已暂停", "鼠标点击退出"):
        require(needle in manager, f"ScreenCleaningManager 缺少：{needle}")
    require("func start(duration: Int? = nil)" in manager, "普通模式启动不得带默认倒计时")
    require("showsCountdown = duration != nil" in manager, "倒计时必须仅由显式 duration 开启")
    require("if showsCountdown {\n" in manager and "Timer.scheduledTimer" in manager,
            "定时器必须仅在测试模式（showsCountdown）下创建")
    require("CGEventType.leftMouseDown" not in manager and "mouseMoved" not in manager,
            "清洁模式不得拦截鼠标事件（必须保留鼠标退出）")
    require("测试模式会在倒计时结束时自动退出" in manager, "测试模式说明缺失")
    model = read("app/SwitchPilot/Sources/SwitchPilot/PanelModel.swift")
    require('ProcessInfo.processInfo.environment["SWITCHPILOT_CLEAN_SCREEN_TEST_SECONDS"]' in model,
            "自动退出必须只由测试环境变量启用")
    require("screenCleaning.start(duration: testSeconds)" in model,
            "普通模式必须传 nil duration（由测试变量决定是否传值）")
    require("startScreenCleaning" in model and "清洁屏幕" in read(
        "app/SwitchPilot/Sources/SwitchPilot/PanelView.swift"), "缺少清洁模式 UI 入口")
    return "普通模式无倒计时/自动退出，键盘拦截与鼠标退出状态明确"


# 8. 快捷键：默认关闭（UserDefaults 缺省 false），仅显式设置才注册。
def hotkeys_default_off():
    hotkeys = read("app/SwitchPilot/Sources/SwitchPilot/HotKeyManager.swift")
    for needle in ('enabledDefaultsKey = "switchpilot.hotKeysEnabled"',
                   "UserDefaults.standard.bool(forKey: Self.enabledDefaultsKey)",
                   "func startIfEnabled()", "guard isEnabled else { return }"):
        require(needle in hotkeys, f"HotKeyManager 缺少：{needle}")
    for relative in ("app/SwitchPilot/Sources/SwitchPilot/main.swift",
                     "app/SwitchPilot/Sources/SwitchPilot/AppDelegate.swift"):
        require("set(true, forKey: Self.enabledDefaultsKey)" not in read(relative),
                f"{Path(relative).name} 不得在启动时开启快捷键")
    docs = read("docs/en/CORE.md") + read("docs/en/ROADMAP.md") + read("docs/TECH.md")
    require("disabled by default" in docs.lower(), "文档未声明快捷键默认关闭")
    return "快捷键默认关闭，仅显式设置后注册"


# 9. Info.plist / 图标 / 单实例 / URL scheme / 权限面。
def bundle_boundaries():
    info = plistlib.loads(read_bytes("app/SwitchPilot/Info.plist"))
    entitlements = plistlib.loads(read_bytes("app/SwitchPilot/Entitlements.plist"))
    require(info.get("CFBundleIdentifier") == "io.github.pengxianghao21.SwitchPilot", "bundle id changed")
    version = str(info.get("CFBundleShortVersionString") or "")
    require(re.fullmatch(r"\d+\.\d+\.\d+", version) is not None,
            f"版本不是语义化版本：{version!r}")
    require(info.get("LSUIElement") is True, "LSUIElement 必须为 true")
    require(info.get("LSMultipleInstancesProhibited") is True, "缺少单实例 key")
    require(info.get("CFBundleIconFile") == "AppIcon", "缺少 CFBundleIconFile=AppIcon")
    require(info.get("NSAppleEventsUsageDescription"), "缺少 Automation 用途说明")
    icon = PKG / "Resources/AppIcon.icns"
    require(icon.is_file() and icon.stat().st_size > 10_000, "缺少 AppIcon.icns 或文件过小")
    schemes = {scheme for entry in (info.get("CFBundleURLTypes") or [])
               for scheme in entry.get("CFBundleURLSchemes", [])}
    require("switchpilot" in schemes, "缺少 switchpilot:// URL scheme")
    usage = sorted(key for key in info if key.endswith("UsageDescription"))
    require(usage == ["NSAppleEventsUsageDescription"], f"新增权限用途声明：{usage}")
    require(sorted(entitlements) == ["com.apple.security.automation.apple-events"],
            f"entitlement 面变化：{sorted(entitlements)}")
    lint = subprocess.run(["/usr/bin/plutil", "-lint", str(PKG / "Info.plist")],
                          capture_output=True, text=True, timeout=30)
    require(lint.returncode == 0, f"plutil 失败：{lint.stderr.strip()}")
    return f"{version} / 单实例 / switchpilot scheme / 图标 / 仅 Automation 权限面"


# 10. 单实例守卫真实存在于启动路径（配合 plist key）。
def single_instance_guard():
    main = read("app/SwitchPilot/Sources/SwitchPilot/main.swift")
    require("func enforceSingleInstance()" in main, "缺少 enforceSingleInstance")
    require("SWITCHPILOT_SMOKE_TEST" in main, "冒烟测试需要绕过单实例的显式开关")
    require("MainActor.assumeIsolated { enforceSingleInstance() }" in main,
            "启动路径未调用单实例守卫")
    return "单实例守卫 + SMOKE_TEST 旁路均在启动路径"


# 11. 现有测试资产完整且规模不缩水（防止误删检查项）。
def test_harness_intact():
    verify = read("scripts/verify-app.py")
    checks_source = read("app/SwitchPilot/Sources/SwitchPilotChecks/main.swift")
    verify_count = len(re.findall(r'^check\("', verify, re.MULTILINE))
    core_count = len(re.findall(r'^    \("', checks_source, re.MULTILINE))
    require(verify_count >= 11, f"verify-app.py 检查项从 11 缩到 {verify_count}")
    require(core_count >= 14, f"SwitchPilotChecks 检查项从 14 缩到 {core_count}")
    for relative in ("scripts/check-contrast.py", "scripts/build-app"):
        require((ROOT / relative).is_file(), f"缺少 {relative}")
    for needle in ("check_contrast_tokens", "check_panel_sizes", "check_launch_smoke"):
        require(needle in verify, f"verify-app.py 缺少 {needle}")
    return f"verify-app {verify_count} 项、SwitchPilotChecks {core_count} 项、对比度/尺寸检查在位"


# 12. 对比度 token 仍全部 ≥ 4.5:1（复用现有只读脚本）。
def contrast_tokens():
    result = subprocess.run(["/usr/bin/python3", str(ROOT / "scripts/check-contrast.py")],
                            capture_output=True, text=True, timeout=60)
    require(result.returncode == 0, "对比度检查失败：" + result.stdout.strip()[-400:])
    return result.stdout.strip().splitlines()[-1]


# 13. 面板点击路径：材质必须 click-through，边框 overlay 不得吃点击，面板打开时激活 app。
def panel_click_path():
    controller = read("app/SwitchPilot/Sources/SwitchPilot/PanelWindowController.swift")
    panel_view = read("app/SwitchPilot/Sources/SwitchPilot/PanelView.swift")
    require("PassthroughVisualEffectView" in controller,
            "缺少 click-through material view")
    require("override func hitTest(_ point: NSPoint) -> NSView? { nil }" in controller,
            "material view 的 hitTest 必须返回 nil")
    require("materialView = PassthroughVisualEffectView()" in controller,
            "实际使用的不是 click-through material view")
    require("NSApp.activate(ignoringOtherApps: true)" in controller,
            "面板打开时必须激活 app，避免首次点击只激活窗口")
    require(".allowsHitTesting(false)" in panel_view,
            "边框 overlay 不得参与点击命中")
    settings = read("app/SwitchPilot/Sources/SwitchPilot/SettingsWindowController.swift")
    require("private final class SettingsWindow: NSWindow" in settings,
            "缺少处理 Cmd-W 的 SettingsWindow")
    require("override func performKeyEquivalent(with event: NSEvent) -> Bool" in settings,
            "SettingsWindow 缺少 performKeyEquivalent")
    require("charactersIgnoringModifiers?.lowercased() == \"w\"" in settings,
            "SettingsWindow 未匹配 Command-W")
    require("performClose(nil)" in settings,
            "SettingsWindow 未调用 performClose")
    require("addLocalMonitorForEvents(matching: .keyDown)" in settings,
            "Settings 窗口缺少 Command-W 事件监视回退")
    return "material click-through / border non-hit-testing / panel activation / settings Cmd-W"


# 14. 面板尺寸阈值（复用 --panel-size 离屏诊断，不显示 UI、不请求权限）。
def panel_size():
    if not APP_BIN.is_file():
        raise Skip("未找到构建产物；请先由执行者运行 scripts/verify-app.py")
    def measure(extra_env):
        env = dict(os.environ)
        env.update(extra_env)
        result = subprocess.run([str(APP_BIN), "--panel-size"], capture_output=True,
                                text=True, timeout=60, env=env)
        require(result.returncode == 0,
                f"--panel-size 失败：{result.stderr.strip()[:200]}")
        match = re.fullmatch(r"\s*(\d+)x(\d+)\s*", result.stdout)
        require(match, f"无法解析 --panel-size 输出：{result.stdout!r}")
        return int(match.group(1)), int(match.group(2))
    width, height = measure({"SWITCHPILOT_HIDE_GUIDE": "1"})
    require(width == 380 and height <= 840, f"无引导面板 {width}x{height}，期望 380x<=840")
    guide_width, guide_height = measure({"SWITCHPILOT_FORCE_GUIDE": "1"})
    require(guide_width == 380 and guide_height <= 840,
            f"带引导面板 {guide_width}x{guide_height}，期望 380x<=840")
    return f"无引导 {width}x{height}、带引导 {guide_width}x{guide_height}"


CHECKS = [
    ("CORE 边界文档", core_doc),
    ("输出音量已移除", output_volume_removed),
    ("无私有依赖", no_private_dependencies),
    ("tccutil 非自动执行", tccutil_not_automatic),
    ("启动路径无自动状态变更", no_automatic_state_changes),
    ("麦克风静音能力", microphone_feature),
    ("屏幕清洁边界", screen_cleaning_feature),
    ("快捷键默认关闭", hotkeys_default_off),
    ("bundle/权限边界", bundle_boundaries),
    ("单实例守卫", single_instance_guard),
    ("测试资产完整", test_harness_intact),
    ("面板点击路径", panel_click_path),
    ("对比度 token", contrast_tokens),
    ("面板尺寸阈值", panel_size),
]

print(f"SwitchPilot 独立防回归检查 — {ROOT}", flush=True)
for name, function in CHECKS:
    check(name, function)
passed = len(CHECKS) - len(FAILS) - len(SKIPS)
print(f"{passed}/{len(CHECKS)} checks passed"
      + (f", {len(SKIPS)} skipped" if SKIPS else "")
      + (f", {len(FAILS)} failed" if FAILS else ""), flush=True)
sys.exit(1 if FAILS else 0)
