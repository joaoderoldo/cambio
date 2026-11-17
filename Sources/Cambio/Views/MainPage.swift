import CambioCore
import SwiftUI

/// Price, today's range, the 30-day chart, and the few controls the app has.
struct MainPage: View {
    let store: RateStore
    let launchAtLogin: LaunchAtLogin
    let platforms: PlatformStore
    let openPicker: () -> Void
    let openCalculator: () -> Void
    @State private var spin = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)
            RateChart(points: store.history)
                .padding(.horizontal, 16)
            status
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 10)
            Divider().padding(.horizontal, 12)
            if !platforms.platforms.isEmpty {
                ReceivingSection(store: store, platforms: platforms.platforms, open: openCalculator).padding(6)
                Divider().padding(.horizontal, 12)
            }
            controls.padding(6)
            Divider().padding(.horizontal, 12)
            footer
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
        }
    }

    private var title: String {
        let catalog = store.catalog
        return "\(catalog.displayName(for: store.pair.base)) → \(catalog.displayName(for: store.pair.quote))"
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            HStack(alignment: .center) {
                Text(verbatim: store.quote.map { RateFormat.price($0.bid, quote: store.pair.quote) } ?? "—")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .tracking(-0.6)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .opacity(store.isOffline ? 0.5 : 1)
                    .animation(.snappy, value: store.quote?.bid)
                Spacer()
                if let quote = store.quote {
                    ChangeBadge(percent: quote.changePercent)
                }
            }
            if let quote = store.quote {
                let digits = RateFormat.fractionDigits(for: quote.bid, compact: false)
                let low = RateFormat.number(quote.low, fractionDigits: digits)
                let high = RateFormat.number(quote.high, fractionDigits: digits)
                Text("Today: low \(low) · high \(high)")
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var status: some View {
        HStack(spacing: 5) {
            Text("30 days")
            Spacer()
            if store.isOffline {
                Text("Offline").foregroundStyle(.orange)
                if store.quote != nil { Text(verbatim: "·") }
            }
            if let quote = store.quote {
                switch RateFormat.freshness(quoteTime: quote.timestamp, checkedAt: store.lastChecked) {
                case .live(let time):
                    Text("Updated at \(RateFormat.clockTime(time))")
                case .published(let time, let checked):
                    // e.g. PTAX, published once a day: show that Refresh did check.
                    Text("Rate from \(RateFormat.clockTime(time)) · checked \(RateFormat.clockTime(checked))")
                }
            }
        }
        .font(.system(size: 11))
        .monospacedDigit()
        .foregroundStyle(.secondary)
    }

    private var controls: some View {
        VStack(spacing: 2) {
            Button(action: openPicker) {
                HStack(spacing: 10) {
                    PairBadge(base: store.pair.base, quote: store.pair.quote, size: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: "\(store.pair.base) → \(store.pair.quote)")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Switch currency")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(RowStyle(verticalPadding: 7))

            Button {
                launchAtLogin.setEnabled(!launchAtLogin.isEnabled)
            } label: {
                HStack {
                    Text("Open at login").font(.system(size: 13))
                    Spacer()
                    MiniSwitch(isOn: launchAtLogin.isEnabled)
                }
            }
            .buttonStyle(RowStyle(verticalPadding: 7))

            if platforms.platforms.isEmpty {
                PayoutEntryRow(open: openCalculator)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.6, dampingFraction: 1)) { spin += 360 }
                Task { await store.refresh() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise").rotationEffect(.degrees(spin))
                    Text("Refresh")
                    Text(verbatim: "⌘R").foregroundStyle(.tertiary)
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }
            .buttonStyle(RowStyle(verticalPadding: 5))
            .fixedSize()
            .keyboardShortcut("r", modifiers: .command)

            Spacer()

            Button {
                NSApp.terminate(nil)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "power")
                    Text("Quit")
                    Text(verbatim: "⌘Q").foregroundStyle(.tertiary)
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }
            .buttonStyle(RowStyle(verticalPadding: 5))
            .fixedSize()
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
