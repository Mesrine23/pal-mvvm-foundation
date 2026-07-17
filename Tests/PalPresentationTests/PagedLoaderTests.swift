import Foundation
import Testing
@testable import PalPresentation

private struct SampleError: Error {}

private actor CursorSpy {
    private(set) var received: [Int?] = []
    func record(_ cursor: Int?) { received.append(cursor) }
    var callCount: Int { received.count }
}

@MainActor
@Suite("PagedLoader")
struct PagedLoaderTests {

    @Test("First page loads through the state machine and arms hasMore")
    func firstPageLoads() async {
        let spy = CursorSpy()
        let loader = PagedLoader<Int, Int> { cursor in
            await spy.record(cursor)
            return Page(items: [1, 2], nextCursor: 2)
        }

        await loader.performLoad()

        #expect(loader.state.value == [1, 2])
        #expect(loader.hasMore)
        #expect(await spy.received == [nil])
    }

    @Test("loadMore passes the cursor, appends in order, and disarms at the end")
    func loadMoreAppendsAndEnds() async throws {
        let loader = PagedLoader<Int, Int> { cursor in
            switch cursor {
            case nil: Page(items: [1, 2], nextCursor: 2)
            case 2:   Page(items: [3, 4], nextCursor: nil)
            default:  Page(items: [], nextCursor: nil)
            }
        }
        await loader.performLoad()

        loader.loadMore()
        await waitUntil { loader.state.value == [1, 2, 3, 4] }
        #expect(loader.state.value == [1, 2, 3, 4])
        #expect(loader.hasMore == false)
        #expect(loader.isLoadingMore == false)

        loader.loadMore()   // hasMore == false → synchronous no-op
        #expect(loader.state.value == [1, 2, 3, 4])
    }

    @Test("loadMore dedupes while a page is already in flight")
    func loadMoreDedupes() async throws {
        let spy = CursorSpy()
        let loader = PagedLoader<Int, Int> { cursor in
            await spy.record(cursor)
            if cursor != nil { try? await Task.sleep(for: .milliseconds(80)) }
            return Page(items: [0], nextCursor: (cursor ?? 0) + 1)
        }
        await loader.performLoad()

        loader.loadMore()
        loader.loadMore()
        loader.loadMore()
        await waitUntil { loader.state.value?.count == 2 }   // wait for the single loadMore to finish

        #expect(await spy.callCount == 2)   // performLoad + one loadMore; the other two deduped
    }

    @Test("loadMore no-ops before the first page has loaded")
    func loadMoreRequiresFirstPage() async throws {
        let spy = CursorSpy()
        let loader = PagedLoader<Int, Int> { cursor in
            await spy.record(cursor)
            return Page(items: [], nextCursor: nil)
        }

        loader.loadMore()   // no first page yet → synchronous no-op (never starts the operation)

        #expect(await spy.callCount == 0)
        #expect(loader.state.value == nil)
    }

    @Test("A failed loadMore keeps the items and surfaces a footer error; retry clears it")
    func loadMoreFailureKeepsItems() async throws {
        let shouldFail = LockedBox(true)
        let loader = PagedLoader<Int, Int> { cursor in
            if cursor == nil { return Page(items: [1], nextCursor: 2) }
            if shouldFail.value { throw SampleError() }
            return Page(items: [2], nextCursor: nil)
        }
        await loader.performLoad()

        loader.loadMore()
        await waitUntil { loader.loadMoreError != nil }
        #expect(loader.state.value == [1])
        #expect(loader.loadMoreError != nil)
        #expect(loader.isLoadingMore == false)

        shouldFail.value = false
        loader.loadMore()
        await waitUntil { loader.state.value == [1, 2] }
        #expect(loader.loadMoreError == nil)
        #expect(loader.state.value == [1, 2])
    }

