#!/usr/bin/env bash
# SessionStart: three lines of state no instruction file can carry — where HEAD is,
# whether the tree is dirty, and what the last release was.
set -uo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || true
branch=$(git branch --show-current 2>/dev/null || echo "?")
tag=$(git tag --list 'v*' --sort=-v:refname 2>/dev/null | head -1)
dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
printf 'Pal: on branch %s (%s uncommitted), latest release %s. Features branch off develop; never commit to main.\n' \
  "$branch" "$dirty" "${tag:-none}"
