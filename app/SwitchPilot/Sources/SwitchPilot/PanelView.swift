import SwiftUI
import SwitchPilotCore

/// v0.3 panel: readable surfaces, explicit button affordances, permission
/// actions visible as buttons, and a first-run guide that can request all
/// permissions at once. Basic actions stay usable without any permission.
struct PanelView: View {
    @ObservedObject var model: PanelModel
    var opaqueBackground = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if !model.hasSeenWelcome || model.showGuide {
                guideCard
            }
            if !model.allPermissionsReady && !model.guideVisible {
                permissionsNeededCard
            }
            keepAwakeCard
            systemCard
            quickActionsCard
            footer
        }
        .padding(16)
        .frame(width: 380)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                .allowsHitTesting(false)
        )
    }

    private var panelBackground: some View {
        // The live panel uses a behind-window NSVisualEffectView material. The
        // development dump paths request an opaque fallback so offscreen
        // screenshots remain readable without a desktop behind them.
        Group {
            if opaqueBackground {
                Color(nsColor: .windowBackgroundColor)
            } else {
                // Magnet-like menu material: a stronger adaptive tint keeps the
                // surface dark and readable while retaining a little desktop
                // depth. This is intentionally more opaque than Xiaomi's menu.
                Color(nsColor: .windowBackgroundColor).opacity(0.90)
            }
        }
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
                Text(LF("菜单栏开关 · v%@", model.version))
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
            Text(L(model.statusTitle))
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
                        Label(model.permissionBusy ? L("请求中…") : L("申请全部权限"), systemImage: "checkmark.shield")
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
            Text(L(text))
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
                    .accessibilityValue(model.keepAwakeActive ? LF("已开启，%@", model.keepAwakeRemaining) : L("已关闭"))
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
                Text(L(model.keepAwakeRemaining))
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

    // MARK: - System controls

    private var systemCard: some View {
        VStack(spacing: 10) {
            darkModeRow
            Divider().opacity(0.45)
            microphoneRow
        }
        .padding(12)
        .background(cardBackground)
    }

    private var darkModeRow: some View {
        HStack(spacing: 10) {
            Image(systemName: model.systemIsDark ? "moon.fill" : "sun.max")
                .font(.system(size: 14, weight: .medium))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text("深色模式")
                    .font(.system(size: 14, weight: .medium))
                HStack(spacing: 4) {
                    Image(systemName: model.darkModePermission == .allowed ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(model.darkModePermission == .allowed ? Color.successInk : permissionColor)
                    Text(model.systemIsDark ? L("系统当前：深色") : L("系统当前：浅色"))
                        .font(.caption)
                        .foregroundStyle(Color.secondaryInk)
                    Text("·").foregroundStyle(Color.secondaryInk)
                    Text(L(permissionText))
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
                if let error = model.darkModeError {
                    Text(error).font(.caption2).foregroundStyle(Color.errorInk)
                } else if !model.darkModeStatus.isEmpty {
                    Text(L(model.darkModeStatus)).font(.caption2).foregroundStyle(Color.secondaryInk)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(get: { model.systemIsDark }, set: { model.setDarkMode($0) }))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(model.darkModeBusy)
                .accessibilityLabel("深色模式")
                .accessibilityValue(model.systemIsDark ? L("系统当前为深色") : L("系统当前为浅色"))
        }
    }

    private var microphoneRow: some View {
        HStack(spacing: 10) {
            Image(systemName: microphoneIcon)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text("麦克风")
                    .font(.system(size: 14, weight: .medium))
                if !model.microphoneState.isAvailable {
                    Text(L(model.microphoneState.message ?? "未找到输入设备"))
                        .font(.caption)
                        .foregroundStyle(Color.secondaryInk)
                } else if model.microphoneState.supportsMute {
                    Text(model.microphoneState.muted == true ? L("麦克风已静音") : L("麦克风已开启"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(model.microphoneState.muted == true ? Color.errorInk : Color.secondaryInk)
                    Text(model.microphoneState.name)
                        .font(.caption2)
                        .foregroundStyle(Color.secondaryInk)
                } else {
                    Text(L(model.microphoneState.message ?? "当前输入设备不支持系统静音控制"))
                        .font(.caption)
                        .foregroundStyle(Color.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(model.microphoneState.name)
                        .font(.caption2)
                        .foregroundStyle(Color.secondaryInk)
                    Text("可在系统设置 › 声音中调整输入设备。")
                        .font(.caption2)
                        .foregroundStyle(Color.secondaryInk)
                }
                if !model.microphoneError.isEmpty {
                    Text(model.microphoneError).font(.caption2).foregroundStyle(Color.errorInk)
                }
            }
            Spacer()
            if model.microphoneState.supportsMute {
                Button {
                    model.toggleMicrophoneMute()
                } label: {
                    Text(model.microphoneState.muted == true ? L("取消静音") : L("静音麦克风"))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(model.microphoneState.muted == true ? L("取消麦克风静音") : L("静音麦克风"))
                .accessibilityLabel(model.microphoneState.muted == true ? L("取消麦克风静音") : L("静音麦克风"))
            }
        }
    }

    private var permissionText: String {
        if model.darkModePermission == .allowed { return L("已授权") }
        if model.darkModePermission == .targetNotRunning || model.darkModePermission == .notDetermined { return L("待授权") }
        return model.darkModePermission.userFacingDescription
    }

    private var permissionColor: Color {
        switch model.darkModePermission {
        case .denied: return .errorInk
        default: return .warningInk
        }
    }

    private var microphoneIcon: String {
        model.microphoneState.muted == true ? "mic.slash.fill" : "mic.fill"
    }

    // MARK: - Quick actions

    private var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("快速动作")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.secondaryInk)
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
            ], spacing: 8) {
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
                    badge: model.lockNeedsPermission ? L("需授权") : nil,
                    action: { model.lockScreen() })
                actionTile(
                    title: "关闭显示器",
                    subtitle: "休眠 · 唤醒看系统",
                    systemImage: "display",
                    badge: nil,
                    action: { model.sleepDisplay() })
                actionTile(
                    title: "清洁屏幕",
                    subtitle: "锁键盘 · 鼠标退出",
                    systemImage: "sparkles",
                    badge: nil,
                    action: { model.startScreenCleaning() })
            }
            if !actionStatusLines.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(actionStatusLines, id: \.self) { line in
                        Text(line)
                    }
                }
                .font(.caption2)
                .foregroundStyle(Color.secondaryInk)
            }
            if !model.screenCleaningError.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "xmark.octagon.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.errorInk)
                    Text(L(model.screenCleaningError))
                        .font(.caption2)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    if model.screenCleaningNeedsAccessibility {
                        Button("打开辅助功能设置") { model.openAccessibilitySettings() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            }
        }
        .padding(12)
        .background(cardBackground)
    }

    private var actionStatusLines: [String] {
        var lines: [String] = []
        if model.screenSaverStatus != L("未执行") {
            lines.append(LF("屏保：%@", model.screenSaverStatus))
        }
        if model.lockStatus != L("未执行") {
            lines.append(LF("锁屏：%@", model.lockStatus))
        }
        if model.displaySleepStatus != L("未执行") {
            lines.append(LF("显示器：%@", model.displaySleepStatus))
        }
        if model.screenCleaningError.isEmpty && model.screenCleaningStatus != L("未执行") {
            lines.append(LF("清洁：%@", model.screenCleaningStatus))
        }
        return lines
    }

    private func actionTile(
        title: String,
        subtitle: String,
        systemImage: String,
        badge: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    if let badge {
                        Text(L(badge))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.primary)
                            .accessibilityLabel(L("需要授权"))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.orange.opacity(0.20)))
                    }
                }
                Text(L(title))
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L(subtitle))
                    .font(.caption2)
                    .foregroundStyle(Color.secondaryInk)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .accessibilityLabel(L(title))
        .accessibilityHint(L(subtitle))
    }

    // MARK: - Permission panel


    private func inlineError(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "xmark.octagon.fill")
                .font(.caption2)
                .foregroundStyle(Color.errorInk)
            Text(L(message))
                .font(.caption2)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Permissions

    private var missingPermissionLabels: [String] {
        var labels: [String] = []
        if model.darkModePermission != .allowed {
            labels.append(L("Automation（深色模式、锁屏）"))
        }
        if !model.accessibilityTrusted {
            labels.append(L("辅助功能（锁屏）"))
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
            Text(LF("缺少：%@。未授权时相关操作不会执行；保持亮屏和启动屏保不受影响。", missingPermissionLabels.joined(separator: L("、"))))
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

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.primary.opacity(0.05))
    }
}
