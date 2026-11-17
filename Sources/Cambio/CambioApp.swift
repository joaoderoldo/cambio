import AppKit
import CambioCore
import SwiftUI

struct CambioApp: App {
    @State private var store: RateStore
    @State private var launchAtLogin = LaunchAtLogin()

    init() {
        let store = RateStore(client: AwesomeAPIClient())
        store.start()
        _store = State(initialValue: store)

        // After sleep the 60 s timer may be far behind; refresh as soon as the network is back.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                await store.refreshIfStale(olderThan: 0)
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            PanelView(store: store, launchAtLogin: launchAtLogin)
        } label: {
            BarLabel(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}
