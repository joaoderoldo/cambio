import Foundation
import Testing
@testable import CambioCore

struct CurrencyPairTests {
    @Test func parsesId() throws {
        let pair = try #require(CurrencyPair(id: "USD-BRL"))
        #expect(pair.base == "USD")
        #expect(pair.quote == "BRL")
    }

    @Test func parsesNonIsoQuote() {
        #expect(CurrencyPair(id: "USD-BRLPTAX")?.quote == "BRLPTAX")
    }

    @Test(arguments: ["USDBRL", "USD-", "-BRL", "A-B-C", ""])
    func rejectsMalformed(_ id: String) {
        #expect(CurrencyPair(id: id) == nil)
    }

    @Test func responseKey() {
        #expect(CurrencyPair.usdBrl.responseKey == "USDBRL")
    }

    @Test func swapped() {
        #expect(CurrencyPair.usdBrl.swapped.id == "BRL-USD")
    }

    @Test func codableRoundTrip() throws {
        let original = CurrencyPair(base: "EUR", quote: "USD")
        let data = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(CurrencyPair.self, from: data) == original)
    }
}
