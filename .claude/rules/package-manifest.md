---
paths:
  - "Package.swift"
---

# Editing Package.swift

The DAG and the zero-dependency guarantee are binding and live in [AGENTS.md](../../AGENTS.md) — this file is the operational checklist around them.

**Adding a dependency is never the answer here.** Pal ships zero external dependencies; the manifest is the guarantee. Swinject and every other third-party package belong app-side.

**Adding a target is ten edits, not one.** Ship them together or the product is half-born:

1. `Package.swift` — the `.target` plus its `dependencies:`, and a `.library` product if apps link it directly.
2. The `.testTarget`.
3. `Sources/<Target>/<Target>.docc/<Target>.md` — the catalog, with Topics.
4. `Documentation/Products/<Target>.md` — the consumer guide.
5. `README.md` — the products table.
6. `Documentation/ARCHITECTURE.md` — the package map.
7. `AGENTS.md` — the DAG line.
8. `.github/workflows/docs.yml` — the `PRODUCTS` list (twice: the docbuild loop and the landing index).
9. `Example/` — dogfood it, and link the product into the app target in `project.pbxproj`.
10. `Documentation/ADOPTERS.md` — the product-selection table adopters read.

**The macOS platform floor is build infrastructure**, not a supported platform: it exists so the host can `swift build`/`swift test`. Products target iOS. Never raise it to "fix" a host-only compile error — gate the surface with `#if canImport(UIKit)` instead.

**A new dependency edge between Pal products is an architecture change**, not a manifest change. It goes through [DECISIONS.md](../../Documentation/DECISIONS.md) and the owner first.
