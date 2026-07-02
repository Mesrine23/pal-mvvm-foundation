import PalAnalytics

/// The app's analytics events, declared as static factories (the foundation ships
/// no events — apps supply their own).
extension AnalyticsEvent {

    /// A screen was shown.
    static func screenViewed(_ name: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "screen_viewed", parameters: ["screen": .string(name)])
    }

    /// A user row was selected.
    static func userSelected(id: Int) -> AnalyticsEvent {
        AnalyticsEvent(name: "user_selected", parameters: ["id": .int(id)])
    }

    /// A favorite was toggled.
    static func favoriteToggled(on: Bool) -> AnalyticsEvent {
        AnalyticsEvent(name: "favorite_toggled", parameters: ["on": .bool(on)])
    }

    /// A local notification was scheduled.
    static func notificationScheduled(_ id: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "notification_scheduled", parameters: ["id": .string(id)])
    }

    /// A demo session started.
    static var loggedIn: AnalyticsEvent { AnalyticsEvent(name: "logged_in") }

    /// A demo session ended.
    static var loggedOut: AnalyticsEvent { AnalyticsEvent(name: "logged_out") }
}
