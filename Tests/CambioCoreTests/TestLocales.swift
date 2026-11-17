import Foundation

let ptBR = Locale(identifier: "pt_BR")
let enUS = Locale(identifier: "en_US")

/// Foundation separates currency symbols with no-break spaces; tests compare plain spaces.
func plain(_ text: String) -> String {
    text.replacingOccurrences(of: "\u{00A0}", with: " ").replacingOccurrences(of: "\u{202F}", with: " ")
}
