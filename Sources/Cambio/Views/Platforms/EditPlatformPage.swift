import CambioCore
import SwiftUI

/// Edit a platform's fees, or set up a new one. Valid edits are saved as they are typed.
struct EditPlatformPage: View {
    @Binding var platform: Platform
    let isNew: Bool
    let store: RateStore
    let editPair: () -> Void
    let add: () -> Void
    let remove: () -> Void
    let back: () -> Void

    @State private var name: String
    @State private var method: String
    @State private var fee: String
    @State private var fixed: String
    @State private var spread: String
    @State private var observedRate: String
    @State private var confirmRemove = false
    @Environment(\.isSnapshot) private var isSnapshot

    init(
        platform: Binding<Platform>,
        isNew: Bool,
        store: RateStore,
        observedRate: String = "",
        editPair: @escaping () -> Void,
        add: @escaping () -> Void,
        remove: @escaping () -> Void,
        back: @escaping () -> Void
    ) {
        _platform = platform
        self.isNew = isNew
        self.store = store
        self.editPair = editPair
        self.add = add
        self.remove = remove
        self.back = back
        let current = platform.wrappedValue
        _name = State(initialValue: current.name)
        _method = State(initialValue: current.method)
        _fee = State(initialValue: Self.text(current.feePercent))
        _fixed = State(initialValue: Self.text(current.fixedFee))
        _spread = State(initialValue: Self.text(current.spreadPercent))
        _observedRate = State(initialValue: observedRate)
    }

    private static func text(_ value: Double) -> String {
        RateFormat.number(value, fractionDigits: 2)
    }

    private static func parsed(_ text: String, in range: ClosedRange<Double>) -> Double? {
        DecimalInput.parse(text).flatMap { range.contains($0) ? $0 : nil }
    }

    private var commercial: Double? { store.quote(for: platform.pair)?.bid }

    /// Calibrating needs the commercial rate of this minute, not a cached one.
    private var hasLiveRate: Bool { commercial != nil && store.isFresh(platform.pair, within: 120) }

    private var computedSpread: Double? {
        guard hasLiveRate, let commercial,
              let rate = DecimalInput.parseRate(observedRate, near: commercial)
        else { return nil }
        return Payout.spread(platformRate: rate, commercial: commercial)
    }

    private var title: String {
        let trimmed = platform.name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? String(localized: "New platform") : "\(trimmed) · \(platform.method)"
    }

    var body: some View {
        // Title and action stay pinned; the form scrolls when the panel is short (0–1 platforms).
        VStack(alignment: .leading, spacing: 0) {
            NavBar(verbatim: title, back: back)
            ScrollIfLive {
                VStack(alignment: .leading, spacing: 0) {
                    fields
                        .padding(.horizontal, 14)
                        .padding(.top, 8)
                    calibration
                        .padding(.horizontal, 14)
                        .padding(.top, 8)
                }
                .padding(.bottom, 4)
            }
            bottomAction
                .padding(.top, 4)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onExitCommand(perform: back)
        .task(id: platform.pair) {
            if !store.isFresh(platform.pair, within: 60) { await store.fetchQuote(for: platform.pair) }
        }
        .onChange(of: name) { _, value in platform.name = value }
        .onChange(of: method) { _, value in platform.method = value }
        .onChange(of: fee) { _, value in
            if let number = Self.parsed(value, in: 0...50) { platform.feePercent = number }
        }
        .onChange(of: fixed) { _, value in
            if let number = Self.parsed(value, in: 0...1_000_000) { platform.fixedFee = number }
        }
        .onChange(of: spread) { _, value in
            if let number = Self.parsed(value, in: 0...50) { platform.spreadPercent = number }
        }
    }

    // MARK: Fields

    private var fields: some View {
        VStack(spacing: 0) {
            field("Name", text: $name, valid: !name.trimmingCharacters(in: .whitespaces).isEmpty, alignment: .trailing)
            Divider().padding(.leading, 12)
            field("Method", text: $method, valid: true, alignment: .trailing)
            Divider().padding(.leading, 12)
            Button(action: editPair) {
                HStack(spacing: 6) {
                    Text("Currencies").font(.system(size: 12.5))
                    Spacer()
                    PairBadge(base: platform.pair.base, quote: platform.pair.quote, size: 16)
                    Text(verbatim: "\(platform.pair.base) → \(platform.pair.quote)").font(.system(size: 12.5, weight: .medium))
                    Image(systemName: "chevron.right").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Divider().padding(.leading, 12)
            field("Fee on amount", text: $fee, valid: Self.parsed(fee, in: 0...50) != nil, suffix: "%")
            Divider().padding(.leading, 12)
            field("Fixed fee", text: $fixed, valid: Self.parsed(fixed, in: 0...1_000_000) != nil, prefix: platform.pair.base)
            Divider().padding(.leading, 12)
            field("Exchange spread", text: $spread, valid: Self.parsed(spread, in: 0...50) != nil, suffix: "%")
        }
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.045)))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func field(
        _ label: LocalizedStringKey,
        text: Binding<String>,
        valid: Bool,
        prefix: String? = nil,
        suffix: String? = nil,
        alignment: TextAlignment = .trailing
    ) -> some View {
        HStack {
            Text(label).font(.system(size: 12.5))
            Spacer()
            HStack(spacing: 4) {
                if let prefix { Text(verbatim: prefix).foregroundStyle(.tertiary) }
                if isSnapshot {
                    Text(verbatim: text.wrappedValue)
                } else {
                    TextField("", text: text)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(alignment)
                }
                if let suffix { Text(verbatim: suffix).foregroundStyle(.tertiary) }
            }
            .font(.system(size: 12.5, weight: .medium))
            .monospacedDigit()
            .padding(.horizontal, 8)
            .frame(width: 128, height: 22, alignment: .trailing)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary.opacity(0.06)))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(valid ? Color.clear : Color.red.opacity(0.7), lineWidth: 1)
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }

