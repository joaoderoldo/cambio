import AppKit
import CambioCore
import SwiftUI

/// Where the panel can go after the main page.
enum PanelRoute: Hashable {
    case picker
}

/// The window under the menu bar item: the main page plus a stack of pages on top of it.
/// Pages enter and leave from the right; the pages underneath stay in the layout, so the
/// window never jumps size and "back" returns to exactly where you were.
struct PanelView: View {
    let store: RateStore
    let launchAtLogin: LaunchAtLogin
    @State var path: [PanelRoute] = []
    var pickerSlot: PickerPage.Slot = .base

    private static let spring = Animation.spring(response: 0.38, dampingFraction: 1)

    var body: some View {
        MainPage(store: store, launchAtLogin: launchAtLogin) { push(.picker) }
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
        }
    }

    private func push(_ route: PanelRoute) {
        withAnimation(Self.spring) { path.append(route) }
    }

    private func pop() {
        withAnimation(Self.spring) { _ = path.popLast() }
    }
}
