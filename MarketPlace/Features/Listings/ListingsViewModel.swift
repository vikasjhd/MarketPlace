import Foundation
import Observation

@MainActor
@Observable
final class ListingsViewModel {
    var searchText = ""

    func visibleListings(from listings: [Listing]) -> [Listing] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if query.isEmpty {
            return listings
        }
        return listings.filter { $0.title.localizedStandardContains(query) }
    }
}
