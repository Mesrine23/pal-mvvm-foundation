import Foundation

/// Static information about the host app, read from its main bundle.
///
/// ```swift
/// Text(verbatim: "\(AppInfo.current.version) (\(AppInfo.current.build))")
/// ```
public struct AppInfo: Sendable, Equatable {

    /// The marketing version (`CFBundleShortVersionString`), e.g. `"1.4.0"`.
    public let version: String

    /// The build number (`CFBundleVersion`), e.g. `"217"`.
    public let build: String

    /// The app's bundle identifier.
    public let bundleId: String

    /// The app's display name, falling back to the bundle name.
    public let displayName: String

    /// Information for the current host app.
    public static let current: AppInfo = {
        let info = Bundle.main.infoDictionary ?? [:]
        return AppInfo(
            version: info["CFBundleShortVersionString"] as? String ?? "0",
            build: info["CFBundleVersion"] as? String ?? "0",
            bundleId: Bundle.main.bundleIdentifier ?? "",
            displayName: (info["CFBundleDisplayName"] ?? info["CFBundleName"]) as? String ?? ""
        )
    }()

    /// `true` in builds compiled with the Debug configuration.
    public static var isDebug: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    /// `true` when running in the iOS Simulator.
    public static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }
}
