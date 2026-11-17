import Foundation
import Testing
@testable import CambioCore

struct PlatformTests {
    @Test func platformValidityAndMonogram() {
        #expect(Platform.deelPix.isValid)
        var platform = Platform.deelPix
        platform.name = "  "
        #expect(!platform.isValid)
        platform = .deelPix
        platform.feePercent = 60
        #expect(!platform.isValid)
        platform = .deelPix
        platform.fixedFee = -1
        #expect(!platform.isValid)
        #expect(Platform.deelPix.monogram == "d")
        #expect(Platform.higlobePix.monogram == "h")
        #expect(Platform.custom(color: .teal).monogram == "?")
    }

    @Test func templatesMatchMeasurements() {
        let deel = Platform.deelPix
        #expect(deel.name == "Deel" && deel.method == "Pix" && deel.pair == .usdBrl && deel.color == .purple)
        #expect(deel.feePercent == 1.2 && deel.fixedFee == 0 && deel.spreadPercent == 1.0)
        let higlobe = Platform.higlobePix
        #expect(higlobe.name == "Higlobe" && higlobe.color == .red)
        #expect(higlobe.feePercent == 0 && higlobe.fixedFee == 0 && higlobe.spreadPercent == 0.2)
        let custom = Platform.custom(color: .green)
        #expect(custom.name.isEmpty && custom.method == "Pix" && custom.pair == .usdBrl && custom.color == .green)
        #expect(custom.feePercent == 0 && custom.fixedFee == 0 && custom.spreadPercent == 0)
    }

    @Test func platformCodableRoundTrip() throws {
        let data = try JSONEncoder().encode(Platform.deelPix)
        #expect(try JSONDecoder().decode(Platform.self, from: data) == .deelPix)
    }

    @Test func instantiatedHasNewId() {
        let copy = Platform.deelPix.instantiated()
        #expect(copy.id != Platform.deelPix.id)
        #expect(copy.name == "Deel" && copy.spreadPercent == 1.0)
    }

    @Test func colorsAreInRange() {
        for color in PlatformColor.allCases {
            let rgb = color.rgb
            #expect((0...1).contains(rgb.red) && (0...1).contains(rgb.green) && (0...1).contains(rgb.blue))
        }
    }
}
