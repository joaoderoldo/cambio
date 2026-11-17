import Foundation
import Testing
@testable import CambioCore

struct CatalogTests {
    let catalog = Catalog(
        pairs: ["USD-BRL", "USD-BRLT", "USD-EUR", "EUR-BRL", "BRL-USD"],
        apiNames: ["USD": "Dólar Americano", "BRL": "Real Brasileiro", "BRLT": "Real Brasileiro Turismo", "EUR": "Euro"]
    )

    @Test func catalogQueries() {
        #expect(catalog.contains(.usdBrl))
        #expect(!catalog.contains(CurrencyPair(base: "BRL", quote: "EUR")))
        #expect(catalog.quotes(for: "USD") == ["BRL", "BRLT", "EUR"])
        #expect(catalog.bases == ["BRL", "EUR", "USD"])
        #expect(Catalog.empty.pairs.isEmpty)
    }

    @Test func displayNames() {
        #expect(catalog.displayName(for: "USD", locale: enUS) == "US Dollar")
        #expect(catalog.displayName(for: "BRLT", locale: enUS) == "Real Brasileiro Turismo")
        #expect(catalog.displayName(for: "ZZZ", locale: enUS) == "ZZZ")
    }

    @Test func searchIgnoresAccentsAndCase() {
        let codes = ["USD", "BRL", "BRLT", "EUR"]
        #expect(catalog.search(codes, query: "dolar", locale: ptBR).contains("USD"))
        #expect(catalog.search(codes, query: "brl", locale: ptBR) == ["BRL", "BRLT"])
        #expect(catalog.search(codes, query: "  ", locale: ptBR) == codes)
    }

    @Test func searchMatchesCountryNames() {
        let codes = ["USD", "MXN", "CHF", "EUR", "BRL", "BTC"]
        #expect(catalog.search(codes, query: "Mexico", locale: enUS) == ["MXN"])
        #expect(catalog.search(codes, query: "estados unidos", locale: ptBR) == ["USD"])
        #expect(catalog.search(codes, query: "Suíça", locale: ptBR) == ["CHF"])
        #expect(catalog.search(codes, query: "europe", locale: enUS) == ["EUR"])
    }
}
