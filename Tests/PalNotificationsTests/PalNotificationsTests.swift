import Foundation
import Testing
import UserNotifications
@testable import PalNotifications

// MARK: - Spy backend

@MainActor
private final class SpyBackend: NotificationCenterBackend {

    var added: [UNNotificationRequest] = []
    var authorizationOptions: UNAuthorizationOptions?
    var grantResult = true
    var status: UNAuthorizationStatus = .notDetermined
    var removedPendingIDs: [String] = []
    var removedAllPending = false
    var pendingIDsToReturn: [String] = []
    var removedDeliveredIDs: [String] = []
    var badgeCount: Int?
    var categories: Set<UNNotificationCategory> = []
    var delegate: (any UNUserNotificationCenterDelegate)?

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationOptions = options
        return grantResult
    }

    func authorizationStatus() async -> UNAuthorizationStatus { status }

    func add(_ request: UNNotificationRequest) async throws { added.append(request) }

    func removePending(ids: [String]) { removedPendingIDs.append(contentsOf: ids) }

    func removeAllPending() { removedAllPending = true }

    func pendingIDs() async -> [String] { pendingIDsToReturn }

    func removeDelivered(ids: [String]) { removedDeliveredIDs.append(contentsOf: ids) }

    func setBadgeCount(_ count: Int) async throws { badgeCount = count }

    func setCategories(_ categories: Set<UNNotificationCategory>) { self.categories = categories }

    func setDelegate(_ delegate: (any UNUserNotificationCenterDelegate)?) { self.delegate = delegate }
}

@MainActor
private func makeService(_ backend: SpyBackend) -> NotificationService {
    NotificationService(backend: backend)
}

// MARK: - Scheduling

@Test @MainActor func immediateScheduleMapsContentAndNilTrigger() async throws {
    let backend = SpyBackend()
    let service = makeService(backend)
    let notification = LocalNotification(
        id: "order-1",
        title: "Ready",
        subtitle: "Order #1",
        body: "Come pick it up",
        sound: .default,
        badge: 3,
        categoryID: "order",
        threadID: "orders",
        userInfo: ["orderID": "1"]
    )

    try await service.schedule(notification)

    let request = try #require(backend.added.first)
    #expect(request.identifier == "order-1")
    #expect(request.trigger == nil)
    #expect(request.content.title == "Ready")
    #expect(request.content.subtitle == "Order #1")
    #expect(request.content.body == "Come pick it up")
    #expect(request.content.badge == 3)
    #expect(request.content.categoryIdentifier == "order")
    #expect(request.content.threadIdentifier == "orders")
    #expect(request.content.userInfo["orderID"] as? String == "1")
}

@Test @MainActor func afterTriggerMapsToTimeInterval() async throws {
    let backend = SpyBackend()
    let service = makeService(backend)

    try await service.schedule(LocalNotification(title: "T", body: "B"), trigger: .after(.seconds(90)))

    let trigger = try #require(backend.added.first?.trigger as? UNTimeIntervalNotificationTrigger)
    #expect(trigger.timeInterval == 90)
    #expect(trigger.repeats == false)
}

@Test @MainActor func nonPositiveDelayIsClamped() async throws {
    let backend = SpyBackend()
    let service = makeService(backend)

    try await service.schedule(LocalNotification(title: "T", body: "B"), trigger: .after(.seconds(0)))

    let trigger = try #require(backend.added.first?.trigger as? UNTimeIntervalNotificationTrigger)
    #expect(trigger.timeInterval == 0.1)
}

@Test @MainActor func calendarTriggerMapsComponentsAndRepeats() async throws {
    let backend = SpyBackend()
    let service = makeService(backend)
    var nineAM = DateComponents()
    nineAM.hour = 9

    try await service.schedule(LocalNotification(title: "T", body: "B"), trigger: .at(nineAM, repeats: true))

    let trigger = try #require(backend.added.first?.trigger as? UNCalendarNotificationTrigger)
    #expect(trigger.dateComponents.hour == 9)
    #expect(trigger.repeats == true)
}

@Test @MainActor func silentSoundMapsToNil() async throws {
    let backend = SpyBackend()
    let service = makeService(backend)

    try await service.schedule(LocalNotification(title: "T", body: "B", sound: .silent))

    #expect(try #require(backend.added.first).content.sound == nil)
}

@Test @MainActor func cancellationAndPendingPassThrough() async throws {
    let backend = SpyBackend()
    let service = makeService(backend)
    backend.pendingIDsToReturn = ["a", "b"]

    service.cancelPending(ids: ["x"])
    service.cancelAllPending()
    service.removeDelivered(ids: ["y"])
    try await service.setBadgeCount(0)

    #expect(backend.removedPendingIDs == ["x"])
    #expect(backend.removedAllPending)
    #expect(backend.removedDeliveredIDs == ["y"])
    #expect(backend.badgeCount == 0)
    #expect(await service.pendingIDs() == ["a", "b"])
}

