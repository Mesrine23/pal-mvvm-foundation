#!/usr/bin/env bash
# Guards the adopter kit against drift: the brief's version stamp, the plugin version that
# triggers consumer updates, and the symlink that keeps the plugin from carrying a stale copy.
#
#   Scripts/check-adopter-kit.sh            # check against the latest v* tag
#   Scripts/check-adopter-kit.sh v1.6.0     # check against a release being prepared
set -uo pipefail
cd "$(dirname "$0")/.."

BRIEF="Documentation/ADOPTERS.md"
MANIFEST="plugins/pal-adopter/.claude-plugin/plugin.json"
LINK="plugins/pal-adopter/reference/ADOPTERS.md"
MARKET=".claude-plugin/marketplace.json"

expected="${1:-$(git tag --list 'v*' --sort=-v:refname | head -1)}"
[ -n "$expected" ] || { echo "FAIL  no v* tag found and no version argument given"; exit 1; }
bare="${expected#v}"
fails=0

fail() { echo "FAIL  $*"; fails=$((fails + 1)); }
pass() { echo "ok    $*"; }

stamp=$(grep -o 'Written for Pal `v[0-9][0-9.]*`' "$BRIEF" | head -1 | grep -o 'v[0-9][0-9.]*')
if [ "$stamp" = "$expected" ]; then
  pass "$BRIEF stamped $stamp"
else
  fail "$BRIEF says '${stamp:-<none>}', expected '$expected' — update the stamp line"
fi

manifest_version=$(python3 -c "import json;print(json.load(open('$MANIFEST')).get('version',''))")
if [ "$manifest_version" = "$bare" ]; then
  pass "$MANIFEST version $manifest_version"
else
  fail "$MANIFEST version is '${manifest_version:-<none>}', expected '$bare' — without a bump, installed plugins keep the cached copy"
fi

if [ -L "$LINK" ] && [ "$(readlink "$LINK")" = "../../../Documentation/ADOPTERS.md" ] && [ -f "$LINK" ]; then
  pass "$LINK links the canonical brief"
else
  fail "$LINK must be a symlink to ../../../Documentation/ADOPTERS.md — a real file there is a second copy that will drift"
fi

if python3 -c "
import json,sys
m=json.load(open('$MARKET'))
sys.exit(0 if any(p.get('source')=='./plugins/pal-adopter' for p in m.get('plugins',[])) else 1)
"; then
  pass "$MARKET lists pal-adopter"
else
  fail "$MARKET no longer points at ./plugins/pal-adopter"
fi

echo
if [ "$fails" -eq 0 ]; then echo "adopter kit consistent with $expected"; else echo "$fails problem(s)"; fi
exit $([ "$fails" -eq 0 ] && echo 0 || echo 1)