    // MARK: Calibration

    private var calibration: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "scope").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.accentColor)
                Text("Adjust from the platform's current rate")
                    .font(.system(size: 12.5, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            calibrationHint
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text(verbatim: platform.pair.quote).foregroundStyle(.tertiary)
                    if isSnapshot {
                        Text(verbatim: observedRate)
                    } else {
                        TextField("", text: $observedRate).textFieldStyle(.plain)
                    }
                    Spacer()
                }
                .font(.system(size: 13, weight: .medium))
                .monospacedDigit()
                .padding(.horizontal, 9)
                .frame(height: 28)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.primary.opacity(0.07)))
                Button {
                    guard let computedSpread else { return }
                    platform.spreadPercent = computedSpread
                    spread = Self.text(computedSpread)
                } label: {
                    Text("Apply")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .fixedSize()
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background(Capsule().fill(Color.accentColor.opacity(computedSpread == nil ? 0.4 : 1)))
                }
                .buttonStyle(.plain)
                .disabled(computedSpread == nil)
            }
            HStack(spacing: 5) {
                Image(systemName: "arrow.turn.down.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
                if hasLiveRate, let commercial {
                    if let computedSpread {
                        Text("spread \(RateFormat.percent(computedSpread)) · commercial now \(RateFormat.number(commercial, fractionDigits: 4))")
                    } else {
                        Text("commercial now \(RateFormat.number(commercial, fractionDigits: 4))")
                    }
                } else {
                    Text("No live commercial rate right now")
                }
            }
            .font(.system(size: 11.5))
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.accentColor.opacity(0.06)))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 1)
        )
    }

    private var calibrationHint: Text {
        let name = platform.name.trimmingCharacters(in: .whitespaces)
        return name.isEmpty
            ? Text("Type the rate the platform is showing. Cambio compares it with this minute's commercial rate.")
            : Text("Type the rate \(name) is showing. Cambio compares it with this minute's commercial rate.")
    }

    // MARK: Add or remove

    @ViewBuilder private var bottomAction: some View {
        HStack {
            Spacer()
            if isNew {
                Button(action: add) {
                    Text("Add")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .frame(height: 28)
                        .background(Capsule().fill(Color.accentColor.opacity(platform.isValid ? 1 : 0.4)))
                }
                .buttonStyle(.plain)
                .disabled(!platform.isValid)
            } else {
                Button {
                    if confirmRemove {
                        remove()
                    } else {
                        withAnimation(.easeOut(duration: 0.15)) { confirmRemove = true }
                    }
                } label: {
                    Text(confirmRemove ? "Confirm removal" : "Remove platform")
                        .font(.system(size: 12, weight: confirmRemove ? .semibold : .medium))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.red.opacity(confirmRemove ? 0.12 : 0)))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
}
