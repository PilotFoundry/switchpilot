import SwiftUI
import SwitchPilotCore

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            permissionSection
            hotKeySection
            loginItemSection
            languageSection
            aboutSection

            if !model.message.isEmpty {
                Text(model.message)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.08)))
            }

            HStack {
                Spacer()
                Text("个人自用")
                    .font(.caption)
                    .foregroundStyle(Color.secondaryInk)
            }
        }
        .padding(20)
        .frame(width: 460)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var permissionSection: some View {
        section("权限", subtitle: "只在需要时申请；不授权也可使用保持亮屏与启动屏保。") {
            permissionRow(
                title: "Automation（System Events）",
                detail: model.automation.userFacingDescription,
                state: model.automation == .allowed)
            permissionRow(
                title: "辅助功能（Accessibility）",
                detail: model.accessibilityTrusted ? "已授权" : "未授权（锁屏需要）",
                state: model.accessibilityTrusted)

            if model.permissionsReady {
                Button(L("重新检查")) { model.recheck() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(model.busy)
            } else {
                HStack(spacing: 8) {
                    if model.automation == .denied {
                        Button(L("打开自动化设置")) { model.openAutomationSettings() }
                            .buttonStyle(.borderedProminent)
                    } else if model.automation != .allowed {
                        Button {
                            model.requestAllPermissions()
                        } label: {
                            Label("申请全部权限", systemImage: "checkmark.shield")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    if !model.accessibilityTrusted && model.automation == .allowed {
                        Button(L("去授权辅助功能")) { model.requestAccessibilityPrompt() }
                            .buttonStyle(.borderedProminent)
                    } else if !model.accessibilityTrusted && model.automation == .denied {
                        Button(L("去授权辅助功能")) { model.requestAccessibilityPrompt() }
                            .buttonStyle(.bordered)
                    }
                    Button(L("重新检查")) { model.recheck() }
                        .buttonStyle(.bordered)
                }
                .controlSize(.small)
                .disabled(model.busy)

                Button(model.showsDiagnostic ? L("收起诊断详情") : L("诊断详情")) {
                    model.toggleDiagnostic()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(Color.secondaryInk)

                if model.showsDiagnostic {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.diagnostic)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color.secondaryInk)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("如果系统设置里已经开启但仍显示未授权：通常是应用重新构建后签名身份变了。请退出应用，从 Finder 启动，并重新授权一次；必要时在终端执行 README 里的 tccutil reset 命令。")
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.05)))
                }
            }

            if model.hasAnyPermission {
                revokeDisclosure
            }
        }
    }

    private var revokeDisclosure: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                model.toggleRevokeHelp()
            } label: {
                HStack(spacing: 4) {
                    Text("如何撤销授权")
                    Image(systemName: model.showsRevokeHelp ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.secondaryInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .accessibilityLabel("如何撤销授权")
            .accessibilityValue(model.showsRevokeHelp ? L("已展开") : L("已收起"))
            .accessibilityHint("显示在系统设置中撤销授权的步骤，以及可复制的终端命令")

            if model.showsRevokeHelp {
                VStack(alignment: .leading, spacing: 9) {
                    Text("推荐在系统设置中手动撤销（更可控）；SwitchPilot 不会自动修改 TCC。")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Button(L("打开自动化设置")) { model.openAutomationSettings() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        Button(L("打开辅助功能设置")) { model.openAccessibilitySettings() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    Button {
                        model.toggleAdvancedTCCUtil()
                    } label: {
                        HStack(spacing: 4) {
                            Text("终端命令（高级）")
                            Image(systemName: model.showsAdvancedTCCUtil ? "chevron.down" : "chevron.right")
                                .font(.caption2)
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(Color.secondaryInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .accessibilityLabel("终端命令（高级）")
                    .accessibilityValue(model.showsAdvancedTCCUtil ? L("已展开") : L("已收起"))

                    if model.showsAdvancedTCCUtil {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(model.tccutilResetCommands)
                                .font(.system(size: 10, design: .monospaced))
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(7)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
                            HStack(spacing: 8) {
                                Button(model.tccutilCopied ? L("已复制") : L("复制命令")) {
                                    model.copyTCCUtilResetCommands()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                Text("只重置本应用；不要 sudo，勿用 reset All；重置后需重新授权。")
                                    .font(.caption2)
                                    .foregroundStyle(Color.secondaryInk)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Divider()
                            HStack(spacing: 5) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color.errorInk)
                                Text("不可逆操作")
                                    .font(.caption.weight(.medium))
                            }
                            Button("在应用内重置两项权限（不可撤销）…") {
                                confirmInAppReset()
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                            .controlSize(.small)
                            .disabled(model.busy)
                            Text("调用系统 tccutil，仅重置本应用两项授权；无 sudo、无 reset All；重置后需重新授权，系统弹窗不保证再次出现。")
                                .font(.caption2)
                                .foregroundStyle(Color.secondaryInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
            }
        }
    }

    private func confirmInAppReset() {
        let alert = NSAlert()
        alert.messageText = L("在应用内重置 SwitchPilot 的权限？")
        alert.informativeText = L("将执行系统自带的 tccutil，仅重置本应用（Automation + 辅助功能）的授权记录。此操作不可撤销，重置后需要重新授权；系统弹窗不保证再次出现，可能需要在系统设置中手动添加。SwitchPilot 不会使用 sudo，也不会执行 reset All。")
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("取消"))
        alert.addButton(withTitle: L("重置两项权限"))
        if let resetButton = alert.buttons.last {
            resetButton.hasDestructiveAction = true
        }
        if alert.runModal() == .alertSecondButtonReturn {
            model.resetInAppPermissions()
        }
    }

    private var hotKeySection: some View {
        section("快捷键", subtitle: "全局快捷键，应用在后台时也可触发；冲突或注册失败会显示错误。") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("启用全局快捷键")
                    Text(model.hotKeyCombos)
                        .font(.caption)
                        .foregroundStyle(Color.secondaryInk)
                }
                Spacer()
                Toggle("", isOn: Binding(get: { model.hotKeysEnabled }, set: { model.setHotKeysEnabled($0) }))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .disabled(!model.hotKeysAvailable)
            }
            if !model.hotKeyError.isEmpty {
                Text(model.hotKeyError)
                    .font(.caption)
                    .foregroundStyle(Color.errorInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("固定组合，不提供自定义录制；实验项默认关闭，只触发保持亮屏与启动屏保，不会在后台请求 TCC。")
                .font(.caption)
                .foregroundStyle(Color.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var loginItemSection: some View {
        section("登录", subtitle: "让 SwitchPilot 在你登录后自动启动。") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("登录时启动 SwitchPilot")
                    Text(model.loginState.description)
                        .font(.caption)
                        .foregroundStyle(Color.secondaryInk)
                }
                Spacer()
                Toggle("", isOn: Binding(get: { model.loginState == .enabled || model.loginState == .requiresApproval }, set: { model.setLoginItem($0) }))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .disabled(model.busy)
            }
            if model.loginState == .requiresApproval {
                Button(L("打开系统设置 › 登录项")) { model.openLoginItemsSettings() }
                    .buttonStyle(.bordered)
            }
            Text("由 macOS 服务管理注册；如果系统拒绝会显示真实错误，个人构建可能需要在系统设置中批准。")
                .font(.caption)
                .foregroundStyle(Color.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var languageSection: some View {
        section("语言", subtitle: "切换后需要重启应用生效。") {
            HStack(spacing: 10) {
                Picker("", selection: Binding(
                    get: { model.language },
                    set: { model.setLanguage($0) }
                )) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(L("退出并重新打开")) {
                    model.restartApp()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var aboutSection: some View {
        section("关于", subtitle: nil) {
            HStack {
                Text("SwitchPilot")
                    .font(.caption)
                Spacer()
                Text("v\(model.version)")
                    .font(.caption)
                    .foregroundStyle(Color.secondaryInk)
            }
            Text("个人自用菜单栏开关；不改原 One Switch，不做分发。")
                .font(.caption)
                .foregroundStyle(Color.secondaryInk)
        }
    }

    private func permissionRow(title: String, detail: String, state: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: state ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.caption)
                .foregroundStyle(state ? Color.successInk : Color.warningInk)
            VStack(alignment: .leading, spacing: 1) {
                Text(L(title)).font(.caption.weight(.medium))
                Text(L(detail)).font(.caption).foregroundStyle(Color.secondaryInk)
            }
            Spacer()
        }
    }

    private func section<Content: View>(
        _ title: String,
        subtitle: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L(title))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.secondaryInk)
            if let subtitle {
                Text(L(subtitle))
                    .font(.caption)
                    .foregroundStyle(Color.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
    }
}
