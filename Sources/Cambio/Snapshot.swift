import AppKit
import CambioCore
import SwiftUI

/// Renders the README screenshots with live data, light and dark: main page, currency picker,
/// calculator, platforms and edit. Edge cases (zero and one platform) guard the layout.
@MainActor
enum Snapshot {
    static func render(to directory: URL, edgeCases: Bool = false) async {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // In-memory settings, so screenshots never touch the real ones or write files.
        let platforms = PlatformStore(settings: InMemorySettings())
        platforms.add(Platform.deelPix.instantiated())
        platforms.add(Platform.higlobePix.instantiated())
        platforms.calculatorAmount = 5000
        let store = RateStore(client: AwesomeAPIClient(), defaults: InMemorySettings(), extraPairs: { platforms.pairs })
        await store.loadCatalog()
        await store.refresh()
        let launchAtLogin = LaunchAtLogin(forced: true)
        let deel = platforms.platforms[0].id

        let shots: [(name: String, scheme: ColorScheme, path: [PanelRoute], slot: PickerPage.Slot)] = [
            ("main-light", .light, [], .base),
            ("main-dark", .dark, [], .base),
            ("picker-light", .light, [.picker], .base),
            ("picker-dark", .dark, [.picker], .quote),
            ("calculator-light", .light, [.calculator], .base),
            ("calculator-dark", .dark, [.calculator], .base),
            ("platforms-light", .light, [.platforms], .base),
            ("platforms-dark", .dark, [.platforms], .base),
            ("edit-light", .light, [.edit(deel)], .base),
            ("edit-dark", .dark, [.edit(deel)], .base),
        ]
        for shot in shots {
            write(PanelView(
                store: store,
                launchAtLogin: launchAtLogin,
                platforms: platforms,
                path: shot.path,
                pickerSlot: shot.slot,
                exampleObservedRate: RateFormat.number(5.72386, fractionDigits: 5)
            ), scheme: shot.scheme, to: directory.appendingPathComponent("\(shot.name).png"))
        }

        guard edgeCases else { return }
        let none = PlatformStore(settings: InMemorySettings())
        let one = PlatformStore(settings: InMemorySettings())
        one.add(Platform.deelPix.instantiated())
        let edges: [(name: String, platforms: PlatformStore, path: [PanelRoute])] = [
            ("edge-0-main", none, []),
            ("edge-0-calculator", none, [.calculator]),
            ("edge-0-new", none, [.newPlatform]),
            ("edge-1-edit", one, [.edit(one.platforms[0].id)]),
            ("edge-1-new", one, [.newPlatform]),
        ]
        for edge in edges {
            write(PanelView(store: store, launchAtLogin: launchAtLogin, platforms: edge.platforms, path: edge.path),
                  scheme: .light, to: directory.appendingPathComponent("\(edge.name).png"))
        }

        // PTAX is published once a day: the status line must show both times.
        let ptax = RateStore(client: AwesomeAPIClient(), defaults: InMemorySettings())
        await ptax.loadCatalog()
        await ptax.select(CurrencyPair(base: "USD", quote: "BRLPTAX"))
        write(PanelView(store: ptax, launchAtLogin: launchAtLogin, platforms: none),
              scheme: .light, to: directory.appendingPathComponent("edge-ptax-main.png"))
    }

    private static func write(_ panel: PanelView, scheme: ColorScheme, to file: URL) {
        let dark = scheme == .dark
        let scene = panel
            .background(dark ? Color(red: 0.165, green: 0.165, blue: 0.175) : Color(red: 0.965, green: 0.965, blue: 0.965))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
            .padding(28)
            .background(dark ? Color(white: 0.06) : Color(white: 0.80))
            .environment(\.colorScheme, scheme)
            .environment(\.isSnapshot, true)

        let renderer = ImageRenderer(content: scene)
        renderer.scale = 2
        if let tiff = renderer.nsImage?.tiffRepresentation,
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            try? png.write(to: file)
        }
    }
}
