import SwiftUI
import SwitchPilotCore

/// v0.3 panel: readable surfaces, explicit button affordances, permission
/// actions visible as buttons, and a first-run guide that can request all
/// permissions at once. Basic actions stay usable without any permission.
struct PanelView: View {
    @ObservedObject var model: PanelModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if !model.hasSeenWelcome || model.showGuide {
                guideCard
            }
            keepAwakeCard
            appearanceCard
            quickActionsCard
            footer
        }
        .padding(16)
        .frame(width: 380)
        .background(panelBackground)
    }

    private var panelBackground: some View {
        // One opaque surface: macOS 27 dials down layered glass, and an opaque
        // background keeps the measured contrast stable over any desktop.
        Color(nsColor: .windowBackgroundColor)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(0.08))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(nsImage: StatusIcon.make(size: 20))
                        .renderingMode(.template)
                        .foregroundStyle(.primary)
                )
            VStack(alignment: .leading, spacing: 1) {
                Text("SwitchPilot")
                    .font(.system(size: 15, weight: .semibold))
                Text("菜单栏开关 · v\(model.version)")
                    .font(.caption2)
                    .foregroundStyle(Color.secondaryInk)
            }
            Spacer()
            statusBadge
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(model.keepAwakeActive ? Color.successInk : Color.secondary.opacity(0.55))
                .frame(width: 6, height: 6)
            Text(model.statusTitle)
                .font(.caption2.weight(.medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(model.keepAwakeActive ? Color.green.opacity(0.16) : Color.primary.opacity(0.07))
        )
    }

    // MARK: - First-run guide

    private var guideCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("开始使用")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if model.allPermissionsReady {
                    Label("权限已就绪", systemImage: "checkmark.seal.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.successInk)
                }
            }
            guideRow("1", "「保持亮屏」开启后，系统不会因空闲而熄灭屏幕；可设置时长。")
            guideRow("2", "「深色模式」首次使用需要 Automation 授权；不需要时也可以不使用该开关。")
            guideRow("3", "「屏保 / 锁屏」会先确认；锁屏还需要辅助功能授权。")
            Text("不授权也可以使用保持亮屏和启动屏保；所有权限都可在设置中撤销。")
                .font(.caption2)
                .foregroundStyle(Color.secondaryInk)
            if !model.permissionSetupMessage.isEmpty {
                Text(model.permissionSetupMessage)
                    .font(.caption2)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if model.permissionBusy {
                ProgressView().progressViewStyle(.linear).controlSize(.small)
            }
            HStack(spacing: 8) {
                Button {
                    model.requestAllPermissions()
                } label: {
                    Label(model.permissionBusy ? "请求中…" : (model.allPermissionsReady ? "权限已就绪" : "申请全部权限"), systemImage: "checkmark.shield")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(model.allPermissionsReady || model.permissionBusy)

                Button("重新检查") { model.recheckPermissions() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                Button("稍后再说") { model.dismissGuide() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .padding(.top, 1)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentColor.opacity(0.09))
        )
    }

    private func guideRow(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.caption2.weight(.bold))
                .frame(width: 16, height: 16)
                .background(Circle().fill(Color.accentColor.opacity(0.18)))
            Text(text)
                .font(.caption)
                .foregroundStyle(Color.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Keep awake

    private var keepAwakeCard: some View {
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
                    .tint(Color.successInk)
            }
            HStack(spacing: 5) {
                Image(systemName: model.keepAwakeActive ? "checkmark.circle.fill" : "minus.circle")
                    .font(.caption2)
                    .foregroundStyle(model.keepAwakeActive ? Color.successInk : Color.secondary)
                Text(model.keepAwakeRemaining)
                    .font(.caption)
                    .foregroundStyle(Color.secondaryInk)
            }
            if let error = model.keepAwakeError {
                inlineError(error)
            }
            Text("不阻止合盖、手动睡眠或低电量睡眠。")
                .font(.caption2)
                .foregroundStyle(Color.secondaryInk)
        }
        .padding(12)
        .background(cardBackground)
    }

    // MARK: - Appearance

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 9) {
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
            HStack(spacing: 5) {
                Image(systemName: model.darkModePermission == .allowed ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(model.darkModePermission == .allowed ? Color.successInk : permissionColor)
                Text(model.systemIsDark ? "系统当前：深色" : "系统当前：浅色")
                    .font(.caption)
                    .foregroundStyle(Color.secondaryInk)
                Text("·").foregroundStyle(Color.secondaryInk)
                Text(permissionText)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            if let error = model.darkModeError {
                inlineError(error)
            } else if !model.darkModeStatus.isEmpty {
                Text(model.darkModeStatus)
                    .font(.caption2)
                    .foregroundStyle(Color.secondaryInk)
            }
            if model.darkModeNeedsPermission && !model.guideVisible {
                permissionPanel(
                    text: "切换系统外观需要 Automation 授权；未授权时不会修改外观。",
                    primaryTitle: "申请 Automation 授权",
                    primaryIcon: "lock.open",
                    primaryAction: { model.requestDarkModeAuthorization() },
                    secondaryTitle: "打开系统设置",
                    secondaryAction: { model.openAutomationSettings() })
            }
        }
        .padding(12)
        .background(cardBackground)
    }

    private var permissionText: String {
        if model.darkModePermission == .allowed { return "已授权" }
        if model.darkModePermission == .targetNotRunning || model.darkModePermission == .notDetermined { return "待授权" }
        return model.darkModePermission.userFacingDescription
    }

    private var permissionColor: Color {
        switch model.darkModePermission {
        case .denied: return .errorInk
        default: return .warningInk
        }
    }

    // MARK: - Quick actions

    private var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("快速动作")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.secondaryInk)
            HStack(spacing: 10) {
                actionTile(
                    title: "启动屏保",
                    subtitle: "确认后立即启动",
                    systemImage: "play.rectangle",
                    badge: nil,
                    action: { model.startScreenSaver() })
                actionTile(
                    title: "锁定屏幕",
                    subtitle: "发送系统锁定快捷键",
                    systemImage: "lock",
                    badge: model.lockNeedsPermission ? "需授权" : nil,
                    action: { model.lockScreen() })
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("屏保：\(model.screenSaverStatus)")
                Text("锁屏：\(model.lockStatus)")
            }
            .font(.caption2)
            .foregroundStyle(Color.secondaryInk)
            if model.lockNeedsPermission && !model.guideVisible {
                if model.lockPermissions.automation != .allowed {
                    permissionPanel(
                        text: "锁屏需要 Automation 与辅助功能授权；当前缺少 Automation，未授权时不会发送按键。",
                        primaryTitle: "申请 Automation 授权",
                        primaryIcon: "lock.open",
                        primaryAction: { model.requestLockAutomation() },
                        secondaryTitle: "打开辅助功能设置",
                        secondaryAction: { model.openAccessibilitySettings() })
                } else {
                    permissionPanel(
                        text: "Automation 已授权；锁屏还需要辅助功能（Accessibility）授权，未授权时不会发送按键。",
                        primaryTitle: "去授权辅助功能",
                        primaryIcon: "hand.raised",
                        primaryAction: { model.requestAccessibilityPrompt() },
                        secondaryTitle: "打开辅助功能设置",
                        secondaryAction: { model.openAccessibilitySettings() })
                }
            }
        }
        .padding(12)
        .background(cardBackground)
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
                        .foregroundStyle(.primary)
                    Spacer()
                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.primary)
                            .accessibilityLabel("需要授权")
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.orange.opacity(0.20)))
                    }
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(Color.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }

    // MARK: - Permission panel

    private func permissionPanel(
        text: String,
        primaryTitle: String,
        primaryIcon: String,
        primaryAction: @escaping () -> Void,
        secondaryTitle: String,
        secondaryAction: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.caption)
                    .foregroundStyle(Color.warningInk)
                Text(text)
                    .font(.caption2)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                Button {
                    primaryAction()
                } label: {
                    Label(primaryTitle, systemImage: primaryIcon)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(secondaryTitle) { secondaryAction() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }

    private func inlineError(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "xmark.octagon.fill")
                .font(.caption2)
                .foregroundStyle(Color.errorInk)
            Text(message)
                .font(.caption2)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.caption2)
                    .foregroundStyle(Color.secondaryInk)
                Text(model.permissionsSummary)
                    .font(.caption2)
                    .foregroundStyle(Color.secondaryInk)
                    .lineLimit(2)
            }
            HStack(spacing: 8) {
                Button("使用说明") { model.toggleGuide() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("设置…") { model.openSettings() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Spacer()
                Button("退出") { model.quit() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.primary.opacity(0.05))
    }
}
