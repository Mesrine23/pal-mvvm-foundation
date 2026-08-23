#!/usr/bin/env python3
"""PostToolUse(Edit|Write): flag clean-code rule violations in the file just written.

Covers the four rules that are mechanically checkable — AGENTS.md rules 4, 5 and 6.
Advisory only: PostToolUse cannot block, and the file is already on disk. Exit 2
puts the findings in front of the agent that wrote them.
"""
import json
import os
import re
import sys

BANNED = [
    (re.compile(r"(?<![\w.])print\s*\("), "`print(` — rule 5: use LoggerFactory"),
    (re.compile(r"(?<![\w.])try!"), "`try!` — rule 4: no force-try"),
    (re.compile(r"\sas!\s"), "`as!` — rule 4: no force-cast"),
    (re.compile(r"\bAnyView\b"), "`AnyView` — rule 6: no type erasure"),
]

WATCHED_PREFIXES = ("Sources/", "Example/")


def strip_noise(line: str) -> str:
    """Blank out double-quoted string contents, then drop a trailing // comment."""
    out = []
    in_string = False
    escaped = False
    i = 0
    while i < len(line):
        ch = line[i]
        if in_string:
            out.append(" ")
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == '"':
                out[-1] = '"'
                in_string = False
            i += 1
            continue
        if ch == '"':
            in_string = True
            out.append(ch)
            i += 1
            continue
        if ch == "/" and line[i:i + 2] == "//":
            break
        out.append(ch)
        i += 1
    return "".join(out)


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0

    path = (payload.get("tool_input") or {}).get("file_path") or ""
    if not path.endswith(".swift"):
        return 0

    cwd = payload.get("cwd") or os.getcwd()
    rel = os.path.relpath(path, cwd)
    if not rel.startswith(WATCHED_PREFIXES):
        return 0

    try:
        with open(path, encoding="utf-8") as handle:
            lines = handle.readlines()
    except OSError:
        return 0

    findings = []
    for number, raw in enumerate(lines, start=1):
        code = strip_noise(raw)
        stripped = code.strip()
        if stripped.startswith(("///", "//", "*", "/*")):
            continue
        for pattern, message in BANNED:
            if pattern.search(code):
                findings.append(f"  {rel}:{number}  {message}")

    if not findings:
        return 0

    print(
        "Pal clean-code rules — fix before reporting done "
        "(AGENTS.md § Clean-code rules):\n" + "\n".join(findings),
        file=sys.stderr,
    )
    return 2


if __name__ == "__main__":
    sys.exit(main())
