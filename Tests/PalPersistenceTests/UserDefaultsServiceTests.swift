import Foundation
import Testing
@testable import PalPersistence

private extension DefaultsKey where Value == Bool {
    static var flagWithDefault: DefaultsKey<Bool> { .init("flagWithDefault", default: false) }
    static var flagWithoutDefault: DefaultsKey<Bool> { .init("flagWithoutDefault") }
}

/// Pins the behaviors the PalPersistence guide documents — the private-suite testing
/// snippet, default-vs-unset reads, and the public raw `name`.
@Suite("UserDefaultsService")
struct UserDefaultsServiceTests {

    @Test("Guide snippet: a private suite per test compiles and isolates writes from .standard")
    func privateSuiteSnippet() throws {
        let suiteName = "tests.\(UUID().uuidString)"
        let suite = try #require(UserDefaults(suiteName: suiteName))
        defer { suite.removePersistentDomain(forName: suiteName) }
        let defaults = UserDefaultsService(defaults: suite)

        defaults.set(true, for: .flagWithoutDefault)

        #expect(defaults.get(.flagWithoutDefault) == true)
        #expect(suite.object(forKey: DefaultsKey<Bool>.flagWithoutDefault.name) != nil)
        #expect(UserDefaults.standard.object(forKey: DefaultsKey<Bool>.flagWithoutDefault.name) == nil)
    }

    @Test("A key with a default reads the default when unset; a key without one reads nil")
    func defaultVersusUnset() throws {
        let suiteName = "tests.\(UUID().uuidString)"
        let suite = try #require(UserDefaults(suiteName: suiteName))
        defer { suite.removePersistentDomain(forName: suiteName) }
        let defaults = UserDefaultsService(defaults: suite)

        #expect(defaults.get(.flagWithDefault) == false)
        #expect(defaults.get(.flagWithoutDefault) == nil)

        defaults.set(true, for: .flagWithoutDefault)
        defaults.delete(.flagWithoutDefault)

        #expect(defaults.get(.flagWithoutDefault) == nil)
    }

    @Test("name is the raw key string the value is stored under")
    func nameIsTheRawKey() throws {
        let suiteName = "tests.\(UUID().uuidString)"
        let suite = try #require(UserDefaults(suiteName: suiteName))
        defer { suite.removePersistentDomain(forName: suiteName) }

        UserDefaultsService(defaults: suite).set(true, for: .flagWithDefault)

        #expect(DefaultsKey<Bool>.flagWithDefault.name == "flagWithDefault")
        #expect(suite.bool(forKey: "flagWithDefault"))
    }
}
