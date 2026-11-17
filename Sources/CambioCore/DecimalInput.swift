import Foundation

/// Reads numbers people type: "5,72386", "5.72386", "1.000,50", "1,000.50", "US$ 5.000", "1,2 %".
public enum DecimalInput {
    /// - Currency symbols, "%" and spaces are ignored.
    /// - With both "," and ".", the last one is the decimal separator.
    /// - With only one kind, the locale's decimal separator is decimal; the locale's grouping
    ///   separator counts as grouping only when every group after it has exactly 3 digits
    ///   ("5.000" is 5000 in pt_BR, "5.72386" is 5.72386).
    /// - Anything else, or more than one decimal separator, is nil.
    public static func parse(_ text: String, locale: Locale = .current) -> Double? {
        var cleaned = text
        for token in ["US$", "R$", "$", "%"] {
            cleaned = cleaned.replacingOccurrences(of: token, with: "")
        }
        cleaned = cleaned.filter { !$0.isWhitespace }
        guard cleaned.contains(where: \.isNumber),
              cleaned.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == "," || $0 == ".") })
        else { return nil }

        let decimal = decimalSeparator(in: cleaned, locale: locale)
        let parts = decimal.map { cleaned.split(separator: $0, omittingEmptySubsequences: false) } ?? [Substring(cleaned)]
        guard parts.count <= 2 else { return nil }

        let fraction = parts.count == 2 ? String(parts[1]) : ""
        guard fraction.allSatisfy(\.isNumber) else { return nil }

        guard let integer = digits(ofGrouped: String(parts[0])) else { return nil }
        return Double((integer.isEmpty ? "0" : integer) + (fraction.isEmpty ? "" : "." + fraction))
    }

    private static func decimalSeparator(in text: String, locale: Locale) -> Character? {
        let lastComma = text.lastIndex(of: ",")
        let lastDot = text.lastIndex(of: ".")
        if let lastComma, let lastDot {
            return lastComma > lastDot ? "," : "."
        }
        guard let only: Character = lastComma != nil ? "," : (lastDot != nil ? "." : nil) else { return nil }
        if String(only) == (locale.decimalSeparator ?? ".") { return only }
        return isGrouping(text, separator: only) ? nil : only
    }

    private static func isGrouping(_ text: String, separator: Character) -> Bool {
        let groups = text.split(separator: separator, omittingEmptySubsequences: false)
        return groups.count >= 2
            && (1...3).contains(groups[0].count)
            && groups.dropFirst().allSatisfy { $0.count == 3 }
    }

    /// The digits of an integer part, accepting well-formed thousands groups ("1.000.000").
    private static func digits(ofGrouped integer: String) -> String? {
        guard let separator = integer.first(where: { $0 == "," || $0 == "." }) else { return integer }
        guard !integer.contains(where: { ($0 == "," || $0 == ".") && $0 != separator }),
              isGrouping(integer, separator: separator)
        else { return nil }
        return integer.filter(\.isNumber)
    }
}
