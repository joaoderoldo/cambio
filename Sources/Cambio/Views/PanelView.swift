import AppKit
import CambioCore
import SwiftUI

/// Where the panel can go after the main page.
enum PanelRoute: Hashable {
    case picker
    case calculator
    case platforms
    case add
    case edit(UUID)
    case newPlatform
    case platformPair(UUID)
    case draftPair
}

/// The window under the menu bar item: the main page plus a stack of pages on top of it.
/// Pages enter and leave from the right; the pages underneath stay in the layout, so the
/// window never jumps size and "back" returns to exactly where you were.
struct PanelView: View {
    let store: RateStore
    let launchAtLogin: LaunchAtLogin
    let platforms: PlatformStore
    @State var path: [PanelRoute] = []
    var pickerSlot: PickerPage.Slot = .base
    /// Pre-filled "rate the platform shows" for screenshots.
    var exampleObservedRate = ""
    /// A custom platform being set up, before it is added.
    @State private var draft = Platform.custom(color: .blue)

    private static let spring = Animation.spring(response: 0.38, dampingFraction: 1)

    var body: some View {
        MainPage(
            store: store,
            launchAtLogin: launchAtLogin,
            platforms: platforms,
            openPicker: { push(.picker) },
            openCalculator: { push(.calculator) }
        )
            .offset(x: path.isEmpty ? 0 : -60)
            .opacity(path.isEmpty ? 1 : 0)
            .allowsHitTesting(path.isEmpty)
            .overlay {
                ZStack {
                    ForEach(Array(path.enumerated()), id: \.element) { index, route in
                        let isTop = index == path.count - 1
                        page(for: route)
                            .offset(x: isTop ? 0 : -60)
                            .opacity(isTop ? 1 : 0)
                            .allowsHitTesting(isTop)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            }
            .clipped()
            .frame(width: 300)
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
                launchAtLogin.refresh()
                Task { await store.refreshIfStale(olderThan: 15) }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
                // Reopening the panel always starts on the main page.
                var instant = Transaction()
                instant.disablesAnimations = true
                withTransaction(instant) { path = [] }
            }
    }

    @ViewBuilder private func page(for route: PanelRoute) -> some View {
        switch route {
        case .picker:
            PickerPage(
                store: store,
                initial: store.pair,
                slot: pickerSlot,
                onSelect: { pair in Task { await store.select(pair) } },
                close: pop
            )
        case .calculator:
            CalculatorPage(
                store: store,
                platforms: platforms,
                edit: { push(platforms.platforms.isEmpty ? .add : .platforms) },
                back: pop
            )
        case .platforms:
            PlatformsPage(platforms: platforms, open: { push(.edit($0)) }, add: { push(.add) }, back: pop)
        case .add:
            AddPlatformPage(
                platforms: platforms,
                addTemplate: { template in
                    platforms.add(template.instantiated())
                    refreshRates()
                    pop()
                },
                custom: {
                    draft = Platform.custom(color: nextColor)
                    push(.newPlatform)
                },
                back: pop
            )
        case .edit(let id):
            EditPlatformPage(
                platform: binding(for: id),
                isNew: false,
                store: store,
                observedRate: exampleObservedRate,
                editPair: { push(.platformPair(id)) },
                add: {},
                remove: {
                    platforms.remove(id: id)
                    pop()
                },
                back: pop
            )
        case .newPlatform:
            EditPlatformPage(
                platform: $draft,
                isNew: true,
                store: store,
                editPair: { push(.draftPair) },
                add: {
                    platforms.add(draft)
                    refreshRates()
                    withAnimation(Self.spring) { path.removeLast(min(2, path.count)) }
                },
                remove: {},
                back: pop
            )
        case .platformPair(let id):
            PickerPage(
                store: store,
                initial: platforms.platform(id: id)?.pair ?? .usdBrl,
                onSelect: { pair in
                    guard var platform = platforms.platform(id: id) else { return }
                    platform.pair = pair
                    platforms.update(platform)
                    refreshRates()
                },
                close: pop
            )
        case .draftPair:
            PickerPage(store: store, initial: draft.pair, onSelect: { draft.pair = $0 }, close: pop)
        }
    }

    /// Edits go straight to the store; invalid ones (e.g. an empty name) are kept out by it.
    private func binding(for id: UUID) -> Binding<Platform> {
        Binding(
            get: { platforms.platform(id: id) ?? draft },
            set: { updated in
                let pairChanged = platforms.platform(id: id)?.pair != updated.pair
                platforms.update(updated)
                if pairChanged { refreshRates() }
            }
        )
    }

    /// The first palette color no platform uses yet.
    private var nextColor: PlatformColor {
        PlatformColor.allCases.first { color in !platforms.platforms.contains { $0.color == color } } ?? .blue
    }

    private func refreshRates() {
        Task { await store.refresh() }
    }

    private func push(_ route: PanelRoute) {
        withAnimation(Self.spring) { path.append(route) }
    }

    private func pop() {
        withAnimation(Self.spring) { _ = path.popLast() }
    }
}
