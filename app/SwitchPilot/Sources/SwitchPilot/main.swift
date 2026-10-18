import AppKit
import SwiftUI
import SwitchPilotCore

@MainActor
func dumpPanel() -> Int32 {
    // Development aid: render the SwiftUI panel offscreen so layout/contrast can
    // be reviewed without Screen Recording permission. Never used by normal runs.
    let application = NSApplication.shared
    application.setActivationPolicy(.prohibited)
    let model = PanelModel()
    if ProcessInfo.processInfo.environment["SWITCHPILOT_HIDE_GUIDE"] != nil {
        model.hideGuideForPreview()
    }
    if ProcessInfo.processInfo.environment["SWITCHPILOT_FORCE_GUIDE"] != nil {
        model.forceGuideForPreview()
    }
    let dumpHeight = ProcessInfo.processInfo.environment["SWITCHPILOT_PANEL_HEIGHT"].flatMap(Double.init) ?? 640
    let hosting = NSHostingController(rootView: PanelView(model: model))
    let view = hosting.view
    view.frame = NSRect(x: 0, y: 0, width: 380, height: CGFloat(dumpHeight))
    if ProcessInfo.processInfo.environment["SWITCHPILOT_DARK"] != nil {
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }
    view.appearance = NSApp.appearance
    view.layoutSubtreeIfNeeded()
    guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
        FileHandle.standardError.write(Data("panel dump: no bitmap\n".utf8))
        return 1
    }
    view.cacheDisplay(in: view.bounds, to: rep)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write(Data("panel dump: no png\n".utf8))
        return 1
    }
    let path = ProcessInfo.processInfo.environment["SWITCHPILOT_PANEL_DUMP"] ?? "/tmp/switchpilot-panel.png"
    do { try data.write(to: URL(fileURLWithPath: path)) }
    catch { FileHandle.standardError.write(Data("panel dump: \(error)\n".utf8)); return 1 }
    print(path)
    return 0
}

@MainActor
func loginItemTest() -> Int32 {
    let before = LoginItem.state
    print("before=\(before)")
    do {
        try LoginItem.enable()
        print("registered=\(LoginItem.state)")
        try LoginItem.disable()
        print("after=\(LoginItem.state)")
        return 0
    } catch {
        print("error=\(error)")
        return 1
    }
}

@MainActor
func panelSize() -> Int32 {
    let application = NSApplication.shared
    application.setActivationPolicy(.prohibited)
    let model = PanelModel()
    if ProcessInfo.processInfo.environment["SWITCHPILOT_HIDE_GUIDE"] != nil {
        model.hideGuideForPreview()
    }
    if ProcessInfo.processInfo.environment["SWITCHPILOT_FORCE_GUIDE"] != nil {
        model.forceGuideForPreview()
    }
    let hosting = NSHostingController(rootView: PanelView(model: model))
    hosting.sizingOptions = [.preferredContentSize]
    hosting.view.layoutSubtreeIfNeeded()
    let size = hosting.preferredContentSize
    print("\(Int(size.width.rounded()))x\(Int(size.height.rounded()))")
    return 0
}

@MainActor
func dumpSettings() -> Int32 {
    let application = NSApplication.shared
    application.setActivationPolicy(.prohibited)
    let model = SettingsModel()
    let hosting = NSHostingController(rootView: SettingsView(model: model))
    let view = hosting.view
    view.frame = NSRect(x: 0, y: 0, width: 460, height: 900)
    if ProcessInfo.processInfo.environment["SWITCHPILOT_DARK"] != nil {
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }
    view.appearance = NSApp.appearance
    view.layoutSubtreeIfNeeded()
    guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return 1 }
    view.cacheDisplay(in: view.bounds, to: rep)
    guard let data = rep.representation(using: .png, properties: [:]) else { return 1 }
    let path = ProcessInfo.processInfo.environment["SWITCHPILOT_PANEL_DUMP"] ?? "/tmp/switchpilot-settings.png"
    try? data.write(to: URL(fileURLWithPath: path))
    print(path)
    return 0
}


let arguments = CommandLine.arguments
if arguments.contains("--login-item-test") {
    exit(MainActor.assumeIsolated { loginItemTest() })
}
if arguments.contains("--panel-size") {
    exit(MainActor.assumeIsolated { panelSize() })
}
if arguments.contains("--dump-settings") {
    exit(MainActor.assumeIsolated { dumpSettings() })
}
if arguments.contains("--dump-panel") {
    exit(MainActor.assumeIsolated { dumpPanel() })
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
MainActor.assumeIsolated { enforceSingleInstance() }
application.run()

@MainActor
func enforceSingleInstance() {
    guard ProcessInfo.processInfo.environment["SWITCHPILOT_SMOKE_TEST"] != "1" else { return }
    let running = NSRunningApplication.runningApplications(withBundleIdentifier: "local.personal.SwitchPilot")
        .filter { $0.processIdentifier != getpid() }
    guard let existing = running.first else { return }
    NSApplication.shared.setActivationPolicy(.accessory)
    let alert = NSAlert()
    alert.messageText = "SwitchPilot 已在运行"
    alert.informativeText = "请使用菜单栏中已有的实例；如果你找不到图标，可以退出所有实例后重新打开。"
    alert.addButton(withTitle: "好")
    alert.runModal()
    existing.activate()
    exit(0)
}
