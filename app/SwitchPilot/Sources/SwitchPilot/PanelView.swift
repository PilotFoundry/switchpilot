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
            audioCard
            quickActionsCard
            if !model.allPermissionsReady && !model.guideVisible {
                permissionsNeededCard
            }
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
            guideRow("2", "「深色模式」需要 Automation 授权；不授权时此开关不会生效。")
            guideRow("3", "「屏保 / 锁屏」点击即执行；屏保移动鼠标退出，锁屏需密码解锁；锁屏还需要辅助功能授权。")
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
                if !model.allPermissionsReady {
                    Button {
                        model.requestAllPermissions()
                    } label: {
                        Label(model.permissionBusy ? "请求中…" : "申请全部权限", systemImage: "checkmark.shield")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(model.permissionBusy)
                }

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

    // MARK: - Output volume

    private var audioCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: audioIcon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                Text("输出音量")
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                if model.audioState.supportsMute {
                    Button {
                        model.toggleAudioMute()
                    } label: {
                        Label(
                            model.audioState.muted == true ? "取消静音" : "静音",
                            systemImage: model.audioState.muted == true ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(model.audioState.muted == true ? "取消静音" : "静音输出")
                    .accessibilityLabel(model.audioState.muted == true ? "取消静音" : "静音输出")
                }
            }
            if !model.audioState.isAvailable {
                Text(model.audioState.message ?? "未找到输出设备")
                    .font(.caption)
                    .foregroundStyle(Color.secondaryInk)
            } else if model.audioState.supportsVolume {
                HStack(spacing: 8) {
                    Slider(value: Binding(
                        get: { model.audioVolume },
                        set: { model.setAudioVolume($0) }), in: 0...1)
                        .accessibilityLabel("输出音量")
                        .disabled(model.audioState.muted == true)
                        .opacity(model.audioState.muted == true ? 0.55 : 1)
                    if model.audioState.muted == true {
                        Label("已静音", systemImage: "speaker.slash")
                            .font(.caption2)
                            .foregroundStyle(Color.secondaryInk)
                            .labelStyle(.titleAndIcon)
                    } else {
                        Text("\(Int((model.audioVolume * 100).rounded()))%")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Color.secondaryInk)
                            .frame(width: 34, alignment: .trailing)
                    }
                }
                Text(model.audioState.name)
                    .font(.caption2)
                    .foregroundStyle(Color.secondaryInk)
            } else {
                Text(model.audioState.message ?? "当前输出不支持系统音量控制")
                    .font(.caption)
                    .foregroundStyle(Color.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                Text(model.audioState.name)
                    .font(.caption2)
                    .foregroundStyle(Color.secondaryInk)
            }
            if !model.audioError.isEmpty {
                inlineError(model.audioError)
            }
        }
        .padding(12)
        .background(cardBackground)
    }

    private var audioIcon: String {
        if model.audioState.muted == true { return "speaker.slash" }
        if model.audioState.supportsVolume {
            return model.audioVolume < 0.05 ? "speaker.wave.1" : "speaker.wave.2"
        }
        return "speaker"
    }

    // MARK: - Quick actions

    private var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("快速动作")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.secondaryInk)
            HStack(spacing: 8) {
                actionTile(
                    title: "启动屏保",
                    subtitle: "启动 · 鼠标退出",
                    systemImage: "play.rectangle",
                    badge: nil,
                    action: { model.startScreenSaver() })
                actionTile(
                    title: "锁定屏幕",
                    subtitle: "锁定 · 密码解锁",
                    systemImage: "lock",
                    badge: model.lockNeedsPermission ? "需授权" : nil,
                    action: { model.lockScreen() })
                actionTile(
                    title: "关闭显示器",
                    subtitle: "休眠 · 鼠标唤醒",
                    systemImage: "display",
                    badge: nil,
                    action: { model.sleepDisplay() })
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("屏保：\(model.screenSaverStatus)")
                Text("锁屏：\(model.lockStatus)")
                Text("显示器：\(model.displaySleepStatus)")
            }
            .font(.caption2)
            .foregroundStyle(Color.secondaryInk)
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

    // MARK: - Permissions

    private var missingPermissionLabels: [String] {
        var labels: [String] = []
        if model.darkModePermission != .allowed {
            labels.append("Automation（深色模式、锁屏）")
        }
        if !model.accessibilityTrusted {
            labels.append("辅助功能（锁屏）")
        }
        return labels
    }

    private var permissionsNeededCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: "lock.shield")
                    .font(.caption)
                    .foregroundStyle(Color.warningInk)
                Text("需要授权")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            Text("缺少：\(missingPermissionLabels.joined(separator: "、"))。未授权时相关操作不会执行；保持亮屏和启动屏保不受影响。")
                .font(.caption)
                .foregroundStyle(Color.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                if model.darkModePermission == .denied {
                    Button("打开自动化设置") { model.openAutomationSettings() }
                        .buttonStyle(.borderedProminent)
                } else if model.darkModePermission != .allowed {
                    Button {
                        model.requestAllPermissions()
                    } label: {
                        Label("申请全部权限", systemImage: "checkmark.shield")
                    }
                    .buttonStyle(.borderedProminent)
                } else if !model.accessibilityTrusted {
                    Button("去授权辅助功能") { model.requestAccessibilityPrompt() }
                        .buttonStyle(.borderedProminent)
                }
                if model.darkModePermission == .denied && !model.accessibilityTrusted {
                    Button("去授权辅助功能") { model.requestAccessibilityPrompt() }
                        .buttonStyle(.bordered)
                }
                Button("重新检查") { model.recheckPermissions() }
                    .buttonStyle(.bordered)
            }
            .controlSize(.small)
        }
        .padding(12)
        .background(cardBackground)
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
