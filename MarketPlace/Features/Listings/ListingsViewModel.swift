import Foundation
import Observation

// State for the list screen: the search text and the filtered listings.
@MainActor
@Observable
final class ListingsViewModel {
    var searchText = ""

    // Listings whose title matches the search text.
    func visibleListings(from listings: [Listing]) -> [Listing] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if query.isEmpty {
            return listings
        }
        return listings.filter { $0.title.localizedStandardContains(query) }
    }
}
