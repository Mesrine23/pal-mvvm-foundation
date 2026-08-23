@AGENTS.md

# Claude Code — Pal specifics

Everything binding is in [AGENTS.md](AGENTS.md), imported above. This file adds only what is specific to Claude Code. **Never restate a rule here** — the two files were byte-identical mirrors until 2026-08-23 and drifted; the import replaced that.

## How Pal's instructions reach you

- The root `AGENTS.md` loads at launch through the import above.
- Area files load on demand: reading anything under `Sources/`, `Example/`, `Tests/`, or `Documentation/` pulls in that directory's `CLAUDE.md`, which imports its `AGENTS.md`. Rules in the nearest file win over the root.
- `.claude/rules/*.md` load when you touch the files their `paths:` glob names — `Package.swift`, `CHANGELOG.md`, `.github/workflows/`. They add operational detail; the binding rule always lives in an `AGENTS.md`.
- Confirm what actually loaded with `/context` → **Memory files**. If an area file is missing there, you have not read a file in that directory yet.

## What runs automatically

- **`/verify`** walks Pal's seven-point definition of done and reports PASS/FAIL per condition. Run it before saying a change is finished — it is the cheapest defense against a false "done".
- **`/release`** is manual-only (`disable-model-invocation`). Never invoke it unless the owner asked for a release.
- **Hooks** (wired in `.claude/settings.json`): a `SessionStart` line reporting branch, dirtiness, and latest tag; a `PreToolUse` guard that escalates git writes to `main`; a `PostToolUse` checker that flags `print(`, `try!`, `as!`, and `AnyView` in files you just edited under `Sources/` or `Example/`. If the checker fires, fix the code — do not edit the hook.
- Verified commands (`swift build`, `swift test`, `xcodebuild` on the Example, read-only `git`/`gh`) are pre-approved in `.claude/settings.json`, and `.build/` is denied to reads so vendored checkouts stay out of context.

## Working here

- **Plan before editing `Sources/`.** A change to a public symbol is a contract change for every app on Pal — use plan mode, then check the compatibility rules in [Sources/AGENTS.md](Sources/AGENTS.md).
- **Auto memory is machine-local and personal.** Anything the team must follow belongs in `AGENTS.md`, committed — never only in memory.
- **`.claude/settings.local.json` is personal** (globally gitignored); `.claude/settings.json` is committed and shared. Put a personal permission or a `claudeMdExcludes` entry in the local file, never in the shared one.

## Editing the instruction files

Read **Maintaining these instruction files** in [AGENTS.md](AGENTS.md) first — it governs every file under this system, including the rules, skills, and hooks. Claude-specific mechanics:

- Keep this file's first line the bare `AGENTS.md` import. Removing it silently drops every project rule.
- HTML comments (`<!-- … -->`) in a `CLAUDE.md` are stripped before the content reaches context — use them for notes to human maintainers only, and never for a rule you expect an agent to follow.
- Write a literal path in backticks (`` `@AGENTS.md` ``) when you mean to mention it rather than import it. An unbacktick'd `@path` anywhere in the file is an import, including Swift attributes like `` `@MainActor` ``.
- `/init` proposes improvements to an existing `CLAUDE.md` rather than overwriting it — review its suggestions against the layout policy before accepting, and keep the import structure.
