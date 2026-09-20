import Testing
@testable import news_duo

struct CountryTests {
    @Test(arguments: [("us", "🇺🇸"), ("id", "🇮🇩"), ("GB", "🇬🇧"), ("jp", "🇯🇵")])
    func flagIsBuiltFromTheRegionCode(code: String, expected: String) {
        #expect(Country(code: code).flag == expected)
    }

    @Test(arguments: ["", "u", "usa", "1a", "é!"])
    func invalidCodesFallBackToAWhiteFlag(code: String) {
        #expect(Country(code: code).flag == "🏳️")
    }

    @Test func codesAreNormalisedToLowercase() {
        #expect(Country(code: "ID") == Country(code: "id"))
        #expect(Country(code: "ID").code == "id")
    }

    @Test func supportedListIsUniqueTwoLetterCodes() {
        let codes = Country.supported.map(\.code)

        #expect(Set(codes).count == codes.count)
        #expect(codes.allSatisfy { $0.count == 2 })
        #expect(codes.contains("us"))
    }

    @Test func everySupportedCountryHasAFlagAndAName() {
        for country in Country.supported {
            #expect(country.flag != "🏳️")
            #expect(!country.name.isEmpty)
        }
    }
}
