import Testing
@testable import CambioCore

struct CurrencyArtTests {
    @Test(arguments: [("USD", "🇺🇸"), ("EUR", "🇪🇺"), ("BRLT", "🇧🇷"), ("BRLPTAX", "🇧🇷"), ("JPY", "🇯🇵")])
    func flags(code: String, flag: String) {
        #expect(CurrencyArt.flag(for: code) == flag)
    }

    @Test(arguments: ["BTC", "XAU", "XCD", "DOGE", "SOL", "BNB", "USDT", "SDR", "XBR"])
    func noFlag(code: String) {
        #expect(CurrencyArt.flag(for: code) == nil)
    }

    @Test func badges() {
        #expect(CurrencyArt.badge(for: "BTC").symbol == "₿")
        #expect(CurrencyArt.badge(for: "XAU").symbol == "Au")
        #expect(CurrencyArt.badge(for: "SOL").symbol == "◎")
        #expect(CurrencyArt.badge(for: "USDT").symbol == "₮")
        let generic = CurrencyArt.badge(for: "ANG")
        #expect(generic.symbol == "A")
        #expect(generic.red == 0.55 && generic.green == 0.55 && generic.blue == 0.55)
    }
}
