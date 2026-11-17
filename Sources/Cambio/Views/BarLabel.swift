import CambioCore
import SwiftUI

/// The text in the menu bar, e.g. "USD 5,78 ▾". Plain text: SF Symbols are dropped there.
struct BarLabel: View {
    let store: RateStore

    var body: some View {
        Text(RateFormat.barText(base: store.pair.base, value: store.quote?.bid, changePercent: store.quote?.changePercent))
            .monospacedDigit()
    }
}
