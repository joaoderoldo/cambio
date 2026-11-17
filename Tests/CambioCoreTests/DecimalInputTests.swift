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

    @Test func rateNearReference() {
        // Platforms often show rates with a dot ("5.723") even for pt_BR users, and vice versa.
        #expect(DecimalInput.parseRate("5.723", near: 5.78, locale: ptBR) == 5.723)
        #expect(DecimalInput.parseRate("5,723", near: 5.78, locale: enUS) == 5.723)
        #expect(DecimalInput.parseRate("5,72386", near: 5.78, locale: ptBR) == 5.72386)
        #expect(DecimalInput.parseRate("5.72386", near: 5.78, locale: ptBR) == 5.72386)
        #expect(DecimalInput.parseRate("abc", near: 5.78, locale: ptBR) == nil)
    }

    @Test func rejectsNonFinite() {
        #expect(DecimalInput.parse(String(repeating: "9", count: 400), locale: ptBR) == nil)
    }
}
