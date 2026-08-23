# Tests

Extends [../AGENTS.md](../AGENTS.md). Swift Testing (`import Testing`) throughout — there is no XCTest in this repo. One test target per product plus `PalSmokeTests` for module-import smoke.

## Run

```bash
swift test                        # everything
swift test --filter LoaderTests   # one suite
```

## Never assert async completion after a fixed sleep

The rule that costs the most when broken: a test that fires work, sleeps a fixed `Task.sleep`, then asserts, is asserting on the scheduler. `LoaderTests` failed exactly this way when a CI image moved to a newer Swift — 40 ms was no longer enough while 50 ms was, with no product regression behind it. Instead:

- `await` the awaitable sibling (`performLoad`, `performLoadMore`) wherever one exists;
- rely on transitions that are documented as **synchronous** — `load(_:)` enters `.loading(previous:)` before it returns, so re-trigger checks need no waiting at all;
- otherwise poll the observable state with `waitUntil { … }` (`Tests/PalPresentationTests/AsyncTestSupport.swift`) and a generous timeout.

## Doc snippets are compile-guarded here

Snippets shipped in the consumer guides are pinned by tests so they cannot silently drift from the API: the canonical ViewModel `load()`/`performLoad` shape in `PalPresentationTests`, the `RouterView` usage in `PalNavigationTests`, and DesignSystem's scroll-observation and shimmer/skeleton snippets in `PalDesignSystemTests`. **Change a documented pattern and you change its guard test in the same commit** — two shipped snippets once reached adopters non-compiling, which is what these guards exist to prevent.

## Style

Exercise seams through spies and fakes, not the network — the suites cover interceptor chains, single-flight token refresh, the log ring buffer, mock interceptors, notification mapping via a spy backend, and the paged/loader state machines this way. A test that needs a live server belongs to an out-of-repo validation run, not here.
