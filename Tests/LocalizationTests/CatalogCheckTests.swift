import Foundation
import Testing

@Suite("String Catalog check")
struct CatalogCheckTests {

    @Test("The Example's catalog has no problems")
    func theExampleCatalogHasNoProblems() throws {
        let catalog = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Example/PalExample/Localizable.xcstrings")
        #expect(try CatalogCheck.problems(in: catalog) == [])
    }

    @Test("Pal's own catalogs have no problems", arguments: [
        "Sources/PalDesignSystem/Localizable.xcstrings",
        "Sources/PalPresentation/Localizable.xcstrings",
    ])
    func palsOwnCatalogsHaveNoProblems(path: String) throws {
        #expect(try CatalogCheck.problems(in: .repository(path)) == [])
    }

    @Test("Each format mistake is caught, and sound formats pass")
    func eachFormatMistakeIsCaught() throws {
        #expect(try CatalogCheck.problems(in: .fixture("Formats.xcstrings")) == [
            .init(key: "formatTranslatorChangedType", issue: "el changes a placeholder's type"),
            .init(key: "formatTranslatorDroppedArgument", issue: "el drops a placeholder"),
            .init(key: "formatFavoritesDroppedCount", issue: "el drops a placeholder"),
            .init(key: "formatEscapedPercent", issue: "%% in a key without placeholders shows as %%"),
            .init(key: "formatMissingGreek", issue: "no el value"),
            .init(key: "Extracted literal", issue: "not a manual key, so it has no symbol"),
        ])
    }

    @Test("A key written twice is caught")
    func aKeyWrittenTwiceIsCaught() throws {
        #expect(try CatalogCheck.problems(in: .fixture("Duplicate.xcstrings")) == [
            .init(key: "duplicateKey", issue: "written more than once; the build keeps the first"),
        ])
    }

    @Test("Reordered placeholders are not a mistake")
    func reorderedPlaceholdersAreNotAMistake() {
        #expect(Set(CatalogCheck.placeholders(in: "%1$@ sent you %2$@"))
            == Set(CatalogCheck.placeholders(in: "Το %2$@ σας το έστειλε ο/η %1$@")))
    }
}

private extension URL {
    static func repository(_ path: String) -> URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: path)
    }

    static func fixture(_ name: String) -> URL {
        URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Fixtures/\(name)")
    }
}