    @Test("refresh restarts from the first page without entering .loading")
    func refreshRestartsPagination() async throws {
        let spy = CursorSpy()
        let loader = PagedLoader<Int, Int> { cursor in
            await spy.record(cursor)
            if cursor == nil { return Page(items: [1], nextCursor: 2) }
            return Page(items: [99], nextCursor: 3)
        }
        await loader.performLoad()
        loader.loadMore()
        await waitUntil { loader.state.value == [1, 99] }
        #expect(loader.state.value == [1, 99])

        let refreshTask = Task { await loader.refresh() }
        #expect(loader.state.isLoading == false)   // refresh never enters .loading
        await refreshTask.value

        #expect(loader.state.value == [1])
        loader.loadMore()
        await waitUntil { loader.state.value == [1, 99] }
        #expect(await spy.received == [nil, 2, nil, 2])
    }

    @Test("Re-triggering the first page cancels the previous in-flight load")
    func reTriggerCancelsPrevious() async throws {
        let sequence = LockedBox(0)
        let loader = PagedLoader<String, Int> { _ in
            let call = sequence.increment()
            if call == 1 {
                try await Task.sleep(for: .milliseconds(120))
                return Page(items: ["slow"], nextCursor: nil)
            }
            return Page(items: ["fast"], nextCursor: nil)
        }

        loader.load()
        // Wait until the first task has claimed call 1 before re-triggering:
        // task start order is unordered, so firing both loads back-to-back can
        // hand the slow branch to the SECOND (uncancelled) load and flake.
        await waitUntil { sequence.value >= 1 }
        loader.load()
        await waitUntil { loader.state.value == ["fast"] }

        #expect(loader.state.value == ["fast"])
    }

    @Test("A failed first page maps to .failed keeping the previous items")
    func firstPageFailureKeepsPrevious() async throws {
        let shouldFail = LockedBox(false)
        let loader = PagedLoader<Int, Int> { _ in
            if shouldFail.value { throw SampleError() }
            return Page(items: [7], nextCursor: nil)
        }
        await loader.performLoad()
        shouldFail.value = true

        await loader.performLoad()

        #expect(loader.state.error != nil)
        #expect(loader.state.value == [7])
    }

    @Test("performLoadMore awaits the append — no polling needed")
    func performLoadMoreAppendsAwaitably() async {
        let loader = PagedLoader<Int, Int> { cursor in
            switch cursor {
            case nil: Page(items: [1, 2], nextCursor: 2)
            case 2:   Page(items: [3], nextCursor: nil)
            default:  Page(items: [], nextCursor: nil)
            }
        }
        await loader.performLoad()

        await loader.performLoadMore()

        #expect(loader.state.value == [1, 2, 3])
        #expect(loader.hasMore == false)
        #expect(loader.isLoadingMore == false)
    }

    @Test("performLoadMore respects the same guards as loadMore")
    func performLoadMoreRespectsGuards() async {
        let spy = CursorSpy()
        let loader = PagedLoader<Int, Int> { cursor in
            await spy.record(cursor)
            return Page(items: [9], nextCursor: nil)
        }

        await loader.performLoadMore()          // before the first page → no-op
        #expect(await spy.received.isEmpty)

        await loader.performLoad()
        await loader.performLoadMore()          // hasMore == false → no-op
        #expect(await spy.received == [nil])
    }

    @Test("A failed performLoadMore keeps the items and sets the footer error")
    func performLoadMoreFailureKeepsItems() async {
        let shouldFail = LockedBox(false)
        let loader = PagedLoader<Int, Int> { cursor in
            if shouldFail.value { throw SampleError() }
            return Page(items: [1], nextCursor: (cursor ?? 0) + 1)
        }
        await loader.performLoad()
        shouldFail.value = true

        await loader.performLoadMore()

        #expect(loader.loadMoreError != nil)
        #expect(loader.state.value == [1])
        #expect(loader.hasMore)
        #expect(loader.isLoadingMore == false)
    }
}

private final class LockedBox<Value: Sendable>: @unchecked Sendable {

    private let lock = NSLock()
    private var storage: Value

    init(_ value: Value) {
        storage = value
    }

    var value: Value {
        get { lock.withLock { storage } }
        set { lock.withLock { storage = newValue } }
    }
}

private extension LockedBox where Value == Int {
    func increment() -> Int {
        lock.withLock {
            storage += 1
            return storage
        }
    }
}
