import CambioCore
import SwiftUI

/// On the main page: each platform's rate next to how much it costs against the commercial one.
struct ReceivingSection: View {
    let store: RateStore
    let platforms: [Platform]
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    SectionLabel("RECEIVING VIA")
                    Spacer()
                    HStack(spacing: 3) {
                        Text("Simulate")
                        Image(systemName: "chevron.right").font(.system(size: 8.5, weight: .bold))
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                }
                ForEach(platforms) { platform in
                    row(platform)
                }
            }
        }
        .buttonStyle(RowStyle(verticalPadding: 9))
    }

    private func row(_ platform: Platform) -> some View {
        HStack(spacing: 10) {
            PlatformBadge(platform: platform, size: 24)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: platform.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Text(verbatim: platform.method).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(verbatim: store.quote(for: platform.pair).map {
                    PayoutText.rate(Payout.platformRate(platform, commercial: $0.bid), quote: platform.pair.quote)
                } ?? "—")
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                Text(verbatim: PayoutText.cost(platform))
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Shown instead of the section while no platform is set up.
struct PayoutEntryRow: View {
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack {
                Text("How much will I receive?").font(.system(size: 13))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(RowStyle(verticalPadding: 7))
    }
}
