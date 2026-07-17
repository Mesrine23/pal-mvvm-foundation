import Foundation
import Testing
@testable import PalPresentation

private struct SampleError: Error {}

/// Compile-guards the canonical GettingStarted VM shape: `load() async` drives `.task`
/// via `performLoad` (the closure returns `Value`), `refresh()` drives the retry button via `load`.
@MainActor @Observable
private final class ReferenceListViewModel {
    let items = Loader<[Int]>()
    private let fetch: @Sendable () async throws -> [Int]
    init(fetch: @escaping @Sendable () async throws -> [Int]) { self.fetch = fetch }
    func load() async { await items.performLoad { try await self.fetch() } }
    func refresh() { items.load { try await self.fetch() } }
}

@MainActor
@Suite("Loader")
struct LoaderTests {

    @Test("Successful load reaches .loaded")
    func loadedOnSuccess() async {
        let loader = Loader<Int>()
        loader.load { 42 }
        await waitUntil { loader.state.value == 42 }
        #expect(loader.state.value == 42)
    }

    @Test("Failed load maps to .failed with a presentable error")
    func failedOnError() async {
        let loader = Loader<Int>()
        loader.load { throw SampleError() }
        await waitUntil { loader.state.error != nil }
        #expect(loader.state.error != nil)
    }

    @Test("Loading keeps the previous value")
    func keepsPreviousValueWhileLoading() async {
        let loader = Loader<String>()
        await loader.performLoad { "first" }          // awaited: deterministically .loaded
        #expect(loader.state.value == "first")

        // load(_:) sets `.loading(previous:)` synchronously at the call site,
        // so the re-trigger transition is race-free — no sleep needed.
        loader.load { try await Task.sleep(for: .seconds(1)); return "second" }
        guard case .loading(let previous) = loader.state else {
            Issue.record("Expected .loading after re-trigger, got \(loader.state)")
            return
        }
        #expect(previous == "first")
        loader.cancel()
    }

    @Test("Re-triggering cancels the previous in-flight load (no late overwrite)")
    func reTriggerCancelsPrevious() async {
        let loader = Loader<String>()
        loader.load { try await Task.sleep(for: .seconds(1)); return "slow" }   // stays in-flight
        loader.load { "fast" }                                                  // supersedes + cancels "slow"
        await waitUntil { loader.state.value == "fast" }
        #expect(loader.state.value == "fast")
    }

    @Test("Canonical VM-holds-Loader pattern compiles and loads")
    func referencePatternCompilesAndLoads() async {
        let viewModel = ReferenceListViewModel(fetch: { [1, 2, 3] })
        await viewModel.load()
        #expect(viewModel.items.state.value == [1, 2, 3])

        viewModel.refresh()   // fire-and-forget load via the retry button
        await waitUntil { if case .loaded = viewModel.items.state { true } else { false } }
        #expect(viewModel.items.state.value == [1, 2, 3])
    }

    @Test("Refresh reloads in place without entering .loading")
    func refreshDoesNotEnterLoading() async throws {
        let loader = Loader<String>()
        await loader.performLoad { "first" }
        #expect(loader.state.value == "first")

        let task = Task { await loader.refresh { try? await Task.sleep(for: .milliseconds(80)); return "second" } }
        try await Task.sleep(for: .milliseconds(20))
        #expect(loader.state.isLoading == false)
        #expect(loader.state.value == "first")
        await task.value
        #expect(loader.state.value == "second")
    }

    @Test("Refresh keeps the previous value on failure")
    func refreshKeepsPreviousOnFailure() async {
        let loader = Loader<String>()
        await loader.performLoad { "first" }
        await loader.refresh { throw SampleError() }
        #expect(loader.state.error != nil)
        #expect(loader.state.value == "first")
    }

    @Test("reset returns to .idle and the cancelled work never lands")
    func resetReturnsToIdle() async {
        let loader = Loader<String>()
        loader.load { try await Task.sleep(for: .seconds(1)); return "late" }
        guard case .loading = loader.state else {
            Issue.record("Expected .loading after load, got \(loader.state)")
            return
        }

        loader.reset()

        guard case .idle = loader.state else {
            Issue.record("Expected .idle after reset, got \(loader.state)")
            return
        }
        // The cancelled task's sleep throws immediately; give it a beat and
        // prove no late overwrite arrives.
        try? await Task.sleep(for: .milliseconds(50))
        guard case .idle = loader.state else {
            Issue.record("Cancelled work overwrote the reset state: \(loader.state)")
            return
        }
    }
}
