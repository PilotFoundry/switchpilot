import SwiftUI
import SwitchPilotCore

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            permissionSection
            loginItemSection
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
                Text("v\(model.version) · 个人自用")
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
            if !model.permissionsReady {
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
            HStack(spacing: 8) {
                Button {
                    model.requestAllPermissions()
                } label: {
                    Label("申请全部权限", systemImage: "checkmark.shield")
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.busy)
                Button("重新检查") { model.recheck() }
                    .buttonStyle(.bordered)
                    .disabled(model.busy)
                if !model.accessibilityTrusted {
                    Button("去授权辅助功能") { model.requestAccessibilityPrompt() }
                        .buttonStyle(.bordered)
                        .disabled(model.busy)
                }
            }
            Divider()
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.secondaryInk)
                VStack(alignment: .leading, spacing: 4) {
                    Text("如何撤销授权")
                        .font(.caption.weight(.medium))
                    Text("macOS 没有应用内批量撤回授权的 API。请在系统设置 › 隐私与安全性 › 自动化 / 辅助功能中手动取消 SwitchPilot；如果需要重置记录，可在终端自行执行 tccutil（本应用不会自动调用）。")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Button("打开自动化设置") { model.openAutomationSettings() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        Button("打开辅助功能设置") { model.openAccessibilitySettings() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            }
        }
    }

    private var loginItemSection: some View {
        section("登录", subtitle: "使用 macOS ServiceManagement（SMAppService）注册本应用。") {
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
                Button("打开系统设置 › 登录项") { model.openLoginItemsSettings() }
                    .buttonStyle(.bordered)
            }
            Text("如果系统拒绝注册（例如签名或应用位置限制），会显示真实错误；ad-hoc 个人构建可能需要在系统设置中批准。")
                .font(.caption)
                .foregroundStyle(Color.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
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
                Text(title).font(.caption.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(Color.secondaryInk)
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
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.secondaryInk)
            if let subtitle {
                Text(subtitle)
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
