import Foundation
import Testing
@testable import CambioCore

struct RateFormatTests {
    @Test func fractionDigitsByRange() {
        #expect(RateFormat.fractionDigits(for: 5.7, compact: true) == 2)
        #expect(RateFormat.fractionDigits(for: 5.7, compact: false) == 4)
        #expect(RateFormat.fractionDigits(for: 0.0384, compact: true) == 4)
        #expect(RateFormat.fractionDigits(for: 0.0384, compact: false) == 6)
        #expect(RateFormat.fractionDigits(for: 512_345.6, compact: true) == 0)
        #expect(RateFormat.fractionDigits(for: 512_345.6, compact: false) == 2)
    }

    @Test func barTextPtBR() {
        #expect(RateFormat.barText(base: "USD", value: 5.776, changePercent: -0.13, locale: ptBR) == "USD 5,78 ▾")
    }

    @Test func barTextEnUS() {
        #expect(RateFormat.barText(base: "USD", value: 5.776, changePercent: 0.2, locale: enUS) == "USD 5.78 ▴")
    }

    @Test func barTextFlatAndMissing() {
        #expect(RateFormat.barText(base: "USD", value: 5.776, changePercent: 0, locale: ptBR) == "USD 5,78")
        #expect(RateFormat.barText(base: "USD", value: 5.776, changePercent: nil, locale: ptBR) == "USD 5,78")
        #expect(RateFormat.barText(base: "USD", value: nil, changePercent: nil, locale: ptBR) == "USD —")
    }

    @Test func smallAndLargeValues() {
        #expect(RateFormat.barText(base: "JPY", value: 0.0384, changePercent: nil, locale: ptBR) == "JPY 0,0384")
        #expect(RateFormat.barText(base: "BTC", value: 512_345.6, changePercent: nil, locale: ptBR) == "BTC 512.346")
    }

    @Test func tinyValuesKeepSignificantDigits() {
        #expect(RateFormat.barText(base: "IRR", value: 5.3e-7, changePercent: nil, locale: ptBR) == "IRR 0,000000530")
        #expect(RateFormat.barText(base: "VND", value: 0.0000389, changePercent: nil, locale: ptBR) == "VND 0,0000389")
        #expect(RateFormat.barText(base: "PYG", value: 0.000156, changePercent: nil, locale: ptBR) == "PYG 0,000156")
        #expect(RateFormat.fractionDigits(for: 5.3e-7, compact: false) == 10)
        #expect(RateFormat.fractionDigits(for: 0, compact: true) == 2)
    }

    @Test func pricePtBR() {
        #expect(plain(RateFormat.price(5.776, quote: "BRL", locale: ptBR)) == "R$ 5,7760")
        #expect(plain(RateFormat.price(5.776, quote: "BRLPTAX", locale: ptBR)).hasPrefix("R$"))
    }

    @Test func percent() {
        #expect(RateFormat.percent(-0.138311, locale: ptBR) == "0,14%")
        #expect(RateFormat.percent(2.05738, locale: enUS) == "2.06%")
    }

    @Test func moneyWithChosenDigits() {
        #expect(plain(RateFormat.money(5.6574, code: "BRL", fractionDigits: 2, locale: ptBR)) == "R$ 5,66")
        #expect(plain(RateFormat.money(28282.4, code: "BRL", fractionDigits: 0, locale: ptBR)) == "R$ 28.282")
        #expect(plain(RateFormat.money(5.6574, code: "BRLPTAX", fractionDigits: 2, locale: ptBR)) == "R$ 5,66")
    }

    @Test func percentWithOneDecimal() {
        #expect(RateFormat.percent(2.188, fractionDigits: 1, locale: ptBR) == "2,2%")
        #expect(RateFormat.percent(-0.2, fractionDigits: 1, locale: ptBR) == "0,2%")
    }
}
