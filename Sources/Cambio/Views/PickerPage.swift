import CambioCore
import SwiftUI

/// Second page of the panel: pick FROM, then TO, from the pairs the API actually offers.
struct PickerPage: View {
    enum Slot { case base, quote }

    let store: RateStore
    let close: () -> Void
    @State private var slot: Slot
    @State private var draftBase: String
    @State private var draftQuote: String?
    @State private var query = ""
    @Environment(\.isSnapshot) private var isSnapshot

    private static let spring = Animation.spring(response: 0.3, dampingFraction: 1)

    init(store: RateStore, close: @escaping () -> Void, slot: Slot = .base) {
        self.store = store
        self.close = close
        _slot = State(initialValue: slot)
        _draftBase = State(initialValue: store.pair.base)
        _draftQuote = State(initialValue: store.pair.quote)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            navigationBar
                .padding(.horizontal, 8)
                .padding(.top, 8)
            slots
                .padding(.horizontal, 14)
                .padding(.top, 6)
            searchField
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 4)
            list
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onExitCommand(perform: close)
        .task {
            if store.catalog.pairs.isEmpty { await store.loadCatalog() }
        }
    }

    // MARK: Header

    private var navigationBar: some View {
        ZStack {
            Text("Currency").font(.system(size: 13, weight: .semibold))
            HStack {
                Button(action: close) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(IconButtonStyle())
                .accessibilityLabel(Text("Currency"))
                Spacer()
            }
        }
    }

    private var slots: some View {
        ZStack {
            HStack(spacing: 8) {
                SlotCard(
                    label: "FROM",
                    code: draftBase,
                    name: Text(verbatim: store.catalog.displayName(for: draftBase)),
                    active: slot == .base
                ) {
                    withAnimation(Self.spring) { slot = .base; query = "" }
                }
                SlotCard(
                    label: "TO",
                    code: draftQuote,
                    name: draftQuote.map { Text(verbatim: store.catalog.displayName(for: $0)) } ?? Text("Destination currency"),
                    active: slot == .quote
                ) {
                    withAnimation(Self.spring) { slot = .quote; query = "" }
                }
            }
            swapButton
        }
    }

    private var canSwap: Bool {
        guard let quote = draftQuote else { return false }
        return store.catalog.contains(CurrencyPair(base: quote, quote: draftBase))
    }

    private var swapButton: some View {
        Button {
            guard let quote = draftQuote, canSwap else { return }
            let base = draftBase
            withAnimation(.spring(response: 0.35, dampingFraction: 1)) {
                draftBase = quote
                draftQuote = base
            }
            Task { await store.select(CurrencyPair(base: quote, quote: base)) }
        } label: {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(canSwap ? AnyShapeStyle(.primary) : AnyShapeStyle(.quaternary))
                .frame(width: 24, height: 24)
                .background(Circle().fill(.background))
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .disabled(!canSwap)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            if isSnapshot {
                Text("Search currency or country").foregroundStyle(.tertiary)
                Spacer()
            } else {
                TextField("Search currency or country", text: $query)
                    .textFieldStyle(.plain)
            }
        }
        .font(.system(size: 13))
        .padding(.horizontal, 9)
        .frame(height: 28)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.06)))
    }

    // MARK: List

    private var candidates: [String] {
        let catalog = store.catalog
        let codes = slot == .base ? catalog.bases : catalog.quotes(for: draftBase)
        return catalog.search(codes, query: query)
    }

    private var selectedCode: String? { slot == .base ? draftBase : draftQuote }

    @ViewBuilder private var list: some View {
        let codes = candidates
        let searching = !query.trimmingCharacters(in: .whitespaces).isEmpty
        let popular = searching ? [] : CurrencyArt.popular.filter(codes.contains)
        let rest = codes.filter { !popular.contains($0) }.sorted {
            store.catalog.displayName(for: $0).localizedCompare(store.catalog.displayName(for: $1)) == .orderedAscending
        }

        let content = VStack(alignment: .leading, spacing: 1) {
            if codes.isEmpty {
                Text("No currency found")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
            } else if popular.isEmpty {
                ForEach(rest, id: \.self, content: row)
            } else {
                sectionHeader("Popular")
                ForEach(popular, id: \.self, content: row)
                sectionHeader("All currencies")
                ForEach(rest, id: \.self, content: row)
            }
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 8)

        if isSnapshot {
            content.frame(minHeight: 0, maxHeight: .infinity, alignment: .top).clipped()
        } else {
            ScrollView { content }.scrollIndicators(.never)
        }
    }

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 3)
    }

    private func row(_ code: String) -> some View {
        Button {
            choose(code)
        } label: {
            HStack(spacing: 10) {
                CurrencyBadge(code: code, size: 22)
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: code).font(.system(size: 13, weight: .semibold))
                    Text(verbatim: store.catalog.displayName(for: code))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if code == selectedCode {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .buttonStyle(RowStyle(verticalPadding: 5))
    }

    /// FROM moves focus to TO (keeping TO if the pair still exists); TO applies and closes.
    private func choose(_ code: String) {
        switch slot {
        case .base:
            let keptQuote = draftQuote.flatMap { store.catalog.contains(CurrencyPair(base: code, quote: $0)) ? $0 : nil }
            withAnimation(Self.spring) {
                draftBase = code
                draftQuote = keptQuote
                slot = .quote
                query = ""
            }
            if let keptQuote {
                Task { await store.select(CurrencyPair(base: code, quote: keptQuote)) }
            }
        case .quote:
            draftQuote = code
            let pair = CurrencyPair(base: draftBase, quote: code)
            Task { await store.select(pair) }
            close()
        }
    }
}

/// One side of the pair (FROM or TO). The active side is outlined in the accent color.
private struct SlotCard: View {
    let label: LocalizedStringKey
    let code: String?
    let name: Text
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(active ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
                HStack(spacing: 7) {
                    if let code {
                        CurrencyBadge(code: code, size: 20)
                        Text(verbatim: code).font(.system(size: 15, weight: .semibold))
                    } else {
                        Circle()
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [2.5, 2.5]))
                            .foregroundStyle(.tertiary)
                            .frame(width: 20, height: 20)
                        Text("Choose").font(.system(size: 15, weight: .semibold)).foregroundStyle(.tertiary)
                    }
                }
                name
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(active ? Color.accentColor.opacity(0.10) : Color.primary.opacity(0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(active ? Color.accentColor.opacity(0.9) : Color.primary.opacity(0.08), lineWidth: active ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
