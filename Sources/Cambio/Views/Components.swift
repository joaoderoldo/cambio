import CambioCore
import SwiftUI

// MARK: - Currency identity

/// A currency as a circle: its flag cropped round, or a colored badge for crypto and metals.
struct CurrencyBadge: View {
    let code: String
    var size: CGFloat = 22

    // The emoji flag is drawn larger than the circle and nudged so the cloth fills it
    // with no white edge (tuned in the approved preview).
    private static let flagScale: CGFloat = 2.2
    private static let flagOffsetX: CGFloat = 0.08
    private static let flagOffsetY: CGFloat = 0.06

    var body: some View {
        ZStack {
            if let flag = CurrencyArt.flag(for: code) {
                Text(flag)
                    .font(.system(size: size * Self.flagScale))
                    .fixedSize()
                    .offset(x: size * Self.flagOffsetX, y: size * Self.flagOffsetY)
            } else {
                let badge = CurrencyArt.badge(for: code)
                Circle().fill(Color(red: badge.red, green: badge.green, blue: badge.blue).gradient)
                Text(badge.symbol)
                    .font(.system(size: size * (badge.symbol.count > 1 ? 0.4 : 0.52), weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.primary.opacity(0.14), lineWidth: 0.5))
        .accessibilityHidden(true)
    }
}

/// Two overlapping badges. The first is cut out with a real mask, so it works on any material.
struct PairBadge: View {
    let base: String
    let quote: String
    var size: CGFloat = 22
    private var overlap: CGFloat { size * 0.32 }

    var body: some View {
        HStack(spacing: -overlap) {
            CurrencyBadge(code: base, size: size)
                .mask {
                    ZStack {
                        Rectangle()
                        Circle()
                            .frame(width: size + 3, height: size + 3)
                            .offset(x: size - overlap)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
                }
            CurrencyBadge(code: quote, size: size)
        }
    }
}

/// The day's change as a tinted capsule; flat days are gray with no arrow.
struct ChangeBadge: View {
    let percent: Double

    var body: some View {
        let tint: Color = percent > 0 ? .green : percent < 0 ? .red : .secondary
        HStack(spacing: 4) {
            if percent != 0 {
                Image(systemName: percent > 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.system(size: 7))
            }
            Text(verbatim: RateFormat.percent(percent))
            Text("today").foregroundStyle(tint.opacity(0.7))
        }
        .font(.system(size: 11.5, weight: .semibold))
        .monospacedDigit()
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(Capsule().fill(tint.opacity(0.13)))
    }
}

// MARK: - Controls

/// A full-width row: subtle rounded highlight on hover, deeper on press.
struct RowStyle: ButtonStyle {
    var verticalPadding: CGFloat = 6

    func makeBody(configuration: Configuration) -> some View {
        Chrome(configuration: configuration, verticalPadding: verticalPadding)
    }

    private struct Chrome: View {
        let configuration: Configuration
        let verticalPadding: CGFloat
        @State private var hovering = false

        var body: some View {
            configuration.label
                .padding(.horizontal, 10)
                .padding(.vertical, verticalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(configuration.isPressed ? 0.11 : hovering ? 0.06 : 0))
                )
                .contentShape(Rectangle())
                .onHover { inside in
                    withAnimation(.easeOut(duration: 0.12)) { hovering = inside }
                }
        }
    }
}

/// A round icon button, used for "back".
struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Chrome(configuration: configuration)
    }

    private struct Chrome: View {
        let configuration: Configuration
        @State private var hovering = false

        var body: some View {
            configuration.label
                .frame(width: 26, height: 26)
                .background(
                    Circle().fill(Color.primary.opacity(configuration.isPressed ? 0.12 : hovering ? 0.07 : 0))
                )
                .contentShape(Circle())
                .onHover { inside in
                    withAnimation(.easeOut(duration: 0.12)) { hovering = inside }
                }
        }
    }
}

/// A small switch drawn in SwiftUI so it renders everywhere, including screenshots.
struct MiniSwitch: View {
    var isOn: Bool

    var body: some View {
        Capsule()
            .fill(isOn ? Color.accentColor : Color.primary.opacity(0.16))
            .frame(width: 28, height: 16)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.22), radius: 1, y: 0.5)
                    .padding(1.5)
            }
            .animation(.spring(response: 0.3, dampingFraction: 1), value: isOn)
    }
}

// MARK: - Snapshot mode

/// True while rendering screenshots: AppKit-backed views (text fields, scroll views)
/// are swapped for plain SwiftUI so ImageRenderer can draw them.
private struct SnapshotKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isSnapshot: Bool {
        get { self[SnapshotKey.self] }
        set { self[SnapshotKey.self] = newValue }
    }
}