// MARK: - Authorization

@Test @MainActor func authorizationRequestMapsOptionsAndResult() async throws {
    let backend = SpyBackend()
    let service = makeService(backend)
    backend.grantResult = true

    let granted = try await service.requestAuthorization([.alert, .sound, .provisional])

    #expect(granted)
    let options = try #require(backend.authorizationOptions)
    #expect(options.contains(.alert))
    #expect(options.contains(.sound))
    #expect(options.contains(.provisional))
    #expect(!options.contains(.badge))
}

@Test @MainActor func authorizationStatusMapsEveryCase() async {
    let backend = SpyBackend()
    let service = makeService(backend)
    var cases: [(UNAuthorizationStatus, NotificationAuthorizationStatus)] = [
        (.notDetermined, .notDetermined),
        (.denied, .denied),
        (.authorized, .authorized),
        (.provisional, .provisional),
    ]
    #if os(iOS)
    cases.append((.ephemeral, .ephemeral))
    #endif
    for (system, expected) in cases {
        backend.status = system
        #expect(await service.authorizationStatus() == expected)
    }
}

// MARK: - Categories

@Test @MainActor func categoriesMapIDsActionsAndOptions() throws {
    let backend = SpyBackend()
    let service = makeService(backend)

    service.setCategories([
        NotificationCategory(id: "order", actions: [
            NotificationAction(id: "reorder", title: "Reorder", options: [.foreground]),
            NotificationAction(id: "trash", title: "Delete", options: [.destructive, .authenticationRequired]),
        ]),
    ])

    let category = try #require(backend.categories.first { $0.identifier == "order" })
    #expect(category.actions.count == 2)
    let reorder = try #require(category.actions.first { $0.identifier == "reorder" })
    #expect(reorder.title == "Reorder")
    #expect(reorder.options.contains(.foreground))
    let trash = try #require(category.actions.first { $0.identifier == "trash" })
    #expect(trash.options.contains(.destructive))
    #expect(trash.options.contains(.authenticationRequired))
}

// MARK: - Delegate seat + responses

@Test @MainActor func initClaimsTheDelegateSeat() {
    let backend = SpyBackend()
    _ = makeService(backend)
    #expect(backend.delegate != nil)
}

@Test @MainActor func responsesReachEverySubscriberIndependently() async {
    let service = makeService(SpyBackend())
    let response = NotificationResponse(notificationID: "n1", actionID: .default, userInfo: ["k": "v"])

    let first = service.responses
    let second = service.responses
    service.receive(response)

    var firstIterator = first.makeAsyncIterator()
    var secondIterator = second.makeAsyncIterator()
    #expect(await firstIterator.next() == response)
    #expect(await secondIterator.next() == response)
}

@Test @MainActor func coldStartResponsesBufferUntilFirstSubscriber() async {
    let service = makeService(SpyBackend())
    let tap = NotificationResponse(notificationID: "cold", actionID: .default)

    service.receive(tap)
    var iterator = service.responses.makeAsyncIterator()

    #expect(await iterator.next() == tap)
}

// MARK: - Push registration

@Test @MainActor func deviceTokenBroadcastsRegisteredEventWithHex() async {
    let service = makeService(SpyBackend())
    let stream = service.pushEvents

    service.handleDeviceToken(Data([0x0a, 0xff, 0x01]))

    var iterator = stream.makeAsyncIterator()
    let event = await iterator.next()
    #expect(event == .registered(PushToken(data: Data([0x0a, 0xff, 0x01]))))
    if case .registered(let token) = event {
        #expect(token.hexString == "0aff01")
    }
}

@Test @MainActor func lateSubscriberReplaysLatestPushEvent() async {
    let service = makeService(SpyBackend())

    service.handleDeviceToken(Data([0x01]))
    var iterator = service.pushEvents.makeAsyncIterator()

    #expect(await iterator.next() == .registered(PushToken(data: Data([0x01]))))
}

@Test @MainActor func registrationFailureBroadcastsMessage() async {
    let service = makeService(SpyBackend())
    let stream = service.pushEvents

    service.handleRegistrationFailure(NSError(domain: "apns", code: 1))

    var iterator = stream.makeAsyncIterator()
    guard case .failed = await iterator.next() else {
        Issue.record("expected .failed")
        return
    }
}

// MARK: - Presentation mapping

@Test func presentationOptionsMapToSystemOptions() {
    #expect(NotificationPresentation.standard.unOptions == [.banner, .sound])
    #expect(NotificationPresentation.hidden.unOptions == [])
    #expect(NotificationPresentation([.banner, .sound, .badge, .list]).unOptions == [.banner, .sound, .badge, .list])
}
