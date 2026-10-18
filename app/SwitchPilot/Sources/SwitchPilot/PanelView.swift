import SwiftUI
import SwitchPilotCore

/// macOS 27 (Golden Gate) direction: quiet surfaces, few decorative icons, clear
/// hierarchy and generous targets. The panel is the primary onboarding surface:
/// the first-run guide explains what each control does and when a permission
/// prompt appears, then gets out of the way.
struct PanelView: View {
    @ObservedObject var model: PanelModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if !model.hasSeenWelcome || model.showGuide {
                guideCard
            }
            keepAwakeSection
            Divider().opacity(0.5)
            appearanceSection
            Divider().opacity(0.5)
            quickActionsSection
            Divider().opacity(0.5)
            footer
        }
        .padding(16)
        .frame(width: 360)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(0.07))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: "switch.2")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.primary)
                )
            VStack(alignment: .leading, spacing: 1) {
                Text("SwitchPilot")
                    .font(.system(size: 15, weight: .semibold))
                Text("菜单栏开关 · v\(model.version)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            statusBadge
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(model.keepAwakeActive ? Color.green : Color.secondary.opacity(0.5))
                .frame(width: 6, height: 6)
            Text(model.statusTitle)
                .font(.caption2.weight(.medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(model.keepAwakeActive ? Color.green.opacity(0.14) : Color.primary.opacity(0.06))
        )
    }

    // MARK: - First-run guide

    private var guideCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("开始使用")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button {
                    model.dismissGuide()
                } label: {
                    Text("知道了")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            guideRow("1", "「保持亮屏」开启后，系统不会因空闲而熄灭屏幕；可设置时长。")
            guideRow("2", "「深色模式」首次使用需要授权 Automation；只在点击后请求。")
            guideRow("3", "「屏保 / 锁屏」会先确认；锁屏还需要辅助功能授权。")
            Text("所有权限都可在系统设置中随时撤销，SwitchPilot 不会在后台自动控制。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.accentColor.opacity(0.08)))
    }

    private func guideRow(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.caption2.weight(.bold))
                .frame(width: 16, height: 16)
                .background(Circle().fill(Color.accentColor.opacity(0.16)))
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Keep awake

    private var keepAwakeSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("保持亮屏")
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                Toggle("", isOn: Binding(get: { model.keepAwakeActive }, set: { model.setKeepAwake($0) }))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .accessibilityLabel("保持亮屏")
                    .accessibilityValue(model.keepAwakeActive ? "已开启，\(model.keepAwakeRemaining)" : "已关闭")
            }

            Picker("时长", selection: Binding(get: { model.preset }, set: { model.setPreset($0) })) {
                ForEach(KeepAwakePreset.allCases) { preset in
                    Text(preset.label).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)

            if let progress = model.keepAwakeProgress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(.green)
            }

            HStack(spacing: 4) {
                Image(systemName: model.keepAwakeActive ? "checkmark.circle.fill" : "minus.circle")
                    .font(.caption2)
                    .foregroundStyle(model.keepAwakeActive ? Color.green : Color.secondary)
                Text(model.keepAwakeRemaining)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            if let error = model.keepAwakeError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            Text("不阻止合盖、手动睡眠或低电量睡眠。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("外观")
            HStack {
                Text("深色模式")
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                Toggle("", isOn: Binding(get: { model.systemIsDark }, set: { model.setDarkMode($0) }))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .disabled(model.darkModeBusy)
                    .accessibilityLabel("深色模式")
                    .accessibilityValue(model.systemIsDark ? "系统当前为深色" : "系统当前为浅色")
            }
            HStack(spacing: 6) {
                Text(model.systemIsDark ? "系统当前：深色" : "系统当前：浅色")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("·").foregroundStyle(.tertiary)
                Text(permissionStateText)
                    .font(.caption2)
                    .foregroundStyle(permissionStateColor)
            }
            if let error = model.darkModeError {
                Text(error).font(.caption).foregroundStyle(.red)
            } else if !model.darkModeStatus.isEmpty {
                Text(model.darkModeStatus).font(.caption).foregroundStyle(.secondary)
            }
            if model.darkModeNeedsPermission {
                HStack(spacing: 8) {
                    Button("请求授权…") { model.requestDarkModeAuthorization() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(model.darkModeBusy)
                    Button("打开系统设置") { model.openAutomationSettings() }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                }
            }
        }
    }

    private var permissionStateText: String {
        if model.darkModePermission == .allowed { return "已授权" }
        if model.darkModePermission == .targetNotRunning { return "首次操作会请求授权" }
        return model.darkModePermission.description
    }

    private var permissionStateColor: Color {
        switch model.darkModePermission {
        case .allowed: return .secondary
        case .denied: return .red
        default: return .orange
        }
    }

    // MARK: - Quick actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("快速动作")
            HStack(spacing: 10) {
                actionTile(
                    title: "启动屏保",
                    subtitle: "立即启动系统屏幕保护",
                    systemImage: "play.rectangle",
                    badge: nil,
                    action: { model.startScreenSaver() })
                actionTile(
                    title: "锁定屏幕",
                    subtitle: "等价 Ctrl+Cmd+Q",
                    systemImage: "lock",
                    badge: model.lockNeedsPermission ? "需授权" : nil,
                    action: { model.lockScreen() })
            }
            Text("屏保：\(model.screenSaverStatus) · 锁屏：\(model.lockStatus)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            if model.lockNeedsPermission {
                VStack(alignment: .leading, spacing: 6) {
                    Text("锁屏需要 Automation + 辅助功能授权；未授权时不会发送按键。")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Button("请求 Automation…") { model.requestLockAutomation() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        Button("打开辅助功能设置") { model.openAccessibilitySettings() }
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                    }
                }
            }
        }
    }

    private func actionTile(
        title: String,
        subtitle: String,
        systemImage: String,
        badge: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .medium))
                    Spacer()
                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(model.permissionsSummary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer()
                Button(model.showGuide ? "收起说明" : "使用说明") {
                    model.toggleGuide()
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
            HStack {
                Text("原 One Switch 未被修改 · 无后台自动操作")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("退出") { model.quit() }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}
