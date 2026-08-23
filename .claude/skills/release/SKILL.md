---
name: release
description: Cut a Pal release — verify both toolchain edges, derive the Affects line, write the CHANGELOG entry, tag, and publish the GitHub Release.
argument-hint: [version]
disable-model-invocation: true
---

Releasing $ARGUMENTS. Work through this in order and stop at step 7 for the owner.

## 1. Preconditions

```bash
git branch --show-current   # must be develop (or a hotfix/* branch off main)
git status --short          # must be clean
gh run list --limit 5       # both toolchain edges green on the tip
```

A red `macos-15` edge blocks the release outright — that is the consumer floor.

## 2. Decide the version

```bash
LAST=$(git tag --list 'v*' --sort=-v:refname | head -1); echo "$LAST"
swift package diagnose-api-breaking-changes "$LAST"
```

Additive → minor · fix → patch · breaking → major. A break shipped in a minor requires an explicit owner ruling recorded in the deviations log; the `api-stability` gate is expected red until the tag re-baselines it.

## 3. Derive the `Affects:` line

```bash
git diff --name-only "$LAST"..HEAD -- Sources | grep '\.swift$' | cut -d/ -f2 | sort -u
```

Trim the candidates to products whose public API or behavior actually changed. `Affects: documentation only` for a docs release.

## 4. Write the CHANGELOG entry

Newest first, `Affects:` first inside it. The template and the voice rules are in `.claude/rules/changelog.md`.

## 5. Update the status docs

In `CONTRIBUTING.md`: the implementation-status or post-1.0 table, and a `> **vX.Y.Z** shipped (YYYY-MM-DD): …` note. Add a deviations-log entry if this release carries an approved exception.

## 6. Ripple the docs and the adopter kit

Product guide, `DECISIONS.md`, `ARCHITECTURE.md`, `README.md` — whatever the release changed.

Then bump the adopter kit to this version — the brief's stamp and the plugin `version`, which is what makes `/plugin update` reach installed adopters at all:

```bash
Scripts/check-adopter-kit.sh vX.Y.Z
```

Run `/verify` and require all eight conditions green.

## 7. Stop and ask

**Do not merge.** Push the branch and ask the owner to confirm the merge into `main` and the tag. This is Pal's standing rule, not a formality.

## 8. After approval

```bash
git checkout main && git merge --no-ff <branch>
git tag -a vX.Y.Z -m "vX.Y.Z" && git push origin main --follow-tags
gh release create vX.Y.Z --title "vX.Y.Z" --notes-file release-notes.md   # body = this release's CHANGELOG entry
```

For a `hotfix/*`, merge into **both** `main` (tag a patch) and `develop`, or the next release reverts the fix. For a normal release, bring `main` back into `develop` so the two do not diverge.

## 9. Verify the publish

```bash
gh run list --workflow=Docs --limit 3
```

The `Docs` workflow runs on the `v*` tag and deploys to GitHub Pages. If `deploy` fails, the `github-pages` environment is probably missing its `v*` tag policy — see `.claude/rules/ci-workflows.md`.
