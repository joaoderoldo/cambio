import AppKit
import CambioCore
import SwiftUI

/// The window under the menu bar item. The currency picker slides in from the right and
/// leaves the same way; the main page stays in the layout so the window never jumps size.
struct PanelView: View {
    enum Page { case main, picker }

    let store: RateStore
    let launchAtLogin: LaunchAtLogin
    @State var page: Page = .main
    var pickerSlot: PickerPage.Slot = .base

    var body: some View {
        MainPage(store: store, launchAtLogin: launchAtLogin) { page = .picker }
            .offset(x: page == .picker ? -60 : 0)
            .opacity(page == .picker ? 0 : 1)
            .allowsHitTesting(page == .main)
            .overlay {
                if page == .picker {
                    PickerPage(store: store, close: { page = .main }, slot: pickerSlot)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .clipped()
            .animation(.spring(response: 0.38, dampingFraction: 1), value: page)
            .frame(width: 300)
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
                launchAtLogin.refresh()
                Task { await store.refreshIfStale(olderThan: 15) }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
                // Reopening the panel always starts on the main page.
                var instant = Transaction()
                instant.disablesAnimations = true
                withTransaction(instant) { page = .main }
            }
    }
}
