import CambioCore
import SwiftUI

/// "How much I receive": type an amount, see what lands through each platform.
struct CalculatorPage: View {
    let store: RateStore
    let platforms: PlatformStore
    let edit: () -> Void
    let back: () -> Void

    @State private var amountText: String
    /// The currency the person picked; falls back when no platform uses it any more.
    @State private var preferredBase: String?
    @Environment(\.isSnapshot) private var isSnapshot

    private static let quickAmounts: [Double] = [1000, 2000, 5000, 10000]

    init(store: RateStore, platforms: PlatformStore, edit: @escaping () -> Void, back: @escaping () -> Void) {
        self.store = store
        self.platforms = platforms
        self.edit = edit
        self.back = back
        _amountText = State(initialValue: Self.text(for: platforms.calculatorAmount))
    }

    private static func text(for amount: Double) -> String {
        RateFormat.number(amount, fractionDigits: 2)
    }

    private var amount: Double { platforms.calculatorAmount }

    private var base: String {
        platforms.baseCurrency(preferring: preferredBase, fallback: store.pair.base)
    }

    private var visible: [Platform] {
        platforms.platforms.filter { $0.pair.base == base }
    }

    private var referencePair: CurrencyPair {
        visible.first?.pair ?? store.pair
    }

    private func received(_ platform: Platform) -> Double? {
        store.quote(for: platform.pair).map { Payout.receive(amount, via: platform, commercial: $0.bid) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavBar("How much I receive", back: back)
            amountCard
                .padding(.horizontal, 14)
                .padding(.top, 8)
            quickChips
                .padding(.horizontal, 14)
                .padding(.top, 8)
            SectionLabel("YOU RECEIVE")
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 2)
            VStack(spacing: 1) {
                commercialRow
                ForEach(visible.sorted { (received($0) ?? -1) > (received($1) ?? -1) }) { platform in
                    platformRow(platform)
                }
            }
            .padding(.horizontal, 6)
            FootNote("Estimate based on the live commercial rate and each platform's fees.")
                .padding(.horizontal, 16)
                .padding(.top, 10)
            Spacer(minLength: 0)
            Divider().padding(.horizontal, 12)
            editButton.padding(6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onExitCommand(perform: back)
    }

    // MARK: Amount

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("YOU SEND")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Color.accentColor)
            HStack(spacing: 8) {
                currencySwitch
                if isSnapshot {
                    Text(verbatim: amountText).modifier(AmountFont())
                    Spacer()
                } else {
                    TextField("", text: $amountText)
                        .textFieldStyle(.plain)
                        .modifier(AmountFont())
                        .onChange(of: amountText) { _, text in
                            if let value = DecimalInput.parse(text) { platforms.calculatorAmount = value }
                        }
                        .onSubmit { amountText = Self.text(for: platforms.calculatorAmount) }
                }
                Text(verbatim: base).font(.system(size: 13, weight: .semibold)).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.accentColor.opacity(0.10)))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.9), lineWidth: 1.5)
        )
    }

    @ViewBuilder private var currencySwitch: some View {
        let bases = platforms.baseCurrencies
        if bases.count > 1, !isSnapshot {
            Menu {
                ForEach(bases, id: \.self) { code in
                    Button(code) { preferredBase = code }
                }
            } label: {
                CurrencyBadge(code: base, size: 22)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        } else {
            CurrencyBadge(code: base, size: 22)
        }
    }

    private var quickChips: some View {
        HStack(spacing: 6) {
            ForEach(Self.quickAmounts, id: \.self) { value in
                let selected = value == amount
                Button {
                    platforms.calculatorAmount = value
                    amountText = Self.text(for: value)
                } label: {
                    Text(verbatim: RateFormat.number(value, fractionDigits: 0))
                        .font(.system(size: 11.5, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(selected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(selected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.05)))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: Results

    private var commercialRow: some View {
        let commercial = store.quote(for: referencePair)?.bid
        return resultRow(
            badge: AnyView(PairBadge(base: referencePair.base, quote: referencePair.quote, size: 22)),
            title: Text("Commercial"),
            subtitle: commercial.map { perUnit($0, pair: referencePair) },
            value: commercial.map { PayoutText.total(amount * $0, quote: referencePair.quote) },
            detail: Text("reference"),
            emphasized: false
        )
    }

    private func platformRow(_ platform: Platform) -> some View {
        let commercial = store.quote(for: platform.pair)?.bid
        let value = received(platform)
        let loss = commercial.flatMap { rate in value.map { amount * rate - $0 } }
        return resultRow(
            badge: AnyView(PlatformBadge(platform: platform, size: 24)),
            title: Text(verbatim: "\(platform.name) · \(platform.method)"),
            subtitle: commercial.map { perUnit(Payout.platformRate(platform, commercial: $0), pair: platform.pair) },
            value: value.map { PayoutText.total($0, quote: platform.pair.quote) },
            detail: loss.map { Text(verbatim: "−" + PayoutText.loss($0, quote: platform.pair.quote)) },
            emphasized: true
        )
    }

    private func perUnit(_ rate: Double, pair: CurrencyPair) -> String {
        String(localized: "\(RateFormat.price(rate, quote: pair.quote)) per \(pair.base)")
    }

    private func resultRow(
        badge: AnyView, title: Text, subtitle: String?, value: String?, detail: Text?, emphasized: Bool
    ) -> some View {
        HStack(spacing: 10) {
            badge
            VStack(alignment: .leading, spacing: 0) {
                title.font(.system(size: 13, weight: emphasized ? .semibold : .medium)).lineLimit(1)
                Text(verbatim: subtitle ?? "—")
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(verbatim: value ?? "—")
                    .font(.system(size: emphasized ? 15 : 13, weight: emphasized ? .semibold : .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(emphasized ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                (detail ?? Text(verbatim: " "))
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(emphasized ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tertiary))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var editButton: some View {
        Button(action: edit) {
            HStack(spacing: 8) {
                if platforms.platforms.isEmpty {
                    Image(systemName: "plus.circle.fill").font(.system(size: 13))
                    Text("Add platform").font(.system(size: 12.5, weight: .medium))
                } else {
                    Image(systemName: "slider.horizontal.3").font(.system(size: 12, weight: .medium))
                    Text("Edit platforms").font(.system(size: 12.5))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(platforms.platforms.isEmpty ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
        }
        .buttonStyle(RowStyle(verticalPadding: 6))
    }
}

private struct AmountFont: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 26, weight: .semibold, design: .rounded))
            .tracking(-0.5)
            .monospacedDigit()
    }
}
