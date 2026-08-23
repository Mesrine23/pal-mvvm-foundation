# Documentation

Extends [../AGENTS.md](../AGENTS.md). These are the consumer-facing docs. The standard they are held to: **an adopter builds an app on Pal without opening a single foundation source file.** Three adopter apps have now done exactly that, and every gap they found was a docs gap rather than a wrong mechanism — protect that.

## One fact, one home

| Change | Update |
|---|---|
| A product's API or usage | [Products/‹Product›.md](Products/) |
| A design decision or its rationale | [DECISIONS.md](DECISIONS.md) |
| Layers, the DAG, a pattern, adoption guidance | [ARCHITECTURE.md](ARCHITECTURE.md) |
| Onboarding: install → composition root → first feature | [GettingStarted.md](GettingStarted.md) |
| What an agent in a *consuming app* needs | [ADOPTERS.md](ADOPTERS.md) — then `Scripts/check-adopter-kit.sh` |
| What shipped in a release | [../CHANGELOG.md](../CHANGELOG.md) |
| Implementation status, phase log, approved exceptions | [../CONTRIBUTING.md](../CONTRIBUTING.md) |
| Symbol-level reference | the product's `.docc` catalog under `Sources/` — never hand-written here |
| A rule agents must follow | `AGENTS.md`, not these files |

**Status and history live in CONTRIBUTING only.** Restating them anywhere else is how they go stale — that already happened once, caught by an adopting agent reading "Phase 0 / empty stubs" at `v0.9.0`.

## Governance

[DECISIONS.md](DECISIONS.md) records the intended design and is authoritative, but it is a living document: **propose changes rather than drifting silently.** When implementation reality conflicts with the design, stop, surface the conflict, and record the resolution in CONTRIBUTING's deviations log. The design text stays authoritative; the log is the audit trail of approved exceptions.

## Every snippet must compile

Snippets here are shipped API surface. Where a snippet encodes a canonical pattern, a test in `Tests/` pins it — change one and change the other in the same commit. Never paste a snippet you have not compiled.

## CHANGELOG entries

Newest first, one entry per release, opening with an **`Affects:`** line naming the products the release touches (`Affects: documentation only` for a docs release) — one tag versions all twelve products, so a consumer who imports two of them must be able to stop reading after that line. Group the body under `Added` / `Fixed` / `Breaking`, and write for someone deciding whether to bump their pin, not for the person who wrote the code.

## Voice

Consumer-facing and specific. Say what a mechanism does and show the seam; leave the rationale to DECISIONS and the history to CONTRIBUTING.
