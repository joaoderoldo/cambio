import SwiftUI

/// Title centered, round "back" button on the left. Shared by every page after the main one.
struct NavBar: View {
    let title: Text
    let back: () -> Void

    init(_ title: LocalizedStringKey, back: @escaping () -> Void) {
        self.title = Text(title)
        self.back = back
    }

    init(verbatim title: String, back: @escaping () -> Void) {
        self.title = Text(verbatim: title)
        self.back = back
    }

    var body: some View {
        ZStack {
            title
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .padding(.horizontal, 34)
            HStack {
                Button(action: back) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(IconButtonStyle())
                .accessibilityLabel(Text("Back"))
                Spacer()
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }
}
