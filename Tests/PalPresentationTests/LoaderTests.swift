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
    func loadedOnSuccess() async throws {
        let loader = Loader<Int>()
        loader.load { 42 }
        try await Task.sleep(for: .milliseconds(50))
        #expect(loader.state.value == 42)
    }

    @Test("Failed load maps to .failed with a presentable error")
    func failedOnError() async throws {
        let loader = Loader<Int>()
        loader.load { throw SampleError() }
        try await Task.sleep(for: .milliseconds(50))
        #expect(loader.state.error != nil)
    }

    @Test("Loading keeps the previous value")
    func keepsPreviousValueWhileLoading() async throws {
        let loader = Loader<String>()
        loader.load { "first" }
        try await Task.sleep(for: .milliseconds(40))
        #expect(loader.state.value == "first")

        loader.load { try await Task.sleep(for: .milliseconds(100)); return "second" }
        guard case .loading(let previous) = loader.state else {
            Issue.record("Expected .loading after re-trigger, got \(loader.state)")
            return
        }
        #expect(previous == "first")
    }

    @Test("Re-triggering cancels the previous in-flight load (no late overwrite)")
    func reTriggerCancelsPrevious() async throws {
        let loader = Loader<String>()
        loader.load { try await Task.sleep(for: .milliseconds(120)); return "slow" }
        loader.load { "fast" }
        try await Task.sleep(for: .milliseconds(220))
        #expect(loader.state.value == "fast")
    }

    @Test("Canonical VM-holds-Loader pattern compiles and loads")
    func referencePatternCompilesAndLoads() async throws {
        let viewModel = ReferenceListViewModel(fetch: { [1, 2, 3] })
        await viewModel.load()
        #expect(viewModel.items.state.value == [1, 2, 3])
        viewModel.refresh()
        try await Task.sleep(for: .milliseconds(50))
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
    func refreshKeepsPreviousOnFailure() async throws {
        let loader = Loader<String>()
        await loader.performLoad { "first" }
        await loader.refresh { throw SampleError() }
        #expect(loader.state.error != nil)
        #expect(loader.state.value == "first")
    }
}
