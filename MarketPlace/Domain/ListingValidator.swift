import Foundation

struct ValidationIssue: Equatable, Sendable {
    enum Field: Equatable, Sendable {
        case title
        case details
        case price
        case images
    }

    let field: Field
    let message: String
}

struct ListingValidator {
    static let titleMaxLength = 80
    static let detailsMaxLength = 1000
    static let maxPriceCents = 100_000_000
    static let maxImages = 3

    static func validate(_ draft: ListingDraft) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty {
            issues.append(ValidationIssue(field: .title, message: "Enter a title."))
        } else if title.count > titleMaxLength {
            issues.append(ValidationIssue(field: .title, message: "Title can be at most 80 characters."))
        }

        let details = draft.details.trimmingCharacters(in: .whitespacesAndNewlines)
        if details.count > detailsMaxLength {
            issues.append(ValidationIssue(field: .details, message: "Description can be at most 1000 characters."))
        }

        let priceText = draft.priceText.trimmingCharacters(in: .whitespaces)
        if priceText.isEmpty {
            issues.append(ValidationIssue(field: .price, message: "Enter a price."))
        } else if let cents = priceCents(from: priceText) {
            if cents > maxPriceCents {
                issues.append(ValidationIssue(field: .price, message: "Price can be at most ₹10,00,000."))
            }
        } else {
            issues.append(ValidationIssue(field: .price, message: "Enter a price like 1500 or 1500.50."))
        }

        if draft.images.count > maxImages {
            issues.append(ValidationIssue(field: .images, message: "You can add at most 3 photos."))
        }

        return issues
    }

    // Returns the price in paise, or nil if the text is not a plain number like "1500" or "1500.50".
    static func priceCents(from text: String) -> Int? {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 1 || parts.count == 2 else { return nil }

        let rupeesText = String(parts[0])
        // Very long numbers would overflow Int when multiplied; they are far above the max price anyway.
        guard isDigits(rupeesText), rupeesText.count <= 12, let rupees = Int(rupeesText) else { return nil }

        var paise = 0
        if parts.count == 2 {
            let paiseText = String(parts[1])
            guard isDigits(paiseText), paiseText.count <= 2, let value = Int(paiseText) else { return nil }
            // "1500.5" means 50 paise, not 5.
            paise = paiseText.count == 1 ? value * 10 : value
        }

        return rupees * 100 + paise
    }

    private static func isDigits(_ text: String) -> Bool {
        !text.isEmpty && text.allSatisfy { $0 >= "0" && $0 <= "9" }
    }
}
