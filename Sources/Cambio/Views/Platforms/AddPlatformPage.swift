import CambioCore
import SwiftUI

/// Templates measured from real withdrawals, or a custom platform.
struct AddPlatformPage: View {
    let platforms: PlatformStore
    let addTemplate: (Platform) -> Void
    let custom: () -> Void
    let back: () -> Void

    private static let templates: [Platform] = [.deelPix, .higlobePix]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavBar("Add platform", back: back)
            Text("Start from a template and adjust it with your account's real rate.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 8)
            VStack(spacing: 1) {
                ForEach(Self.templates) { template in
                    templateRow(template)
                }
                Button(action: custom) {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 8.4, style: .continuous)
                            .fill(Color.primary.opacity(0.08))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            )
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Custom").font(.system(size: 13, weight: .semibold))
                            Text("You set the name, fees and spread").font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "plus.circle.fill").font(.system(size: 16)).foregroundStyle(Color.accentColor)
                    }
                }
                .buttonStyle(RowStyle(verticalPadding: 6))
            }
            .padding(.horizontal, 6)
            FootNote("Templates measured in Nov 2026 from real withdrawals. Fees change: check your account.")
                .padding(.horizontal, 16)
                .padding(.top, 10)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onExitCommand(perform: back)
    }

    private func isAdded(_ template: Platform) -> Bool {
        platforms.platforms.contains { $0.name == template.name && $0.method == template.method }
    }

    private func templateRow(_ template: Platform) -> some View {
        let added = isAdded(template)
        return Button { addTemplate(template) } label: {
            HStack(spacing: 10) {
                PlatformBadge(platform: template, size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: "\(template.name) · \(template.method)").font(.system(size: 13, weight: .semibold))
                    Text(verbatim: PayoutText.summary(template)).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                if added {
                    Text("Added").font(.system(size: 11, weight: .medium)).foregroundStyle(.tertiary)
                } else {
                    Image(systemName: "plus.circle.fill").font(.system(size: 16)).foregroundStyle(Color.accentColor)
                }
            }
        }
        .buttonStyle(RowStyle(verticalPadding: 6))
        .disabled(added)
    }
}
