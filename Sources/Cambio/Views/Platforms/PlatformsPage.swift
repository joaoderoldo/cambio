import CambioCore
import SwiftUI

/// The platforms the person receives through, plus "Add platform".
struct PlatformsPage: View {
    let platforms: PlatformStore
    let open: (UUID) -> Void
    let add: () -> Void
    let back: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavBar("Platforms", back: back)
            Text("How money reaches your account. Cambio applies each one's fees to the live rate.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 8)
            ScrollIfLive {
                VStack(spacing: 1) {
                    ForEach(platforms.platforms) { platform in
                        Button { open(platform.id) } label: {
                            HStack(spacing: 10) {
                                PlatformBadge(platform: platform, size: 28)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(verbatim: "\(platform.name) · \(platform.method)")
                                        .font(.system(size: 13, weight: .semibold))
                                        .lineLimit(1)
                                    Text(verbatim: PayoutText.summary(platform))
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(RowStyle(verticalPadding: 6))
                    }
                    Button(action: add) {
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 8.4, style: .continuous)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                .foregroundStyle(Color.accentColor.opacity(0.7))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Image(systemName: "plus")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color.accentColor)
                                )
                            Text("Add platform")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.accentColor)
                            Spacer()
                        }
                    }
                    .buttonStyle(RowStyle(verticalPadding: 6))
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onExitCommand(perform: back)
    }
}
