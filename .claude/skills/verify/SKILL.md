---
name: verify
description: Run Pal's definition of done and report which conditions pass or fail. Use before claiming any change is finished, and when asked to verify, check the build, or confirm things are green.
allowed-tools: Bash(Scripts/check-adopter-kit.sh*) Bash(./Scripts/check-adopter-kit.sh*) Bash(swift build) Bash(swift test*) Bash(xcodebuild*) Bash(git status*) Bash(git diff*) Bash(git tag*) Bash(swift package diagnose-api-breaking-changes*) Bash(swift package --triple arm64-apple-ios17.0-simulator *) Bash(xcrun --sdk iphonesimulator --show-sdk-path)
---

Walk all eight conditions. Report each as PASS or FAIL **with the actual output** for anything that fails. Never summarize a failure as a warning, and never report the change as done while one is FAIL.

## 1–2. Package builds and tests

```bash
swift build && swift test
```

## 3. Example app compiles

```bash
xcodebuild -project Example/PalExample.xcodeproj -scheme PalExample -destination 'generic/platform=iOS Simulator' build
```

Skip only if the change touches no Swift and no `Package.swift`; say so explicitly in the report. Keep the `-destination`: without it `xcodebuild` picks the Mac and fails at signing (exit 65).

No scheme is committed under `xcshareddata` — `-scheme` works because Xcode autocreates a per-user scheme in gitignored `xcuserdata/`. On a fresh clone that has never been opened in Xcode, open the project once, then retry. Do not substitute `-target`: it builds Release into an untracked `build/` and fails.

## 4. Public symbols are documented and curated

For each product with changed sources, every new `public` symbol needs a `///` comment and an entry in `Sources/<Target>/<Target>.docc/<Target>.md` Topics.

```bash
git diff --name-only -- Sources | grep '\.swift$' | cut -d/ -f2 | sort -u   # products touched
git diff -- Sources | grep -E '^\+\s*public ' | sed 's/^+//'                # new public surface
```

## 5. Public API is still additive

Only when step 4 found new or changed public surface. Run both — the host build can't see API inside `#if canImport(UIKit)`:

```bash
BASELINE=$(git tag --list 'v*' --sort=-v:refname | head -1)
swift package diagnose-api-breaking-changes "$BASELINE"
swift package --triple arm64-apple-ios17.0-simulator --sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" diagnose-api-breaking-changes "$BASELINE"
```

Each run must list all twelve products; a run that lists fewer evaluated less than it claims, which is a FAIL. A detected break is a FAIL unless it is a deliberate, owner-ruled break — say which, and name the ruling.

## 6. Docs moved with the change

A changed public API, decision, or behavior means the product guide, `DECISIONS.md`, `ARCHITECTURE.md`, and the CONTRIBUTING status were updated in the same change. List which you touched, or state that none applied and why.

## 7. Adopter kit is consistent

Only when the change touched `Documentation/ADOPTERS.md`, `plugins/`, or `.claude-plugin/`:

```bash
Scripts/check-adopter-kit.sh
```

## 8. Branch discipline

```bash
git status --short && git branch --show-current
```

Work belongs on a pushed `feature/*` or `hotfix/*` branch, not merged. Being on `main` or `develop` with uncommitted work is a FAIL.

**One exception:** a release prep runs on `develop` by design (`/release` step 1 requires it). During a release, this condition passes once the prep is committed — the CHANGELOG entry, the status note, and the adopter-kit bump belong on `develop`. Feature work committed straight to `develop` is still a FAIL.
