import Foundation
import Testing
@testable import CambioCore

struct AwesomeAPITests {
    // Real response captured on 2026-11-17.
    static let latestJSON = #"{"USDBRL":{"code":"USD","codein":"BRL","name":"Dólar Americano/Real Brasileiro","high":"5.8106","low":"5.7582","varBid":"-0.008","pctChange":"-0.138311","bid":"5.776","ask":"5.7775","timestamp":"1794925571","create_date":"2026-11-17 11:26:11"}}"#

    @Test func latestDecodes() throws {
        let quote = try AwesomeAPI.decodeLatest(Data(Self.latestJSON.utf8), pair: .usdBrl)
        #expect(quote.pair == .usdBrl)
        #expect(quote.bid == 5.776)
        #expect(quote.high == 5.8106)
        #expect(quote.low == 5.7582)
        #expect(quote.changePercent == -0.138311)
        #expect(quote.timestamp == Date(timeIntervalSince1970: 1_794_925_571))
    }

    @Test func latestMissingPairThrows() {
        #expect(throws: AwesomeAPI.Failure.missingPair("EURBRL")) {
            try AwesomeAPI.decodeLatest(Data(Self.latestJSON.utf8), pair: CurrencyPair(base: "EUR", quote: "BRL"))
        }
    }

    @Test func latestInvalidNumberThrows() {
        let json = #"{"USDBRL":{"bid":"n/a","high":"1","low":"1","pctChange":"0","timestamp":"1794925571"}}"#
        #expect(throws: AwesomeAPI.Failure.invalidNumber("bid")) {
            try AwesomeAPI.decodeLatest(Data(json.utf8), pair: .usdBrl)
        }
    }

    @Test func latestHtmlThrows() {
        #expect(throws: (any Error).self) {
            try AwesomeAPI.decodeLatest(Data("<html>301 Moved</html>".utf8), pair: .usdBrl)
        }
    }

    @Test func latestErrorPayloadThrows() {
        let json = #"{"status":404,"code":"CoinNotExists","message":"moeda nao encontrada USD-XYZ"}"#
        #expect(throws: (any Error).self) {
            try AwesomeAPI.decodeLatest(Data(json.utf8), pair: .usdBrl)
        }
    }

    @Test func historyAscendingAndSkipsBad() throws {
        // Newest first, like the API, with one unparsable entry in the middle.
        let json = #"[{"bid":"5.77","high":"5.8","low":"5.7","timestamp":"1794925189"},{"bid":"abc","timestamp":"1794868960"},{"bid":"5.66","timestamp":"1794605388"}]"#
        let points = try AwesomeAPI.decodeHistory(Data(json.utf8))
        #expect(points.map(\.value) == [5.66, 5.77])
        #expect(points.first?.date == Date(timeIntervalSince1970: 1_794_605_388))
    }

    @Test func urls() {
        #expect(AwesomeAPI.latestURL(for: .usdBrl).absoluteString == "https://economia.awesomeapi.com.br/json/last/USD-BRL")
        #expect(AwesomeAPI.historyURL(for: .usdBrl, days: 30).absoluteString == "https://economia.awesomeapi.com.br/json/daily/USD-BRL/30")
        #expect(AwesomeAPI.pairsURL.absoluteString == "https://economia.awesomeapi.com.br/json/available")
        #expect(AwesomeAPI.namesURL.absoluteString == "https://economia.awesomeapi.com.br/json/available/uniq")
    }

    @Test func catalogDecodes() throws {
        let pairs = #"{"USD-BRL":"Dólar Americano/Real Brasileiro","USD-BRLT":"Dólar Americano/Real Brasileiro Turismo"}"#
        let names = #"{"USD":"Dólar Americano","BRL":"Real Brasileiro","BRLT":"Real Brasileiro Turismo"}"#
        let catalog = try AwesomeAPI.decodeCatalog(pairs: Data(pairs.utf8), names: Data(names.utf8))
        #expect(catalog.pairs == ["USD-BRL", "USD-BRLT"])
        #expect(catalog.apiNames["BRLT"] == "Real Brasileiro Turismo")
    }
}
