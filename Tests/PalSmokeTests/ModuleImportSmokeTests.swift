import Testing
import PalCore
import PalPersistence
import PalNetworking
import PalAuth
import PalPresentation
import PalNavigation
import PalDesignSystem
import PalAnalytics
import PalFeatureFlags
import PalDebugKit
import PalNotifications

@Suite("Package smoke")
struct ModuleImportSmokeTests {
    @Test("All Pal modules link and import")
    func allModulesImport() {
        #expect(Bool(true))
    }
}
