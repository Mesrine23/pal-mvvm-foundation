---
paths:
  - "CHANGELOG.md"
---

# Writing a CHANGELOG entry

Newest first. Write for a consumer deciding whether to bump their pin — not for the person who wrote the code.

```markdown
## [1.6.0] — YYYY-MM-DD

**Affects:** PalNetworking, PalPresentation

One paragraph on what this release is for and what drove it.

### Added
### Fixed
### Breaking (pre-adoption)
```

**The `Affects:` line is mandatory** and comes first — one tag versions all twelve products, so a consumer who imports two of them must be able to stop reading right there. Use `Affects: documentation only` for a docs release.

Derive the candidate list from the diff, never from memory:

```bash
git diff --name-only "$(git tag --list 'v*' --sort=-v:refname | head -1)"..HEAD -- Sources | grep '\.swift$' | cut -d/ -f2 | sort -u
```

Then **trim it**. The diff over-reports: doc-comment fixes and in-repo call-site updates (a pattern match gaining a `_` because an enum changed elsewhere) touch a product's files without changing anything for someone who imports it. Keep only products whose public API or behavior actually moved.

Every entry names the symbol it is about — `NetworkClient.sendWithResponse(_:)`, not "improved the client". A breaking change says what a call site must do differently, in one sentence.
