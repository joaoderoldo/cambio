import Foundation
import Testing
@testable import CambioCore

func approx(_ a: Double, _ b: Double, _ tolerance: Double = 1e-9) -> Bool { abs(a - b) < tolerance }

struct PayoutTests {
    @Test func payoutDeelMatchesRealSimulation() {
        let received = Payout.receive(5000, via: .deelPix, commercial: 5.7817)
        #expect(approx(received, 5000 * 0.988 * 5.7817 * 0.99))
    }

    @Test func payoutHiglobeSpreadOnly() {
        // Higlobe converts at the commercial rate minus 0.20%, with no fee.
        let received = Payout.receive(1000.00, via: .higlobePix, commercial: 5.4881)
        #expect(approx(received, 1000.00 * 5.4881 * 0.998))
        #expect(abs(received - 5477.12) < 0.01)
    }

    @Test func fixedFeeNeverNegative() {
        var platform = Platform.custom(color: .blue)
        platform.name = "Wire"
        platform.fixedFee = 50
        #expect(Payout.receive(10, via: platform, commercial: 5.78) == 0)
    }

    @Test func platformRateAndCost() {
        #expect(approx(Payout.platformRate(.deelPix, commercial: 5.78), 5.78 * 0.988 * 0.99))
        #expect(approx(Payout.costPercent(.deelPix), 2.188))
        #expect(approx(Payout.costPercent(.higlobePix), 0.2))
    }

    @Test func spreadFromRate() {
        #expect(Payout.spread(platformRate: 5.72386, commercial: 5.7817) == 1.0)
        #expect(Payout.spread(platformRate: 5.9, commercial: 5.78) == 0)
        #expect(Payout.spread(platformRate: 1, commercial: 5.78) == 20)
        #expect(Payout.spread(platformRate: 5.7, commercial: 0) == nil)
        #expect(Payout.spread(platformRate: -1, commercial: 5.78) == nil)
    }
}
