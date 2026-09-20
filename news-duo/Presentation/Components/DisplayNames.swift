import Foundation

// User-facing names for domain values live here, not in the Domain layer.

nonisolated extension NewsCategory {
    var title: String {
        switch self {
        case .business: "Business"
        case .entertainment: "Entertainment"
        case .general: "General"
        case .health: "Health"
        case .science: "Science"
        case .sports: "Sports"
        case .technology: "Technology"
        }
    }
}

nonisolated extension ArticleSortOrder {
    var title: String {
        switch self {
        case .relevancy: "Relevancy"
        case .popularity: "Popularity"
        case .newest: "Newest"
        }
    }
}

nonisolated extension Country {
    /// Flag emoji built from the code's regional indicator symbols ("id" → 🇮🇩).
    /// No dependency needed: every ISO 3166-1 alpha-2 code maps this way.
    var flag: String {
        let letters = code.uppercased().unicodeScalars
        guard letters.count == 2, letters.allSatisfy({ ("A"..."Z").contains($0) }) else { return "🏳️" }
        let regionalIndicatorA: UInt32 = 0x1F1E6
        return String(String.UnicodeScalarView(letters.compactMap {
            UnicodeScalar(regionalIndicatorA + $0.value - UnicodeScalar("A").value)
        }))
    }

    /// Localized name, used for accessibility since the UI shows only the flag.
    var name: String {
        Locale.current.localizedString(forRegionCode: code) ?? code.uppercased()
    }
}
