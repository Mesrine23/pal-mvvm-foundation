---
paths:
  - ".github/workflows/*.yml"
  - ".github/workflows/*.yaml"
---

# Editing CI

## Never drop the `macos-15` edge

`build-and-test` (`macos-15`, Xcode 16 / Swift 6.1) is the **consumer floor**, and it is the job that catches what local development cannot: newer SDKs concurrency-annotate system frameworks, so a wrapper that compiles on the latest Xcode can fail there. `build-and-test-latest` (`macos-26`) is the forward-looking edge. Both, always. Removing the floor edge silently ships breakage to every adopter on that toolchain.

## `api-stability` semantics are deliberate

The job diffs the public API against the newest `v*` tag and **hard-fails only on a detected break**. When the baseline tag no longer builds on the CI toolchain, it warns and skips rather than failing — every tag ≤ `v1.3.0` carries a portability bug that makes an API diff against them uncompilable. Do not "simplify" that branch into a plain failure.

A deliberate break is the one expected red: ship it with the new tag and the gate re-baselines on the next run.

## Docs deploy has invisible repo state

`docs.yml` runs on `v*` tags and deploys to GitHub Pages. The `github-pages` environment's deployment policy must allow **tags matching `v*`** in addition to `main` — GitHub allows only `main` by default, and the `deploy` job fails silently without it:

```bash
gh api repos/:owner/:repo/environments/github-pages/deployment-branch-policies -f name='v*' -f type=tag
```

That state lives in repo settings, not in this repository, so it survives no clone and no revert. It is recorded here and in the CONTRIBUTING deviations log because nothing in the tree reveals it.

The `PRODUCTS` list appears **twice** in `docs.yml` — the docbuild loop and the landing-index generator. Adding a product means editing both.

The landing-index step also emits `site/llms.txt`, the entry point agents fetch from the docs site. It reuses that step's `PRODUCTS` variable deliberately — keep the two generators in one step so the product list stays single-sourced.

DocC is built plugin-free (`xcodebuild docbuild`) on purpose: `swift-docc-plugin` would put an external package in `Package.swift`. Never switch to the plugin.
