import AppKit
import CambioCore
import SwiftUI

/// Renders the README screenshots with live data: main page and picker, light and dark.
@MainActor
enum Snapshot {
    static func render(to directory: URL) async {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // In-memory settings, so screenshots never touch the real ones or write files.
        let store = RateStore(client: AwesomeAPIClient(), defaults: InMemorySettings())
        await store.loadCatalog()
        await store.refresh()
        let launchAtLogin = LaunchAtLogin(forced: true)

        let shots: [(name: String, scheme: ColorScheme, path: [PanelRoute], slot: PickerPage.Slot)] = [
            ("main-light", .light, [], .base),
            ("main-dark", .dark, [], .base),
            ("picker-light", .light, [.picker], .base),
            ("picker-dark", .dark, [.picker], .quote),
        ]
        for shot in shots {
            let dark = shot.scheme == .dark
            let scene = PanelView(store: store, launchAtLogin: launchAtLogin, path: shot.path, pickerSlot: shot.slot)
                .background(dark ? Color(red: 0.165, green: 0.165, blue: 0.175) : Color(red: 0.965, green: 0.965, blue: 0.965))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
                .padding(28)
                .background(dark ? Color(white: 0.06) : Color(white: 0.80))
                .environment(\.colorScheme, shot.scheme)
                .environment(\.isSnapshot, true)

            let renderer = ImageRenderer(content: scene)
            renderer.scale = 2
            if let tiff = renderer.nsImage?.tiffRepresentation,
               let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                try? png.write(to: directory.appendingPathComponent("\(shot.name).png"))
            }
        }
    }
}
