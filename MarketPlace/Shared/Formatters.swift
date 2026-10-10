import Foundation

// MainActor because NumberFormatter isn't thread-safe; only views use it.
@MainActor
enum Formatters {
    // Created once; making a NumberFormatter for every row is slow.
    private static let priceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.locale = Locale(identifier: "en_IN")
        return formatter
    }()

    static func price(cents: Int) -> String {
        priceFormatter.string(from: NSNumber(value: Double(cents) / 100)) ?? ""
    }
}
