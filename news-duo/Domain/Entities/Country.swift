nonisolated struct Country: Identifiable, Hashable, Sendable {
    /// Lowercase ISO 3166-1 alpha-2 code, e.g. "us".
    let code: String

    var id: String { code }

    init(code: String) {
        self.code = code.lowercased()
    }

    static let unitedStates = Country(code: "us")

    /// Countries NewsAPI has listed for top headlines.
    ///
    /// Availability depends on the plan: the API answers an unsupported or
    /// uncovered country with an empty result, not an error. With a developer
    /// key only "us" returned headlines when this list was checked.
    static let supported: [Country] = [
        "ae", "ar", "at", "au", "be", "bg", "br", "ca", "ch", "cn", "co", "cu", "cz", "de",
        "eg", "fr", "gb", "gr", "hk", "hu", "id", "ie", "il", "in", "it", "jp", "kr", "lt",
        "lv", "ma", "mx", "my", "ng", "nl", "no", "nz", "ph", "pl", "pt", "ro", "rs", "ru",
        "sa", "se", "sg", "si", "sk", "th", "tr", "tw", "ua", "us", "ve", "za",
    ].map { Country(code: $0) }
}
