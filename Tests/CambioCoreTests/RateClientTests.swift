import Foundation
import Testing
@testable import CambioCore

actor RequestLog {
    private(set) var requests: [URLRequest] = []
    func add(_ request: URLRequest) { requests.append(request) }
}

struct RateClientTests {
    func respond(_ status: Int, _ body: String, log: RequestLog? = nil) -> AwesomeAPIClient.Loader {
        { request in
            await log?.add(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (Data(body.utf8), response)
        }
    }

    @Test func clientNon2xxThrows() async {
        let client = AwesomeAPIClient(load: respond(429, "Too Many Requests"))
        await #expect(throws: URLError.self) { try await client.latest(.usdBrl) }
    }

    @Test func clientDecodesLatestWithShortTimeout() async throws {
        let log = RequestLog()
        let client = AwesomeAPIClient(load: respond(200, AwesomeAPITests.latestJSON, log: log))
        let quote = try await client.latest(.usdBrl)
        #expect(quote.bid == 5.776)
        let request = try #require(await log.requests.first)
        #expect(request.url == AwesomeAPI.latestURL(for: .usdBrl))
        #expect(request.timeoutInterval == 15)
        #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
    }

    @Test func catalogFetchesBothEndpoints() async throws {
        let log = RequestLog()
        let client = AwesomeAPIClient(load: { request in
            await log.add(request)
            let body = request.url == AwesomeAPI.pairsURL ? #"{"USD-BRL":"x"}"# : #"{"USD":"Dólar Americano"}"#
            return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        let catalog = try await client.catalog()
        #expect(catalog.pairs == ["USD-BRL"])
        #expect(Set(await log.requests.compactMap(\.url)) == [AwesomeAPI.pairsURL, AwesomeAPI.namesURL])
    }
}
