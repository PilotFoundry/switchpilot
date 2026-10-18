import SwiftUI
import SwitchPilotCore

struct PanelView: View {
    @ObservedObject var model: PanelModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            keepAwakeSection
            Divider()
            darkModeSection
            Divider()
            quickActionsSection
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 320)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "switch.2")
                .font(.title2)
            VStack(alignment: .leading, spacing: 1) {
                Text("SwitchPilot").font(.headline)
                Text("个人自用 · v\(model.version)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var keepAwakeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: Binding(get: { model.keepAwakeActive }, set: { model.setKeepAwake($0) })) {
                Label("保持亮屏", systemImage: "display")
            }
            .toggleStyle(.switch)
            .controlSize(.small)

            Picker("时长", selection: Binding(get: { model.preset }, set: { model.setPreset($0) })) {
                ForEach(KeepAwakePreset.allCases) { preset in
                    Text(preset.label).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text(model.keepAwakeRemaining).font(.caption).foregroundStyle(.secondary)
            if let error = model.keepAwakeError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            Text("仅阻止空闲导致的显示器休眠；不阻止合盖、手动睡眠或低电量睡眠。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var darkModeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: Binding(get: { model.systemIsDark }, set: { model.setDarkMode($0) })) {
                Label("深色模式", systemImage: "moon")
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .disabled(model.darkModeBusy)

            Text(model.systemIsDark ? "系统当前：深色" : "系统当前：浅色")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("权限：\(model.darkModePermission.description)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            if let error = model.darkModeError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            if !model.darkModeStatus.isEmpty {
                Text(model.darkModeStatus).font(.caption).foregroundStyle(.secondary)
            }
            if !model.darkModePermission.canWrite {
                HStack(spacing: 8) {
                    Button("请求授权…") { model.requestDarkModeAuthorization() }
                        .disabled(model.darkModeBusy)
                    Button("打开自动化设置") { model.openAutomationSettings() }
                }
                .font(.caption)
            } else {
                Button("打开自动化设置") { model.openAutomationSettings() }
                    .font(.caption)
                    .buttonStyle(.link)
            }
            Text("属于 Automation/TCC 授权项；拒绝或撤销授权时不会显示切换成功。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Button {
                    model.startScreenSaver()
                } label: {
                    Label("启动屏保", systemImage: "play.rectangle")
                }
                .buttonStyle(.bordered)

                Button {
                    model.lockScreen()
                } label: {
                    Label("锁定屏幕", systemImage: "lock")
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.small)

            VStack(alignment: .leading, spacing: 2) {
                Text("屏保：\(model.screenSaverStatus)")
                Text("锁屏：\(model.lockStatus)")
                Text("锁屏权限：\(model.lockPermissions.summary)")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            Text("屏保/锁屏会立即改变屏幕状态，需要确认；锁屏需要 Automation 与辅助功能授权。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("原 One Switch 未被修改").font(.caption2).foregroundStyle(.secondary)
                Text("无后台自动操作 · 仅本机").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Button("退出") { model.quit() }
                .buttonStyle(.borderless)
                .font(.caption)
        }
    }
}
