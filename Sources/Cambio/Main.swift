import AppKit

@main
enum Main {
    /// `Cambio --snapshot <dir>` renders the README screenshots and exits.
    /// Add `--edge-cases` to also render layouts with zero and one platform (layout checks).
    @MainActor
    static func main() {
        let args = CommandLine.arguments
        if let index = args.firstIndex(of: "--snapshot"), index + 1 < args.count {
            let directory = URL(fileURLWithPath: args[index + 1], isDirectory: true)
            NSApplication.shared.setActivationPolicy(.prohibited)
            Task { @MainActor in
                await Snapshot.render(to: directory, edgeCases: args.contains("--edge-cases"))
                exit(0)
            }
            NSApplication.shared.run()
        } else {
            CambioApp.main()
        }
    }
}
