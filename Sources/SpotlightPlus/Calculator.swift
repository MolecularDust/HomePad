import Foundation

/// Evaluates arithmetic typed into the search field, like Spotlight does: "7+3", "7+3=", "(2+3)*4", "2^10", "15%".
/// A small parser rather than NSExpression, which raises Objective-C exceptions on input it can't read.
enum Calculator {
    struct Answer {
        let expression: String      // what was typed, e.g. "7+3 ="
        let value: String           // e.g. "10"
    }

    /// nil when the text isn't arithmetic: plain words, a lone number, or something that can't be worked out.
    static func evaluate(_ text: String) -> Answer? {
        var source = text.trimmingCharacters(in: .whitespaces)
        if source.hasSuffix("=") { source.removeLast() }
        let normalised = source
            .replacingOccurrences(of: "×", with: "*").replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "−", with: "-").replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: ",", with: ".")
            .filter { !$0.isWhitespace }
        // Dates and phone numbers (2024-01-05) aren't sums.
        if normalised.range(of: #"^\d+(-\d+){2,}$"#, options: .regularExpression) != nil { return nil }
        let allowed = Set("0123456789.+-*/^()%")
        guard !normalised.isEmpty, normalised.allSatisfy(allowed.contains), normalised.contains(where: \.isNumber) else { return nil }

        var parser = Parser(Array(normalised))
        guard let result = parser.parse(), parser.usedOperator, result.isFinite else { return nil }
        let typed = source.trimmingCharacters(in: .whitespaces)
        return Answer(expression: typed + " =", value: format(result))
    }

    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 10
        formatter.maximumSignificantDigits = 12
        return formatter
    }()

    private static func format(_ value: Double) -> String {
        if value == value.rounded(), abs(value) < 1e15 { return String(Int64(value)) }
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// expression := term (("+" | "-") term)*      term := power (("*" | "/") power)*
    /// power := unary ("^" power)?                 unary := ("-" | "+") unary | postfix
    /// postfix := primary "%"*                     primary := number | "(" expression ")"
    private struct Parser {
        let chars: [Character]
        var index = 0
        var usedOperator = false

        init(_ chars: [Character]) { self.chars = chars }

        mutating func parse() -> Double? {
            guard let value = expression(), index == chars.count else { return nil }
            return value
        }

        private var next: Character? { index < chars.count ? chars[index] : nil }

        private mutating func expression() -> Double? {
            guard var value = term() else { return nil }
            while let c = next, c == "+" || c == "-" {
                index += 1
                guard let rhs = term() else { return nil }
                usedOperator = true
                value = c == "+" ? value + rhs : value - rhs
            }
            return value
        }

        private mutating func term() -> Double? {
            guard var value = power() else { return nil }
            while let c = next, c == "*" || c == "/" {
                index += 1
                guard let rhs = power() else { return nil }
                if c == "/" && rhs == 0 { return nil }
                usedOperator = true
                value = c == "*" ? value * rhs : value / rhs
            }
            return value
        }

        private mutating func power() -> Double? {
            guard let base = unary() else { return nil }
            if next == "^" {
                index += 1
                guard let exponent = power() else { return nil }
                usedOperator = true
                return pow(base, exponent)
            }
            return base
        }

        private mutating func unary() -> Double? {
            if let c = next, c == "-" || c == "+" {
                index += 1
                guard let value = unary() else { return nil }
                return c == "-" ? -value : value
            }
            return postfix()
        }

        private mutating func postfix() -> Double? {
            guard var value = primary() else { return nil }
            while next == "%" {
                index += 1
                usedOperator = true
                value /= 100
            }
            return value
        }

        private mutating func primary() -> Double? {
            if next == "(" {
                index += 1
                guard let value = expression(), next == ")" else { return nil }
                index += 1
                return value
            }
            let start = index
            while let c = next, c.isNumber || c == "." { index += 1 }
            return index > start ? Double(String(chars[start..<index])) : nil
        }
    }
}
