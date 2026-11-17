import Foundation
import Testing
@testable import CambioCore

struct DecimalInputTests {
    @Test(arguments: [
        ("5,72386", 5.72386), ("5.72386", 5.72386), ("1.000,50", 1000.5), ("1,000.50", 1000.5),
        ("1,2", 1.2), (" 1,20 % ", 1.2), ("US$ 5.000", 5000.0), ("12", 12.0),
        ("1.000.000", 1_000_000.0), ("R$ 12.345,67", 12345.67),
    ])
    func parsesDecimals(text: String, expected: Double) {
        #expect(DecimalInput.parse(text, locale: ptBR) == expected)
    }

    @Test(arguments: ["abc", "1,2,3,4", "", "5..2", "1.2.3,4,5", "-", "%"])
    func rejectsGarbage(text: String) {
        #expect(DecimalInput.parse(text, locale: ptBR) == nil)
    }

    @Test func parsesEnUS() {
        #expect(DecimalInput.parse("5.000", locale: enUS) == 5.0)
        #expect(DecimalInput.parse("5,000", locale: enUS) == 5000)
    }
}
